class_name TipBox
extends HBoxContainer
## Conteneur (icône + valeur) dont l'infobulle explique une ressource : première ligne = titre,
## suite = texte à retour à la ligne automatique (les infobulles par défaut ne passent pas à la ligne).

const WIDTH: int = 200


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_HELP
	add_theme_constant_override("separation", 1)


func _make_custom_tooltip(for_text: String) -> Object:
	return UIKit.rich_tooltip(for_text, WIDTH)
