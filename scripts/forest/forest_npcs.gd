extends RefCounted

const DIR := "res://assets/forest/npc/"
const NPCS := [
	{"id":"spectral_lamplighter", "zone":"central_clearing", "position":Vector2(520,560), "front":"Spectral_Lamplighter_FRONT.png", "side":"Spectral_Lamplighter_SIDE_RIGHT.png", "action_id":"guide"},
	{"id":"minor_astral_stag", "zone":"central_clearing", "position":Vector2(1380,565), "front":"Minor_Astral_Stag_front.png", "side":"Minor_Astral_Stag_side_right.png", "action_id":"ambient"},
	{"id":"moss_ruin_guardian", "zone":"alchemical_ruins", "position":Vector2(550,540), "front":"Moss_Ruin_Guardian_FRONT.png", "side":"Moss_Ruin_Guardian_SIDE_RIGHT.png", "action_id":"forge"},
	{"id":"neon_fungal_monk", "zone":"alchemical_ruins", "position":Vector2(1390,570), "front":"Neon_Fungal_Monk_front.png", "side":"Neon_Fungal_Monk_side_right.png", "action_id":"lab"},
	{"id":"crystal_medusa", "zone":"crystal_grove", "position":Vector2(1370,530), "front":"Crystal_Medusa_Front_1024.png", "side":"Crystal_Medusa_Side_Right_1024.png", "action_id":"expeditions"},
	{"id":"mycelial_oracle", "zone":"ethereal_mist", "position":Vector2(610,620), "front":"Mycelial_Oracle_Front.png", "side":"Mycelial_Oracle_Side_Right.png", "action_id":"lore"},
	{"id":"underbrush_eye", "zone":"ethereal_mist", "position":Vector2(1390,620), "front":"Underbrush_Eye_front.png", "side":"Underbrush_Eye_side_right.png", "action_id":"lore"},
	{"id":"threshold_mask_spirit2", "zone":"arcane_sanctuary", "position":Vector2(1310,570), "front":"Threshold_Mask_Spirit2_FRONT.png", "side":"Threshold_Mask_Spirit2_SIDE_RIGHT.png", "action_id":"world_gate"},
	{"id":"bark_witch", "zone":"duel_clearing", "position":Vector2(1430,590), "front":"Bark_Witch_front.png", "side":"Bark_Witch_side_right.png", "action_id":"ranked"}
]
