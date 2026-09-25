## ui_checks.gd
## PORTS: nothing — test helper per interface spec §4.5 (rules 04, 05) and §7
class_name UiChecks
extends RefCounted
## Layout rules the interface spec makes testable. Pure queries over a laid-out
## tree; call them after at least one process_frame.


## Names of visible buttons under `root` shorter than `min_height` px (rule 05).
static func short_buttons(root: Node, min_height: float) -> Array[String]:
	var out: Array[String] = []
	for node: Node in root.find_children("*", "BaseButton", true, false):
		var button: BaseButton = node as BaseButton
		if button.is_visible_in_tree() and button.size.y < min_height - 0.5:
			out.append(String(button.name))
	return out


## Names of visible Controls under `root` whose global rect leaves `bounds`.
## Content inside a ScrollContainer is skipped: it is meant to exceed its clip.
static func outside(root: Node, bounds: Rect2) -> Array[String]:
	var out: Array[String] = []
	var allowed: Rect2 = bounds.grow(0.5)
	for node: Node in root.find_children("*", "Control", true, false):
		var control: Control = node as Control
		if not control.is_visible_in_tree() or _in_scroll(control, root):
			continue
		if not allowed.encloses(control.get_global_rect()):
			out.append(String(control.name))
	return out


## "Parent/A+B" for every pair of visible siblings in a Container whose rects overlap.
static func overlapping_siblings(root: Node) -> Array[String]:
	var out: Array[String] = []
	for node: Node in root.find_children("*", "Container", true, false):
		# A hidden Container never lays its children out; they are not drawn.
		if not (node as Container).is_visible_in_tree():
			continue
		var kids: Array[Control] = []
		for child: Node in node.get_children():
			var control: Control = child as Control
			if control != null and control.visible:
				kids.append(control)
		for i: int in range(kids.size()):
			for j: int in range(i + 1, kids.size()):
				if kids[i].get_rect().intersects(kids[j].get_rect(), false):
					out.append("%s/%s+%s" % [node.name, kids[i].name, kids[j].name])
	return out


static func _in_scroll(control: Control, root: Node) -> bool:
	var parent: Node = control.get_parent()
	while parent != null and parent != root:
		if parent is ScrollContainer:
			return true
		parent = parent.get_parent()
	return false
