"""Client minimal de l'API HTTP de ComfyUI (stdlib uniquement).

- validation d'un workflow (format API) contre /object_info (ou un instantané hors ligne)
- mise en file (/prompt), attente (/history), récupération des images (/view)
- gabarits : les valeurs "{{NOM}}" d'un workflow sont remplacées par des paramètres.
"""
from __future__ import annotations

import copy
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
WORKFLOW_DIR = ROOT / "comfy" / "workflows"
SNAPSHOT = ROOT / "comfy" / "object_info_snapshot.json"
DEFAULT_URL = os.environ.get("COMFY_URL", "http://127.0.0.1:8188")


def load_workflow(name: str) -> dict[str, Any]:
    path = WORKFLOW_DIR / (name if name.endswith(".json") else name + ".json")
    return json.loads(path.read_text(encoding="utf-8"))


def fill(workflow: dict[str, Any], params: dict[str, Any]) -> dict[str, Any]:
    """Remplace récursivement les chaînes "{{CLE}}" par params[CLE] (type conservé)."""

    def sub(v: Any) -> Any:
        if isinstance(v, str) and v.startswith("{{") and v.endswith("}}"):
            key = v[2:-2]
            if key not in params:
                raise KeyError(f"paramètre de workflow manquant : {key}")
            return params[key]
        if isinstance(v, dict):
            return {k: sub(x) for k, x in v.items()}
        if isinstance(v, list):
            return [sub(x) for x in v]
        return v

    wf = copy.deepcopy(workflow)
    meta = wf.pop("_meta_workflow", None)
    out = {k: sub(v) for k, v in wf.items()}
    if meta is not None:
        out["_meta_workflow"] = meta
    return out


def placeholders(workflow: dict[str, Any]) -> set[str]:
    found: set[str] = set()

    def walk(v: Any) -> None:
        if isinstance(v, str) and v.startswith("{{") and v.endswith("}}"):
            found.add(v[2:-2])
        elif isinstance(v, dict):
            for x in v.values():
                walk(x)
        elif isinstance(v, list):
            for x in v:
                walk(x)

    walk({k: v for k, v in workflow.items() if k != "_meta_workflow"})
    return found


def validate(workflow: dict[str, Any], object_info: dict[str, Any]) -> list[str]:
    """Vérifie classes, entrées requises, valeurs COMBO et liens d'un workflow API."""
    errors: list[str] = []
    nodes = {k: v for k, v in workflow.items() if not k.startswith("_")}
    for nid, node in nodes.items():
        ctype = node.get("class_type")
        if ctype not in object_info:
            errors.append(f"nœud {nid}: classe inconnue {ctype}")
            continue
        spec = object_info[ctype]
        inputs = node.get("inputs", {})
        required = spec.get("input", {}).get("required", {})
        optional = spec.get("input", {}).get("optional", {})
        for name, ispec in required.items():
            if name not in inputs:
                errors.append(f"nœud {nid} ({ctype}): entrée requise manquante '{name}'")
        for name, val in inputs.items():
            ispec = required.get(name, optional.get(name))
            if ispec is None:
                errors.append(f"nœud {nid} ({ctype}): entrée inconnue '{name}'")
                continue
            if isinstance(val, list) and len(val) == 2 and isinstance(val[0], str) and isinstance(val[1], int):
                src = nodes.get(val[0])
                if src is None:
                    errors.append(f"nœud {nid}: lien vers nœud absent {val[0]}")
                    continue
                outs = object_info.get(src.get("class_type"), {}).get("output", [])
                if val[1] >= len(outs):
                    errors.append(f"nœud {nid}: sortie {val[1]} inexistante sur {val[0]}")
                continue
            kind = ispec[0] if ispec else None
            if isinstance(kind, list):
                if val not in kind:
                    errors.append(f"nœud {nid} ({ctype}): valeur '{val}' hors liste pour '{name}'")
            elif kind == "COMBO":
                opts = (ispec[1] or {}).get("options", []) if len(ispec) > 1 else []
                if opts and val not in opts:
                    errors.append(f"nœud {nid} ({ctype}): valeur '{val}' hors liste pour '{name}'")
            elif kind in ("INT", "FLOAT"):
                if not isinstance(val, (int, float)) or isinstance(val, bool):
                    errors.append(f"nœud {nid} ({ctype}): '{name}' doit être numérique")
                else:
                    cfg = ispec[1] if len(ispec) > 1 and isinstance(ispec[1], dict) else {}
                    if "min" in cfg and val < cfg["min"] or "max" in cfg and val > cfg["max"]:
                        errors.append(f"nœud {nid} ({ctype}): '{name}'={val} hors bornes")
    return errors


class ComfyClient:
    def __init__(self, base_url: str = DEFAULT_URL) -> None:
        self.base = base_url.rstrip("/")
        self.client_id = str(uuid.uuid4())
        self._object_info: dict[str, Any] | None = None

    def _get(self, path: str, timeout: float = 60) -> Any:
        with urllib.request.urlopen(self.base + path, timeout=timeout) as r:
            return json.loads(r.read().decode("utf-8"))

    def alive(self) -> bool:
        try:
            self._get("/system_stats", timeout=3)
            return True
        except (urllib.error.URLError, OSError, ValueError):
            return False

    def system_stats(self) -> dict[str, Any]:
        return self._get("/system_stats")

    def object_info(self) -> dict[str, Any]:
        if self._object_info is None:
            self._object_info = self._get("/object_info", timeout=120)
        return self._object_info

    def queue(self, workflow: dict[str, Any]) -> str:
        nodes = {k: v for k, v in workflow.items() if not k.startswith("_")}
        body = json.dumps({"prompt": nodes, "client_id": self.client_id}).encode("utf-8")
        req = urllib.request.Request(self.base + "/prompt", data=body, headers={"Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.loads(r.read().decode("utf-8"))["prompt_id"]
        except urllib.error.HTTPError as e:
            raise RuntimeError(f"ComfyUI a refusé le workflow : {e.read().decode('utf-8', 'replace')[:2000]}") from e

    def wait(self, prompt_id: str, timeout: float = 900, poll: float = 1.0) -> dict[str, Any]:
        t0 = time.time()
        while time.time() - t0 < timeout:
            hist = self._get(f"/history/{prompt_id}")
            if prompt_id in hist:
                entry = hist[prompt_id]
                status = entry.get("status", {})
                if status.get("status_str") == "error":
                    raise RuntimeError(f"échec d'exécution ComfyUI : {json.dumps(status)[:2000]}")
                if status.get("completed", False) or entry.get("outputs"):
                    return entry
            time.sleep(poll)
        raise TimeoutError(f"délai dépassé pour {prompt_id}")

    def images(self, history_entry: dict[str, Any]) -> dict[str, list[bytes]]:
        """Renvoie {node_id: [png bytes, ...]} pour chaque nœud de sortie."""
        out: dict[str, list[bytes]] = {}
        for nid, data in history_entry.get("outputs", {}).items():
            for img in data.get("images", []):
                q = urllib.parse.urlencode({"filename": img["filename"], "subfolder": img.get("subfolder", ""), "type": img.get("type", "output")})
                with urllib.request.urlopen(f"{self.base}/view?{q}", timeout=120) as r:
                    out.setdefault(nid, []).append(r.read())
        return out

    def run(self, workflow: dict[str, Any], timeout: float = 900) -> dict[str, list[bytes]]:
        errs = validate(workflow, self.object_info())
        if errs:
            raise ValueError("workflow invalide :\n  " + "\n  ".join(errs))
        pid = self.queue(workflow)
        return self.images(self.wait(pid, timeout=timeout))


def save_snapshot(client: ComfyClient, class_types: set[str]) -> None:
    """Sauve la partie d'/object_info utilisée par nos workflows (validation hors ligne)."""
    oi = client.object_info()
    snap = {k: oi[k] for k in sorted(class_types) if k in oi}
    SNAPSHOT.write_text(json.dumps(snap, indent=1, ensure_ascii=False), encoding="utf-8")
