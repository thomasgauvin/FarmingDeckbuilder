extends CardData
class_name Rockbud

var tile: Tile

var callback: Callable
var event_type = EventManager.EventType.AfterGrow

# To be overridden by specific code seeds
func register_seed_events(event_manager: EventManager, p_tile: Tile):
	tile = p_tile
	tile.protected = true
	callback = func(args: EventArgs):
		tile.protected = true
	event_manager.register_listener(event_type, callback)

func unregister_seed_events(event_manager: EventManager):
	event_manager.unregister_listener(event_type, callback)

func copy():
	var new = Rockbud.new();
	new.assign(self)
	return new

func get_long_description():
	return Helper.get_long_description("protect") + "\n" + super.get_long_description()
