class_name UiStyle
extends RefCounted
## Shared placeholder UI styling (bold white text, thick dark outline).
## Milestone 2 replaces this with a proper Theme + display font.

const OUTLINE := Color(0.08, 0.06, 0.14)


static func label(text: String, size: int, outline: int = 14) -> Label:
	var l := Label.new()
	l.text = text
	var settings := LabelSettings.new()
	settings.font_size = size
	settings.font_color = Color.WHITE
	settings.outline_size = outline
	settings.outline_color = OUTLINE
	l.label_settings = settings
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func button(text: String, size: int, min_size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_NONE
	return b
