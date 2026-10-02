class_name AuctionLot
extends RefCounted
## Lot d'enchères : une épave, un prix de départ, une mise max cachée des PNJ
## et une offre max (enchère par procuration) du joueur.

var id: int = 0
var location: String = ""
var ship: Ship = null
var start_price: int = 0
var npc_max: int = 0
var player_max: int = 0
var open_hour: int = 0
var close_hour: int = 0
var scanned: bool = false
var special: String = ""
var closed: bool = false
var result: String = ""
var paid: int = 0
var buyer_seen: bool = false


func increment() -> int:
	return maxi(10, int(round(float(start_price) * 0.2)))


func progress(now: int) -> float:
	if close_hour <= open_hour:
		return 1.0
	return clampf(float(now - open_hour) / float(close_hour - open_hour), 0.0, 1.0)


## Mise courante visible (les PNJ enchérissent progressivement jusqu'à leur maximum).
func visible_price(now: int) -> int:
	var npc_now: int = int(lerpf(float(start_price), float(npc_max), sqrt(progress(now))))
	if player_max <= 0:
		return npc_now
	if player_max > npc_now:
		return mini(player_max, maxi(start_price, npc_now + increment()))
	return mini(npc_max, player_max + increment())


func player_leading(now: int) -> bool:
	if player_max <= 0:
		return false
	var npc_now: int = int(lerpf(float(start_price), float(npc_max), sqrt(progress(now))))
	return player_max > npc_now


## Prix final si le joueur l'emporte (second prix + incrément), sinon -1.
func winning_price() -> int:
	if player_max <= npc_max:
		return -1
	return mini(player_max, maxi(start_price, npc_max + increment()))


func to_dict() -> Dictionary:
	return {
		"id": id, "location": location, "ship": ship.to_dict() if ship != null else {},
		"start_price": start_price, "npc_max": npc_max, "player_max": player_max,
		"open_hour": open_hour, "close_hour": close_hour, "scanned": scanned, "special": special,
		"closed": closed, "result": result, "paid": paid, "buyer_seen": buyer_seen,
	}


static func from_dict(d: Dictionary) -> AuctionLot:
	var l: AuctionLot = AuctionLot.new()
	l.id = int(d.get("id", 0))
	l.location = str(d.get("location", ""))
	l.ship = Ship.from_dict(d.get("ship", {}))
	l.start_price = int(d.get("start_price", 0))
	l.npc_max = int(d.get("npc_max", 0))
	l.player_max = int(d.get("player_max", 0))
	l.open_hour = int(d.get("open_hour", 0))
	l.close_hour = int(d.get("close_hour", 0))
	l.scanned = bool(d.get("scanned", false))
	l.special = str(d.get("special", ""))
	l.closed = bool(d.get("closed", false))
	l.result = str(d.get("result", ""))
	l.paid = int(d.get("paid", 0))
	l.buyer_seen = bool(d.get("buyer_seen", false))
	return l
