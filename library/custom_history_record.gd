extends Reference

# Custom History Record for Split Path actions
var type = "ChangeObjectTexture"
var history_data

# Logging Functions
const ENABLE_LOGGING = true
const LOGGING_LEVEL = 0

func outputlog(msg,level=0):
	if ENABLE_LOGGING:
		if level <= LOGGING_LEVEL:
			printraw("(%d) <MakePatternHole>: " % OS.get_ticks_msec())
			print(msg)
	else:
		pass

func update_object_textures(type: String):

	for key in history_data.keys():
		if Global.World.HasNodeID(int(key)):
			if history_data[key].has(type):
				set_texture_values(Global.World.GetNodeByID(int(key)),history_data[key][type])

func set_texture_values(node, data: Dictionary):

	var texture = load(data["texture_path"])
	if texture != null:
		node.SetTexture(texture)
		node.hasCustomColor = data["hascustomcolor"]
		if data["hascustomcolor"]:
			node.SetCustomColor(Color(data["customcolor"]))	

func undo():

	outputlog("undo",3)
	update_object_textures("old")

func redo():
	
	outputlog("redo",3)
	update_object_textures("new")

