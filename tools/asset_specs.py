"""Spécifications de tous les assets générés (prompts, tailles, post-traitement).

Les prompts décrivent des concepts originaux (aucun artiste, studio ou personnage existant).
Chaque spec : id, category, out (chemin relatif à assets/), prompt, w/h de génération,
pp (spécification pixelize), seeds (graines candidates).
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data"

STYLE = "pixel art, 16-bit retro game sprite, clean bold shapes, flat colors, limited palette, crisp edges, thick dark outline"
ISO = "isolated on a plain white background, centered, entire object visible, no text"
BG_STYLE = "detailed pixel art, 16-bit retro game background, crisp pixels, limited palette"
NEGATIVE = "blurry, photo, realistic, 3d render, text, letters, watermark, signature, logo, frame, border, multiple objects, cropped"

HULLS = {
    "hull_shuttle": ("small chubby used space shuttle hull shaped like a mosquito body, rounded nose", [76, 34]),
    "hull_courier": ("sleek small courier spaceship hull, slim aerodynamic body, pointed nose", [80, 30]),
    "hull_tug": ("stubby heavy space tugboat hull, boxy bulldog-like body with a big front bumper", [80, 38]),
    "hull_miner": ("mining spaceship hull with a big drill on the nose, sturdy body", [88, 36]),
    "hull_cargo": ("long cargo freighter spaceship hull, whale-like big container body", [108, 42]),
    "hull_fighter": ("sleek retro interceptor spaceship fuselage, long pointed nose", [92, 30]),
    "hull_yacht": ("luxurious space yacht hull, elegant curved body with portholes and gold trim", [100, 38]),
    "hull_explorer": ("large deep space explorer ship hull, long body with antennas and a sensor dome", [114, 44]),
}
ENGINES = {
    "eng_putt": ("small rusty old rocket engine with a dented nozzle and black smoke", [26, 20]),
    "eng_ion": ("compact ion thruster engine with a soft blue glow", [28, 20]),
    "eng_twin": ("twin nozzle turbo rocket engine with two exhausts", [32, 24]),
    "eng_plasma": ("big plasma rocket engine with a roaring orange flame", [34, 24]),
    "eng_fusion": ("elegant fusion engine with a padded white casing and warm glow", [34, 24]),
    "eng_warp": ("futuristic quantum warp engine with glowing purple rings", [36, 26]),
}
COCKPITS = {
    "cock_box": ("square boxy spaceship cockpit cabin with small flat windows", [26, 18]),
    "cock_bubble": ("round glass bubble spaceship cockpit with a metal base", [28, 20]),
    "cock_visor": ("sleek fighter pilot canopy with a tinted visor glass", [30, 16]),
    "cock_armored": ("armored spaceship cockpit with thick plates and slit windows", [30, 20]),
    "cock_lounge": ("luxury spaceship lounge cockpit with big panoramic windows and a tiny sofa", [34, 20]),
    "cock_crystal": ("crystal dome spaceship cockpit made of faceted glowing glass", [32, 22]),
}
WINGS = {
    "wing_stub": ("pair of tiny stubby spaceship wing fins", [30, 16]),
    "wing_delta": ("triangular delta spaceship wing", [52, 22]),
    "wing_swept": ("swept-back spaceship wing like an arrow", [54, 20]),
    "wing_solar": ("spaceship solar sail wing with blue solar panels", [56, 24]),
}
WEAR = {
    "wear_rust": "scattered orange and brown rust stains and corrosion patches",
    "wear_scratch": "scattered light grey scratches and scuff marks",
    "wear_dent": "scattered dark grey dents and bumps on metal",
    "wear_scorch": "scattered black and dark brown burn marks and soot stains",
}
CLIENTS = {
    "glorbian": "green gelatinous blob alien with big round eyes and a tiny bow tie",
    "krrkt": "insectoid alien with mandibles, antennae and compound eyes, wearing a work vest",
    "zoxxian": "purple octopus-like alien with tentacles, wearing a pearl necklace and a monocle",
    "plutonian": "rocky stone golem alien with glowing crystal eyes, wearing a flat cap",
    "velarian": "bird-like alien with blue and yellow feathers and aviator goggles",
    "mmmbr": "sentient mushroom alien with a red cap with white spots and a friendly face",
    "silicoid": "living crystal alien made of white and teal crystals, elegant",
    "neonyx": "glowing orange-red lizard alien wearing a leather jacket",
    "misty": "ghostly gaseous cloud alien with a soft white mist body and two glowing eyes",
    "glutton": "chubby round yellow alien with a huge smiling mouth holding a snack",
    "tetrapter": "giant butterfly alien with pink and purple wings and long antennae",
    "android": "free robot android with a black and white metal head and a blue visor",
}
STAFF = {
    "staff_01": "young woman mechanic with goggles on her forehead, grease on her cheek and blue overalls",
    "staff_02": "green-skinned three-eyed alien mechanic wearing a backwards cap",
    "staff_03": "elderly salesman with a big grey mustache and a bright striped tie",
    "staff_04": "blue alien with four arms wearing a white lab coat",
    "staff_05": "small round robot scientist with one big eye, an antenna and tiny glasses",
    "staff_06": "orange furry alien with big ears wearing a headset",
    "staff_07": "tall pale alien painter with a beret and colorful paint stains",
    "staff_08": "young mechanic with spiky hair and a red bandana",
    "staff_09": "grumpy old alien mechanic with a beard made of cables and a welding mask",
    "staff_10": "charming pink alien saleswoman with sunglasses and a big smile",
}
STORY = {
    "story_bolt": "sarcastic onboard computer AI shown as a boxy robot head with a green CRT screen face and an antenna",
    "story_odile": "adventurous old woman mechanic with white hair in a bun, aviator goggles and a big wrench, blue hologram tint",
    "story_lustre": "slick corporate alien executive in a shiny purple suit with slicked back hair and a fake smile",
    "story_inspector": "strict alien inspector with round glasses, a uniform cap and a clipboard",
}
UI_ICON_SUBJECTS = {
    "ui_credits": "stack of gold coins", "ui_rp": "glowing blue lightbulb", "ui_rep": "golden star badge",
    "ui_debt": "red bill paper with a chain", "ui_day": "small sun and moon clock", "ui_pause": "pause symbol with two bars",
    "ui_play": "play triangle symbol", "ui_fast": "double arrow fast forward symbol", "ui_faster": "triple arrow fast forward symbol",
    "ui_garage": "small hangar building", "ui_auction": "wooden auction gavel", "ui_staff": "two little worker heads with caps",
    "ui_research": "chemistry flask with bubbles", "ui_quests": "open journal book with a bookmark", "ui_sales": "price tag",
    "ui_settings": "metal gear cog", "ui_scan": "magnifying glass", "ui_bid": "raised hand holding a paddle",
    "ui_repair": "wrench", "ui_conceal": "paint roller covering a crack", "ui_paint": "spray paint can", "ui_sell": "handshake",
    "ui_hire": "plus sign next to a person", "ui_check": "green check mark", "ui_lock": "padlock",
    "ui_warning": "yellow warning triangle", "ui_star": "shiny star", "ui_report": "clipboard with a chart",
}
ROLE_SUBJECTS = {
    "role_buyer": "auction paddle with a number", "role_mechanic": "crossed wrench and screwdriver", "role_bodyworker": "paint brush with a drop",
    "role_seller": "golden handshake", "role_researcher": "microscope",
}
BRANCH_SUBJECTS = {
    "branch_atelier": "anvil and hammer", "branch_commerce": "shop sign with coins", "branch_perso": "color palette with brush",
    "branch_rh": "group of three people", "branch_diagnostic": "stethoscope", "branch_lieux": "planet with a map pin",
}
ITEM_SUBJECTS = {
    "item_keel": "glowing ancient metal beam", "item_heart": "glowing reactor core shaped like a heart",
    "item_sail": "shimmering golden solar sail", "item_star": "star-shaped cockpit seat glowing", "item_compass": "celestial brass compass with a star",
}
DEFECT_SUBJECTS = {
    "def_rust": "rusty metal plate", "def_dent": "dented metal panel", "def_breach": "cracked hull with escaping air puff",
    "def_misfire": "engine coughing black smoke", "def_plasma": "leaking blue plasma drop", "def_fuel": "cracked hose with duct tape",
    "def_nav": "confused compass with question mark", "def_canopy": "cracked glass window", "def_ai": "sulking computer screen face",
    "def_wing": "bent airplane wing", "def_wiring": "chewed electric cables with spark", "def_battery": "empty battery with red level",
    "def_air": "air vent with green smelly cloud", "def_gravity": "upside down floating chair", "def_toilet": "small space toilet",
}
OPTION_SUBJECTS = {
    "opt_polish": "sparkling polish cloth", "opt_flames": "flame decal sticker", "opt_horn": "trumpet horn", "opt_rack": "roof rack with boxes",
    "opt_baby": "small baby seat", "opt_spoiler": "car spoiler fin", "opt_neon": "glowing neon light tube", "opt_leather": "luxury leather seat",
    "opt_minibar": "cocktail glass with ice", "opt_shield": "round energy shield", "opt_autopilot": "steering wheel with robot head",
    "opt_solar": "small solar panel",
}
TECH_SUBJECTS = {
    "at_1": "workbench with tools", "at_2": "ratchet wrench with sparkles", "at_3": "crate full of bolts", "at_4": "repair bay with lift",
    "at_5": "big hangar door", "at_6": "robotic arm", "at_7": "night lamp and moon",
    "co_1": "smiling face with sparkle", "co_2": "holographic billboard", "co_3": "credit card", "co_4": "sales desk",
    "co_5": "shield with check mark", "co_6": "two hands shaking with coins", "co_7": "red carpet and crown",
    "pe_1": "paint spray gun", "pe_2": "color swatches fan", "pe_3": "neon underglow light", "pe_4": "luxury armchair",
    "pe_5": "paint booth", "pe_6": "trending arrow with stars", "pe_7": "gold paint bucket",
    "rh_1": "coffee machine with mug", "rh_2": "newspaper ad", "rh_3": "graduation cap", "rh_4": "bunk bed",
    "rh_5": "pillow with Z letters", "rh_6": "magnifying glass over a person", "rh_7": "first aid kit with heart",
    "di_1": "handheld scanner", "di_2": "gamma ray scanner with green rays", "di_3": "stethoscope on engine", "di_4": "laboratory flask",
    "di_5": "certificate with seal", "di_6": "quantum atom scanner", "di_7": "robot brain chip",
    "li_1": "ice crystal permit card", "li_2": "tow truck spaceship", "li_3": "shady handshake in purple light", "li_4": "skull map",
    "li_5": "cargo crate with discount tag", "li_6": "golden invitation envelope", "li_7": "radar screen with blip",
}


def _load(name: str) -> dict[str, Any]:
    return json.loads((DATA / name).read_text(encoding="utf-8"))


def specs() -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []

    def part(cat: str, pid: str, subject: str, size: list[int], paint: bool) -> None:
        color = "red painted panels with grey metal details" if paint else "grey metal with colored details"
        out.append({
            "id": pid, "category": cat, "out": f"ships/{cat}/{pid}.png", "w": 1344, "h": 768, "seeds": [101, 202],
            "prompt": f"{STYLE}, side view of a {subject}, facing right, {color}, game asset, {ISO}",
            "pp": {"mode": "sprite", "max": size, "paint_hue": "red" if paint else None, "outline": True},
        })

    for pid, (subj, size) in HULLS.items():
        part("hull", pid, subj + ", without wings", size, True)
    for pid, (subj, size) in ENGINES.items():
        out.append({"id": pid, "category": "engine", "out": f"ships/engine/{pid}.png", "w": 1024, "h": 1024, "seeds": [101, 202],
                    "prompt": f"{STYLE}, side view of a single {subj}, horizontal, exhaust nozzle pointing left, game asset, {ISO}",
                    "pp": {"mode": "sprite", "max": size, "outline": True, "orient": "flame_left"}})
    for pid, (subj, size) in COCKPITS.items():
        out.append({"id": pid, "category": "cockpit", "out": f"ships/cockpit/{pid}.png", "w": 1024, "h": 1024, "seeds": [101, 202],
                    "prompt": f"{STYLE}, side view of a single {subj}, facing right, game asset, {ISO}",
                    "pp": {"mode": "sprite", "max": size, "outline": True}})
    for pid, (subj, size) in WINGS.items():
        part("wings", pid, subj + ", seen from the side", size, True)
    for wid, subj in WEAR.items():
        out.append({"id": wid, "category": "wear", "out": f"ships/wear/{wid}.png", "w": 1344, "h": 768, "seeds": [101, 202],
                    "prompt": f"{STYLE}, texture overlay of {subj} spread across the whole image, no object, {ISO}",
                    "pp": {"mode": "sprite", "max": [96, 48], "outline": False, "fill": True}})
    species = {s["id"]: s for s in _load("species.json")["species"]}
    for sid, subj in CLIENTS.items():
        pid = species[sid]["portrait"]
        out.append({"id": pid, "category": "portrait", "out": f"portraits/{pid}.png", "w": 1024, "h": 1024, "seeds": [101, 202],
                    "prompt": f"{STYLE}, portrait of a {subj}, alien customer, head and shoulders, front view, friendly, game character portrait, {ISO}",
                    "pp": {"mode": "sprite", "max": [48, 48], "canvas": [48, 48], "align": "bottom", "outline": True}})
    for pid, subj in STAFF.items():
        out.append({"id": pid, "category": "portrait", "out": f"portraits/{pid}.png", "w": 1024, "h": 1024, "seeds": [101, 202],
                    "prompt": f"{STYLE}, portrait of a {subj}, garage employee, head and shoulders, front view, game character portrait, {ISO}",
                    "pp": {"mode": "sprite", "max": [48, 48], "canvas": [48, 48], "align": "bottom", "outline": True}})
    for pid, subj in STORY.items():
        out.append({"id": pid, "category": "portrait", "out": f"portraits/{pid}.png", "w": 1024, "h": 1024, "seeds": [101, 202],
                    "prompt": f"{STYLE}, portrait of a {subj}, head and shoulders, front view, game character portrait, {ISO}",
                    "pp": {"mode": "sprite", "max": [48, 48], "canvas": [48, 48], "align": "bottom", "outline": True}})

    def icon(iid: str, subject: str) -> None:
        out.append({"id": iid, "category": "icon", "out": f"icons/{iid}.png", "w": 1024, "h": 1024, "seeds": [101],
                    "prompt": f"{STYLE}, single game inventory icon of a {subject}, simple chunky shape, bold colors, {ISO}",
                    "pp": {"mode": "sprite", "max": [16, 16], "canvas": [16, 16], "align": "center", "outline": False, "min_component": 0.15}})

    for table in (UI_ICON_SUBJECTS, ROLE_SUBJECTS, BRANCH_SUBJECTS, ITEM_SUBJECTS, DEFECT_SUBJECTS, OPTION_SUBJECTS):
        for iid, subj in table.items():
            icon(iid, subj)
    for node in _load("tech_tree.json")["nodes"]:
        icon(node["icon"], TECH_SUBJECTS[node["id"]])

    out.append({"id": "garage", "category": "background", "out": "backgrounds/garage.png", "w": 1344, "h": 768, "seeds": [301, 302, 303],
                "prompt": f"{BG_STYLE}, full-screen game scene filling the whole frame edge to edge, side view cross-section of a cozy orbital space station garage on two floors, ground floor with three large empty repair bays side by side with orange doorframes, hanging cranes, tool carts, tiled metal floor with yellow hazard lines, upper floor with an office, a lab and a paint booth behind railings, pipes on the ceiling, round portholes showing stars, warm industrial lighting, no characters, no vehicles, no text",
                "pp": {"mode": "opaque", "size": [480, 270]}})
    loc_prompts = {
        "loc_ferropolis": "huge space scrapyard station with mountains of broken spaceship wrecks, cranes, magnets, orange sunset light, smoke",
        "loc_kryo7": "frozen icy planetary rings with giant ice chunks and frozen derelict spaceships trapped in ice, pale blue and teal colors, auction floodlights",
        "loc_nebula": "colorful black market bazaar on a floating asteroid inside a purple and pink nebula, neon stalls and lanterns, shady spaceships parked",
        "loc_tartarus": "eerie spaceship graveyard drifting in dark space, giant broken hulls and skeleton frames, green ghostly glow, red giant star",
        "loc_opalia": "luxurious moon with opal crystal domes and an elegant auction hall with golden lights, rich purple sky with rings",
    }
    for lid, subj in loc_prompts.items():
        out.append({"id": lid, "category": "background", "out": f"backgrounds/{lid}.png", "w": 1344, "h": 768, "seeds": [301, 302],
                    "prompt": f"{BG_STYLE}, full-screen landscape scene filling the entire image edge to edge, {subj}, starry sky, no text, no border",
                    "pp": {"mode": "opaque", "size": [480, 270]}})
    out.append({"id": "ui_panel_src", "category": "ui", "out": "ui/_panel_src.png", "w": 1024, "h": 1024, "seeds": [401, 402],
                "prompt": f"{STYLE}, single square sci-fi metal user interface panel frame with riveted dark steel border, beveled edges, small orange corner lights, flat dark blue-grey center, game UI element, front view, {ISO}",
                "pp": {"mode": "sprite", "max": [32, 32], "outline": False}})
    out.append({"id": "ui_button_src", "category": "ui", "out": "ui/_button_src.png", "w": 1024, "h": 1024, "seeds": [401, 402],
                "prompt": f"{STYLE}, single wide rectangular sci-fi metal game button with orange beveled border and a dark steel face, no text, game UI element, front view, {ISO}",
                "pp": {"mode": "sprite", "max": [32, 16], "outline": False}})
    return out


if __name__ == "__main__":
    s = specs()
    cats: dict[str, int] = {}
    for x in s:
        cats[x["category"]] = cats.get(x["category"], 0) + 1
    print(len(s), "assets", cats, sum(len(x["seeds"]) for x in s), "générations")
