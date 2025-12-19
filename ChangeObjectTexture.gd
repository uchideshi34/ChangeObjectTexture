#########################################################################################################
##
## Select New Object Texture FUNCTIONS
##
#########################################################################################################

var script_class = "tool"

# Variables
var tags_panel
var ui_config = {}

var select_tool_panel
var store_last_valid_selection = []
var show_button = null

# Logging functions
const ENABLE_LOGGING = true
const LOGGING_LEVEL = 0

#########################################################################################################
##
## UTILITY FUNCTIONS
##
#########################################################################################################

func outputlog(msg,level=0):
	if ENABLE_LOGGING:
		if level <= LOGGING_LEVEL:
			printraw("(%d) <ChangeObjectTexture>: " % OS.get_ticks_msec())
			print(msg)
	else:
		pass

# Function to see if a structure that looks like a copied dd data entry is the same
func is_the_same(a, b) -> bool:

	if a is Dictionary:
		if not b is Dictionary:
			return false
		if a.keys().size() != b.keys().size():
			return false
		for key in a.keys():
			if not b.has(key):
				return false
			if not is_the_same(a[key], b[key]):
				return false
	elif a is Array:
		if not b is Array:
			return false
		if a.size() != b.size():
			return false
		for _i in a.size():
			if not is_the_same(a[_i], b[_i]):
				return false
	elif a != b:
		return false

	return true

# Function to look at a node and determine what type it is based on its properties
func get_node_type(node):

	if node.get("WallID") != null:
		return "portals"

	# Note this is also true of portals but we caught those with WallID
	elif node.get("Sprite") != null:
		return "objects"
	elif node.get("FadeIn") != null:
		return "paths"
	elif node.get("HasOutline") != null:
		return "pattern_shapes"
	elif node.get("Joint") != null:
		return "walls"

	return null

# Function to find the grid menu category so we can put UI around it and modify it. Note that category_label here is the singular version, eg "Wall" not "Walls"
func find_select_vbox(tool_name: String):

	match tool_name:
		"ObjectTool":
			return Global.Editor.Toolset.GetToolPanel("SelectTool").objectOptions
		"PathTool":
			return Global.Editor.Toolset.GetToolPanel("SelectTool").pathOptions
		"PatternShapeTool":
			return Global.Editor.Toolset.GetToolPanel("SelectTool").patternShapeOptions
		"WallTool":
			return Global.Editor.Toolset.GetToolPanel("SelectTool").wallOptions
		"PortalTool":
			return Global.Editor.Toolset.GetToolPanel("SelectTool").portalOptions
		_:
			outputlog("Error in find_select_grid_menu: vbox section not found. " + str(tool_name),4)
			return null

# Function to get the texture of a node based on tool_type
func get_asset_texture(node, tool_type: String):
	var texture = null

	match tool_type:
		"ObjectTool","ScatterTool","WallTool","PortalTool","objects","portals","walls":
			texture = node.Texture
		"PathTool", "LightTool","paths","lights":
			texture = node.get_texture()
		"PatternShapeTool","pattern_shapes":
			texture = node._Texture
		"RoofTool","roofs":
			texture = node.TilesTexture
		_:
			return null

	return texture

# Function to look at resource string and return the texture
func load_image_texture(texture_path: String):

	var image = Image.new()
	var texture = ImageTexture.new()

	# If it isn't an internal resource
	if not "res://" in texture_path:
		image.load(Global.Root + texture_path)
		texture.create_from_image(image)
	# If it is an internal resource then just use the ResourceLoader
	else:
		texture = ResourceLoader.load(texture_path)
	
	return texture

#########################################################################################################
##
## SELECT TOOL SIGNALS FUNCTION
##
#########################################################################################################

# Function to set up signals based on the options vboxes changing visibility
func setup_select_tool_options_change():

	outputlog("setup_select_tool_options_change")

	var vbox = find_select_vbox("ObjectTool")
	if vbox != null:
		vbox.connect("visibility_changed", self, "on_select_tool_option_visibility_changed", [vbox, "ObjectTool"])

# Function to respond when a select tool option becomes visible or hidden
func on_select_tool_option_visibility_changed(vbox: VBoxContainer, tool_type: String):

	outputlog("on_select_tool_option_visibility_changed: " + str(tool_type) + " visible: " + str(vbox.visible), 2)

	# If it has become visible then
	if vbox.visible && select_tool_panel.visible && show_button.pressed:
		ready_objectmenu_for_swap()
	else:
		hide_objectmenu_for_swap()

# Function to check if the selection has changed
func has_selection_changed() -> bool:

	outputlog("has_selection_changed: " + str(Global.Editor.Tools["SelectTool"].Selected),4)

	# Check if it has changed from the stored version and update it if it has changed
	if not is_the_same(store_last_valid_selection, Global.Editor.Tools["SelectTool"].Selected):
		store_last_valid_selection = Global.Editor.Tools["SelectTool"].Selected
		return true
	else:
		return false


#########################################################################################################
##
## CORE FUNCTION
##
#########################################################################################################

# Set the object menu to the right state. Note this fires on objectOptions visibility so refreshes the colours automatically.
func set_objectmenu_to_select_state():

	outputlog("set_objectmenu_to_select_state",2)

	var objectmenu = Global.Editor.ObjectLibraryPanel.objectMenu
	var texture
	var select_tool = Global.Editor.Tools["SelectTool"]

	objectmenu.select_mode = ItemList.SELECT_SINGLE	
	objectmenu.unselect_all()

	if select_tool.Selected.size() > 0:
		texture = get_asset_texture(select_tool.Selected[0],"ObjectTool")
		if texture != null:
			objectmenu.SelectTexture(texture)
		if select_tool.Selected[0].HasCustomColor():
			Global.Editor.ObjectLibraryPanel.objectMenu.SetCustomColor(select_tool.Selected[0].GetCustomColor())
		else:
			Global.Editor.ObjectLibraryPanel.objectMenu.SetCustomColor(select_tool_panel.objectColor.Color)
	else:
		Global.Editor.ObjectLibraryPanel.objectMenu.SetCustomColor(select_tool_panel.objectColor.Color)

# On new item selected in the object menu
func on_item_selected_in_objectmenu(index):

	var history_data = {}

	if Global.Editor.ActiveToolName == "SelectTool":
		var select_tool = Global.Editor.Tools["SelectTool"]
		outputlog("on_item_selected_in_objectmenu: " + str(index),2)
		if not Global.Editor.ObjectLibraryPanel.objectMenu.Lookup.keys().size() > index:
			return
		
		var texture_path = Global.Editor.ObjectLibraryPanel.objectMenu.Lookup.keys()[index]
		outputlog("new_texture: " + str(texture_path),2)
		var texture = load(texture_path)
		var is_custom_colourable = is_object_at_index_custom_colourable(index)
		outputlog("is_custom_colourable: " + str(is_custom_colourable),2)
		
		for item in select_tool.Selected:
			history_data[item.get_meta("node_id")] = {
				"old": {
					"texture_path": get_asset_texture(item,"ObjectTool").resource_path, 
					"hascustomcolor": item.HasCustomColor(),
					"customcolor": item.GetCustomColor()
					}
			}
				
			update_object_to_new_texture(item, texture, is_custom_colourable)
			history_data[item.get_meta("node_id")]["new"] = {
					"texture_path": texture.resource_path, 
					"hascustomcolor": item.HasCustomColor(),
					"customcolor": item.GetCustomColor()
					}
			
		select_tool.OnFinishSelection()
		select_tool.EnableTransformBox(true)

		create_update_custom_history(history_data)
	
# Update a object to a new texture
func update_object_to_new_texture(item: Node2D, texture: Texture, is_custom_colourable: bool):

	outputlog("update_object_to_new_texture",2)

	var color

	# If this is an object
	if get_node_type(item) == "objects":
		# Set the new texture
		item.SetTexture(texture)

		# If the object already has a custom colour then keep it
		if item.HasCustomColor():
			color = item.GetCustomColor()
		# If not then draw the value from the current select tool colour
		else:
			color = select_tool_panel.objectColor.Color
				
		# If the record in the object library has a custom colour options
		if is_custom_colourable:
			# Set the has custom colour to true
			item.hasCustomColor = true
			# Set the custom colour
			item.SetCustomColor(color)
			# Refresh the shader on the object
			reset_colourable_object_node(item)
		# Otherwise mark it as not custom colourable which should sort everything else out...
		else:
			item.hasCustomColor = false
			reset_noncolourable_object_node(item)
		Global.Editor.ObjectLibraryPanel.objectMenu.SetCustomColor(color)
		# If the node has a dropshadow then we need to update the shadow texture too
		if item.has_meta("dropshadow_enabled"):
			if item.get_node("5D03") != null:
				item.get_node("5D03").texture = texture

			

# Return whether an object in the object library is custom colourable (taken from its modulate value)
func is_object_at_index_custom_colourable(index: int):

	return Global.Editor.ObjectLibraryPanel.objectMenu.get_item_icon_modulate(index) == Color(1.0,0.0,0.0,1.0)

# Function to try and reset a colourable object node
func reset_colourable_object_node(node):

	outputlog("reset_colourable_object_node",2)

	var shader_material = ShaderMaterial.new()

	shader_material.shader = ResourceLoader.load("res://shaders/CustomColors.shader","Shader",true)
	shader_material.set_shader_param("tint_r", node.GetCustomColor())
	node.Sprite.material = shader_material

# Function to try and reset a colourable object node
func reset_noncolourable_object_node(node):

	outputlog("reset_noncolourable_object_node",2)

	var shader_material = ShaderMaterial.new()

	shader_material.shader = ResourceLoader.load("res://shaders/Object.shader","Shader",true)
	node.Sprite.material = shader_material


# When the select tool is hidden, then also hide the object library panel
func on_select_tool_panel_visibility_changed():

	outputlog("on_select_tool_panel_visibility_changed: " + str(select_tool_panel.visible),2)

	if not select_tool_panel.visible:
		Global.Editor.ObjectLibraryPanel.visible = false
		tags_panel.visible = false

func on_active_button_toggled(button_pressed: bool):

	if button_pressed:
		ready_objectmenu_for_swap()
	else:
		hide_objectmenu_for_swap()

func hide_objectmenu_for_swap():

	Global.Editor.ObjectLibraryPanel.visible = false
	tags_panel.visible = false

func ready_objectmenu_for_swap():

	Global.Editor.ObjectLibraryPanel.visible = true
	tags_panel.visible = true
	set_objectmenu_to_select_state()

# When the custom colour is changed, update the library panel
func _on_custom_colour_changed(_ignore_this):

	Global.Editor.ObjectLibraryPanel.objectMenu.SetCustomColor(select_tool_panel.objectColor.Color)

func on_objectmenu_button_toggled(button_pressed: bool, type: String):

	outputlog("on_objectmenu_button_toggled: " + str(type),2)

	if button_pressed && show_button.pressed && Global.Editor.ActiveToolName == "SelectTool":
		match type:
			"all":
				Global.Editor.ObjectLibraryPanel.ShowAllObjects()
				Global.Editor.ObjectLibraryPanel.filters.visible = true
			"used":
				Global.Editor.ObjectLibraryPanel.ShowUsedObjects()
				Global.Editor.ObjectLibraryPanel.filters.visible = false
			"tags":
				Global.Editor.ObjectLibraryPanel.ShowNoObjects()
				make_tags_panel_emit_selected_signal()
				Global.Editor.ObjectLibraryPanel.filters.visible = false

func make_tags_panel_emit_selected_signal():

	if tags_panel.tagsList.get_selected_items().size() > 0:
		tags_panel.tagsList.emit_signal("multi_selected",tags_panel.tagsList.get_selected_items(),true)

#########################################################################################################
##
## HISTORY FUNCTIONS
##
#########################################################################################################


# Create custom history record, called when a colour preset is selected, the color picker is closed, or a slider timer finishes
func create_update_custom_history(history_data: Dictionary):

	outputlog("create_update_custom_history",2)

	# Create a new record if one is needed or simply update the existing one
	var record_script = Script.InstanceReference("library/custom_history_record.gd")

	# If this is null for any reason then return to avoid a crash
	if record_script == null:
		outputlog("record_script is null",2)
		return

	record_script.history_data = history_data.duplicate(true)

	outputlog("record_script.history_data\n" + JSON.print(record_script.history_data,"\t"),2)

	# If this is a new action then create a new custom record
	var record = Global.Editor.History.CreateCustomRecord(record_script)

#########################################################################################################
##
## START FUNCTION
##
#########################################################################################################
# Main Script
func start() -> void:

	outputlog("ChangeObjectTexture Mod Has been loaded.")
	select_tool_panel = Global.Editor.Toolset.GetToolPanel("SelectTool")

	tags_panel = select_tool_panel.CreateTagsPanel()
	tags_panel.visible = false
	Global.Editor.ObjectLibraryPanel.objectMenu.connect("item_selected", self, "on_item_selected_in_objectmenu")
	select_tool_panel.connect("visibility_changed", self, "on_select_tool_panel_visibility_changed")

	setup_select_tool_options_change()
	# Set up the signals for pressing the all, used or tags buttons if the tool is active
	Global.Editor.ObjectLibraryPanel.allButton.connect("toggled", self, "on_objectmenu_button_toggled", ["all"])
	Global.Editor.ObjectLibraryPanel.usedButton.connect("toggled", self, "on_objectmenu_button_toggled", ["used"])
	Global.Editor.ObjectLibraryPanel.tagsButton.connect("toggled", self, "on_objectmenu_button_toggled", ["tags"])


	# Set up button to show/hide the object library panel
	show_button = Button.new()
	show_button.toggle_mode = true
	show_button.icon = load_image_texture("icons/transform-icon.png")
	show_button.text = "Enable Texture Swap"
	show_button.hint_tooltip = "Toggle to launch object library and change texture of selected objects."
	show_button.pressed = false
	show_button.connect("toggled", self, "on_active_button_toggled")
	select_tool_panel.objectOptions.add_child(show_button)

	# Connect to color palettes for objects to check for a change
	select_tool_panel.objectColor.colorList.connect("item_selected",self,"_on_custom_colour_changed")
	select_tool_panel.objectColor.popup.connect("modal_closed",self,"_on_custom_colour_changed",[0])
	select_tool_panel.objectColor.colorPicker.connect("color_changed",self,"_on_custom_colour_changed")

	# Register the mod with _lib if that mod is loaded
	if Engine.has_signal("_lib_register_mod"):
		Engine.emit_signal("_lib_register_mod", self)

		var update_checker = Global.API.UpdateChecker
		update_checker.register(Global.API.UpdateChecker.builder()\
														.fetcher(update_checker.github_fetcher("uchideshi34", "ChangeObjectTexture"))\
														.downloader(update_checker.github_downloader("uchideshi34", "ChangeObjectTexture"))\
														.build())

	




	

	

	
	


















	
