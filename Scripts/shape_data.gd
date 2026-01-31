extends Node

# Configuration data for all acts in the game

var acts = {
	1: {
		"character": "demon",
		"next_character": "farmer",
		"shapes": ["placeholder", "wheat"],
		"question": "What did you do your whole life?",
		"answers": [
			{"text": "Slave away at a farm", "correct": true},
			{"text": "Lead a successful business", "correct": false},
			{"text": "Guard the castle walls", "correct": false}
		],
		"timer": 45,
		"dialogue_before": "You emerge from the shadows, a formless demon seeking flesh..."
	},
	2: {
		"character": "farmer",
		"next_character": "merchant",
		"shapes": ["coin", "chest"],  # Placeholder - will be defined later
		"question": "Where did your fortune come from?",
		"answers": [
			{"text": "Trading goods in the market", "correct": true},
			{"text": "Working the land with my hands", "correct": false},
			{"text": "Serving the crown with honor", "correct": false}
		],
		"timer": 50,
		"dialogue_before": "The farmer's body fits well... but you hunger for more."
	},
	3: {
		"character": "merchant",
		"next_character": "guardsman",
		"shapes": ["sword", "shield"],  # Placeholder - will be defined later
		"question": "What is your duty?",
		"answers": [
			{"text": "Protect the realm from threats", "correct": true},
			{"text": "Entertain the court with wit", "correct": false},
			{"text": "Accumulate wealth and influence", "correct": false}
		],
		"timer": 55,
		"dialogue_before": "Coin and comfort are not enough. You need power."
	},
	4: {
		"character": "guardsman",
		"next_character": "jester",
		"shapes": ["mask", "bells"],  # Placeholder - will be defined later
		"question": "How do you move through the court?",
		"answers": [
			{"text": "With laughter and hidden truths", "correct": true},
			{"text": "With blade and unwavering duty", "correct": false},
			{"text": "With grace and royal bearing", "correct": false}
		],
		"timer": 60,
		"dialogue_before": "A soldier's strength is limited. You need access to the throne."
	},
	5: {
		"character": "jester",
		"next_character": "queen",
		"shapes": ["crown", "scepter"],  # Placeholder - will be defined later
		"question": "Who sits beside the king?",
		"answers": [
			{"text": "The Queen, with grace and power", "correct": true},
			{"text": "The fool, whispering advice", "correct": false},
			{"text": "The guard, ever vigilant", "correct": false}
		],
		"timer": 65,
		"dialogue_before": "So close now... one more step to the throne."
	},
	6: {
		"character": "queen",
		"next_character": "victory",
		"shapes": ["throne", "orb"],  # Placeholder - will be defined later
		"question": "What do you seek?",
		"answers": [
			{"text": "Ultimate power over all", "correct": true},
			{"text": "A life of simple pleasures", "correct": false},
			{"text": "To serve with loyalty", "correct": false}
		],
		"timer": 70,
		"dialogue_before": "The Queen's body is yours. The final step awaits..."
	}
}

func get_act(act_number: int) -> Dictionary:
	"""Get configuration for a specific act"""
	if acts.has(act_number):
		return acts[act_number]
	return {}

func get_shapes_for_act(act_number: int) -> Array:
	"""Get the list of shape names for an act"""
	var act_data = get_act(act_number)
	if act_data.has("shapes"):
		return act_data["shapes"]
	return []

func get_timer_for_act(act_number: int) -> float:
	"""Get the timer duration for an act"""
	var act_data = get_act(act_number)
	if act_data.has("timer"):
		return float(act_data["timer"])
	return 45.0  # Default fallback

func get_question_data(act_number: int) -> Dictionary:
	"""Get question and answers for the mind puzzle"""
	var act_data = get_act(act_number)
	return {
		"question": act_data.get("question", ""),
		"answers": act_data.get("answers", [])
	}
