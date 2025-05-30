extends StrEffect
class_name PickCardEffect

var PickOption = preload("res://src/ui/pick_option.tscn")
var SelectCard = preload("res://src/cards/select_card.tscn")

enum PickFrom {
	Hand,
	Discard,
	Burned,
	RandomSeed,
	Blight,
	HandCost1
}

enum AndThen {
	Draw,
	Burn,
	Use
}

@export var timing2: EventManager.EventType
@export var count: int
@export var pick_from: PickFrom
@export var and_then: AndThen
@export var skippable: bool

var card: CardData = null
var callback2: Callable
var tile: Tile = null

# An effect involving picking cards
# Pick 
# * any card if count == -1
# * 1 of (count + strength) cards if count != -1
# From (pick_from)
# * hand or discard pile or burned cards or random seeds or blight cards
# And Then (and_then)
# * Draw (1 + strength) copies if count == -1
# * Burn the card
# * Immediately play the card
# Can only be strengthened if and_then==draw
# timing1 is the timing on which you pick the card which is AfterCardPlayed unless it's a seed where the effect scales which size then -> OnActionCardUsed
# timing2 is the timing on which the and_then occurs
# Should pretty much either be OnPlantHarvest (for seed effect like iris)
# or AfterCardPlayed for immediate effect (burn, add card to hand)

func _init(p_timing = EventManager.EventType.AfterCardPlayed, p_seed = false, p_strength = 1.0,
	p_base_strength = 1.0, p_strength_increment = 1.0, p_timing_2 = EventManager.EventType.AfterCardPlayed, p_count = -1, p_pick_from = PickFrom.Hand,
	p_and_then = AndThen.Draw, p_skippable = false):
	super(p_timing, p_seed, p_strength, p_base_strength, p_strength_increment)
	timing2 = p_timing_2
	count = p_count
	pick_from = p_pick_from
	and_then = p_and_then

func register(event_manager: EventManager, p_tile: Tile):
	tile = p_tile
	callback = func(args: EventArgs):
		pick_card_event(args)

	callback2 = func(args: EventArgs):
		# If timing2 is Plant Harvest, it must not trigger when other plants are harvested
		if timing2 != EventManager.EventType.OnPlantHarvest or args.specific.tile == tile:
			do_followup_action(args)
	
	event_manager.register_listener(timing, callback)
	
	# As an exception the AfterCardPlayed trigger is done immediately
	# after timing1 function is executed
	if timing2 != EventManager.EventType.AfterCardPlayed:
		event_manager.register_listener(timing2, callback2)

func pick_card_event(args: EventArgs):
	if card != null:
		return
	var options = []
	match pick_from:
		PickFrom.Hand:
			options.assign(args.cards.get_hand_info())
		PickFrom.HandCost1:
			options.assign(args.cards.get_hand_info().filter(func(card_data):
				return card_data.cost <= strength))
		PickFrom.Discard:
			options.assign(args.cards.discard_pile_cards)
		PickFrom.Burned:
			pass
		PickFrom.RandomSeed:
			options.assign(pick_from_random_seed())
		PickFrom.Blight:
			options.assign(DataFetcher.get_element_cards("blight"))
	if count != -1:
		options.shuffle()
	display_options(args, options, func(card_data):
		card = card_data
		if timing == EventManager.EventType.OnActionCardUsed:
			args.specific.tile.play_effect_particles()
		if timing2 == EventManager.EventType.AfterCardPlayed:
			do_followup_action(args))

func pick_from_random_seed():
	var cards = DataFetcher.get_all_cards()
	var candidates = []
	for card in cards:
		if card.type == "SEED" and card.rarity != "basic" and card.rarity != "unique" and card.rarity != "legendary":
			candidates.append(card)
	return candidates

func display_options(args: EventArgs, options: Array, set_card: Callable):
	if options.size() == 0:
		set_card.call(load("res://src/cards/data/unique/void.tres"))
		return
	if count > 0:
		options = options.slice(0, count + strength)
	if options.size() == 1 and !skippable and pick_from == PickFrom.Hand:
		set_card.call(options[0])
	elif options.size() <= 7:
		var pick_option_ui = PickOption.instantiate()
		args.user_interface.add_child(pick_option_ui)
		var prompt = "Pick a card"
		var cancel_callback = null if !skippable else func():
			args.user_interface.remove_child(pick_option_ui)
			set_card.call(null)

		pick_option_ui.setup(prompt, options, func(selected):
			set_card.call(selected)
			args.user_interface.remove_child(pick_option_ui), cancel_callback)
	else:
		var select_card = SelectCard.instantiate()
		select_card.tooltip = args.user_interface.tooltip
		select_card.size = Constants.VIEWPORT_SIZE
		select_card.z_index = 2
		select_card.theme = load("res://assets/theme_large.tres")
		if !skippable:
			select_card.disable_cancel()
		select_card.select_callback = func(card_data: CardData):
			args.user_interface.remove_child(select_card)
			set_card.call(card_data)
		select_card.select_cancelled.connect(func():
			args.user_interface.remove_child(select_card)
			set_card.call(null))
		args.user_interface.add_child(select_card)
		select_card.do_card_pick(args.cards.discard_pile_cards, "Select a card")

func do_followup_action(args: EventArgs):
	if and_then == AndThen.Burn:
		args.cards.remove_card_with_info(card)
		args.cards.notify_card_burned(card)
		card = null
	elif and_then == AndThen.Draw:
		for i in range(strength if count == -1 else 1):
			args.cards.draw_specific_card_from(card, args.user_interface.get_global_mouse_position())
	elif and_then == AndThen.Use:
		Global.selected_card = card
		Global.LOCK = false
		args.farm.use_card(tile.grid_location, true)
		Global.LOCK = true
		Global.selected_card = null

func unregister(event_manager: EventManager):
	event_manager.unregister_listener(timing, callback)
	if timing2 != EventManager.EventType.AfterCardPlayed:
		event_manager.unregister_listener(timing2, callback2)

func get_description(size: int):
	var descr = ""
	if card == null:
		descr += get_timing_text(timing) + get_pick_from_description() + get_and_then_description()
	else:
		descr += get_and_then_description()
	return get_description_interp(descr)

func get_pick_from_description():
	var count_text = ""
	if count == -1:
		count_text = " a card "
	elif strength > base_strength:
		count_text = " 1 of [color=aqua]" + str(count + strength) + "[/color] cards"
	else:
		count_text = " 1 of " + str(count) + " cards"

	match pick_from:
		PickFrom.Hand:
			return "Pick" + count_text + "from your hand"
		PickFrom.HandCost1:
			return "Pick" + count_text.replace("card", ("[color=aqua]" if strength > 1 else "")\
			+ str(strength) + "-cost" + ("[/color]" if strength > 1 else "") + " card")\
			 + "from your hand"
		PickFrom.Discard:
			return "Pick" + count_text + "from your discard pile"
		PickFrom.Burned:
			return "Pick" + count_text + "from those burned this year"
		PickFrom.RandomSeed:
			return ("Pick" + count_text).replace("cards", "random Seed cards")
		PickFrom.Blight:
			return "Pick" + count_text + "Blight cards"
		_:
			return "card"

func get_and_then_description():
	var count_text = ""
	if count == -1 and strength > 1:
		count_text = " [color=aqua]" + str(strength) + " copies[/color] "
		if card != null:
			count_text += "of " + card.name + " "
	elif card == null:
		count_text = " a copy "
	else:
		count_text = " " + card.name + " "
	match and_then:
		AndThen.Draw:
			if timing2 == EventManager.EventType.AfterCardPlayed:
				return " and add" + count_text + "to your hand"
			else:
				return (". " if card == null else "") + get_timing_text(timing2) + "Add" + count_text + "to your hand"
		AndThen.Burn:
			return " and [color=gold]Burn[/color] it"
		AndThen.Use:
			return (". " if card == null else "") + get_timing_text(timing2) + "Cast " + ("it" if card == null else card.name) + " on this plant"

func copy():
	var copy = PickCardEffect.new()
	copy.assign(self)
	return copy

func save_data() -> Dictionary:
	var save_dict = super.save_data()
	save_dict["count"] = count
	save_dict["pick_from"] = pick_from
	save_dict["and_then"] = and_then
	save_dict["skippable"] = skippable
	save_dict["timing2"] = timing2
	return save_dict

func load_data(data) -> Effect2:
	super.load_data(data)
	count = data.count
	pick_from = data.pick_from
	and_then = data.and_then
	skippable = data.skippable
	timing2 = data.timing2
	return self

func assign(other):
	super.assign(other)
	count = other.count
	pick_from = other.pick_from
	and_then = other.and_then
	skippable = other.skippable
	timing2 = other.timing2
	card = other.card
	return self

func can_strengthen():
	return and_then == AndThen.Draw or pick_from == PickFrom.HandCost1

func get_long_description():
	if and_then == AndThen.Burn:
		return Helper.get_long_description("burn")
	return ""
