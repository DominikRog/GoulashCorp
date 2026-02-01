extends Node

# Configuration data for all acts in the game

var acts = {
	1: {
		"character": "demon",
		"next_character": "farmer",
		"shapes": ["Clue_Farmer_1", "Clue_Farmer_2"],
		"question": "Who lives by the sun, yet works by the merchant’s call?",
		"answers": [
			{"text": "Farmer", "correct": true},
			{"text": "Sailor", "correct": false},
			{"text": "Shepherd", "correct": false}
		],
		"timer": 45,
		"dialogue_before": "You emerge from the shadows, a formless demon seeking flesh..."
	},
	2: {
		"character": "farmer",
		"next_character": "merchant",
		"shapes": ["Clue_Merchant_1", "Clue_Merchant_2"],
		"question": "Who sells what they never make, and buys what they never truly need?",
		"answers": [
			{"text": "Thief", "correct": false},
			{"text": "Noble", "correct": false},
			{"text": "Merchant", "correct": true}
		],
		"timer": 50,
		"dialogue_before": "The farmer's body fits well... but you hunger for more."
	},
	3: {
		"character": "merchant",
		"next_character": "guardsman",
		"shapes": ["Clue_Guard_1", "Clue_Guard_2"],
		"question": "Who stops the many, in the name of the more important few?",
		"answers": [
			{"text": "Guardsman", "correct": true},
			{"text": "Tax Collector", "correct": false},
			{"text": "Judge", "correct": false}
		],
		"timer": 55,
		"dialogue_before": "Coin and comfort are not enough. You need power."
	},
	4: {
		"character": "guardsman",
		"next_character": "jester",
		"shapes": ["Clue_Jester_1", "Clue_Jester_2"],
		"question": "Who speaks the truth by pretending to lie?",
		"answers": [
			{"text": "Prophet", "correct": false},
			{"text": "Jester", "correct": true},
			{"text": "Spy", "correct": false}
		],
		"timer": 60,
		"dialogue_before": "A soldier's strength is limited. You need access to the throne."
	},
	5: {
		"character": "jester",
		"next_character": "queen",
		"shapes": ["Clue_Queen_1", "Clue_Queen_2"],
		"question": "Who may change a kingdom, but cannot change its laws?",
		"answers": [
			{"text": "General", "correct": false},
			{"text": "Queen", "correct": true},
			{"text": "Judge", "correct": false}
		],
		"timer": 65,
		"dialogue_before": "So close now... one more step to the throne."
	},
	6: {
		"character": "queen",
		"next_character": "king",
		"shapes": ["Clue_King", "Clue_King_2"],  # Using Queen clues for now until King shapes exist
		"question": "Who, with a single decision, can alter hundreds more?",
		"answers": [
			{"text": "King", "correct": true},
			{"text": "Priest", "correct": false},
			{"text": "Warrior", "correct": false}
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
