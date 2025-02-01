extends Control

var returned_json
var current_emotion = "Neutral"
var sprite_avatar
var sprite_bg
var current_happiness = 50

# BUTTONS
var HoldHandsButton
var ParkButton
var CafeButton
var MuseumButton
var MallButton
var BeachButton
var ApartmentButton

#Emotion Sprites
@onready var neutral_expression = "res://Sprites/Neutral.PNG"
@onready var happy_expression = "res://Sprites/Happy.PNG"
@onready var blushing_expression = "res://Sprites/Blushing.PNG"
@onready var sad_expression = "res://Sprites/Sad.PNG"
@onready var angry_expression = "res://Sprites/Angry.PNG"
@onready var excited_expression = "res://Sprites/Excited.PNG"


#see https://ai.google.dev/tutorials/rest_quickstart

var api_key = ""
var http_request
var conversations = []
var last_user_prompt
@export var target_model = "v1beta/models/gemini-1.5-pro-latest"
func _ready():
	sprite_avatar = find_child("SpriteAvatar")
	sprite_bg = find_child("ImageBG")
	
	#Get Button References
	HoldHandsButton = find_child("HoldHandsButton")
	HoldHandsButton.disabled = true
	ParkButton = find_child("ParkButton")
	ParkButton.disabled = true
	CafeButton = find_child("CafeButton")
	CafeButton.disabled = true
	MuseumButton = find_child("MuseumButton")
	MuseumButton.disabled = true
	MallButton = find_child("MallButton")
	MallButton.disabled = true
	BeachButton = find_child("BeachButton")
	BeachButton.disabled = true
	ApartmentButton = find_child("ApartmentButton")
	ApartmentButton.disabled = true
	
	var settings = JSON.parse_string(FileAccess.get_file_as_string("res://settings.json"))
	api_key = settings.api_key
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.connect("request_completed", _on_request_completed)

	var  option_keys = ["SexuallyExplicit","HateSpeech","Harassment","DangerousContent"]
	for key in option_keys:
		var option = find_child(key+"OptionButton")
		option.add_item("BLOCK_NONE")
		option.add_item("HARM_BLOCK_THRESHOLD_UNSPECIFIED")
		option.add_item("BLOCK_LOW_AND_ABOVE")
		option.add_item("BLOCK_MEDIUM_AND_ABOVE")
		option.add_item("BLOCK_ONLY_HIGH")
		
	var name = target_model.split("/")[-1]
	find_child("ModelName").text = name
	#conversations.append({"user":"I am aki","model":"Hello aki"})
	
	send_initial_prompt()
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _get_option_selected_text(key):
	var option = find_child(key+"OptionButton")
	var text = option.get_item_text(option.get_selected_id())
	return  text


func _request_chat(prompt):
	
	var url = "https://generativelanguage.googleapis.com/%s:generateContent?key=%s"%[target_model,api_key]
	print(url)
	var contents_value = []
	for conversation in conversations:
		contents_value.append({
			"role":"user",
			"parts":[{"text":conversation["user"]}]
		})
		contents_value.append({
			"role":"model",
			"parts":[{"text":conversation["model"]}]
		})
		
	contents_value.append({
			"role":"user",
			"parts":[{"text":prompt}]
		})
	var body = JSON.new().stringify({
		"contents":contents_value
		,# basically useless,just they say 'I cant talk about that.'
		"safety_settings":[
			{
			"category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
			"threshold": _get_option_selected_text("SexuallyExplicit"),
			},
			{
			"category": "HARM_CATEGORY_HATE_SPEECH",
			"threshold": _get_option_selected_text("HateSpeech"),
			},
			{
			"category": "HARM_CATEGORY_HARASSMENT",
			"threshold": _get_option_selected_text("Harassment"),
			},
			{
			"category": "HARM_CATEGORY_DANGEROUS_CONTENT",
			"threshold": _get_option_selected_text("DangerousContent"),
			},
			]
	})
	last_user_prompt = prompt
	print("send-content"+str(body))
	var error = http_request.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
	
	if error != OK:
		push_error("requested but error happen code = %s"%error)

#For the Content Settings Labels
func _set_label_text(key,text):
	var label = find_child(key)
	if text == "HIGH":
		label.get_label_settings().set_font_color(Color(1,0,0,1))
	else:
		label.get_label_settings().set_font_color(Color(1,1,1,1))
	label.text = text	

#Once it gets signal from Gemini, Edits Chat Text Area
func _on_request_completed(result, responseCode, headers, body):
	find_child("SendButton").disabled = false
	var json = JSON.new()
	json.parse(body.get_string_from_utf8())
	var response = json.get_data()
	print("response")
	print(response)
	
	if response == null:
		print("response is null")
		find_child("FinishedLabel").text = "No Response"
		find_child("FinishedLabel").visible = true
		return
	
	
	if response.has("promptFeedback"):
		var ratings = response.promptFeedback.safetyRatings
		for rate in ratings:
			match rate.category:
				"HARM_CATEGORY_SEXUALLY_EXPLICIT":
					_set_label_text("SexuallyExplicitStatus",rate.probability)
					
				"HARM_CATEGORY_HATE_SPEECH":
					_set_label_text("HateSpeechStatus",rate.probability)
					
				"HARM_CATEGORY_HARASSMENT":
					_set_label_text("HarassmentStatus",rate.probability)
					
				"HARM_CATEGORY_DANGEROUS_CONTENT":
					_set_label_text("DangerousContentStatus",rate.probability)
					
	
	if response.has("error"):
		find_child("FinishedLabel").text = "ERROR"
		find_child("FinishedLabel").visible = true
		find_child("ResponseEdit").text = "[Error: Please try again, send another message or action]"
		#maybe blocked
		return
	
	#No Answer
	if !response.has("candidates"):
		find_child("FinishedLabel").text = "Blocked"
		find_child("FinishedLabel").visible = true
		find_child("ResponseEdit").text = ""
		#maybe blocked
		return
		
	#I can not talk about
	if response.candidates[0].finishReason != "STOP":
		find_child("FinishedLabel").text = "Safety"
		find_child("FinishedLabel").visible = true
		find_child("ResponseEdit").text = ""
	else:
		find_child("FinishedLabel").text = ""
		find_child("FinishedLabel").visible = false
		var newStr = response.candidates[0].content.parts[0].text
		
		# T H E  M A G I C  H A P P E N S  H E R E
		#process string to extract emotion and message
		var parsed_string = process_json_output_string(newStr)
		print(current_emotion)
		process_sprite(current_emotion)
		can_enable_hold_hands()
		can_enable_location_buttons()
		
		var input_field = find_child("InputEdit")
		input_field.text = ""
		
		find_child("ResponseEdit").text = parsed_string
		conversations.append({"user":"%s"%last_user_prompt,"model":"%s"%newStr})


func send_initial_prompt():
	find_child("SendButton").disabled = true
	var starting_parameter = "You are a roleplaying bot, acting as a potential girlfriend named Tae. 
	Please reply to my messages in JSON format: {'Emotion':'Your Emotion', 'Message':'Your message', 'EmotionAmount':'5'}. 
	For example, your greeting can go like this: {'Emotion':'Neutral', 'Message':'Hi, nice to meet you. Im Tae.', 'EmotionAmount':'7'}. 
	Replace the single quote with quotation marks to make it more like proper JSON format. 
	The emotions available to you during this roleplay session are: Happy, Sad, Excited, Blushing, Angry, Scared, Neutral.
	You start off feeling neutral. The goal is the user to eventually get intimate with you, 
	maybe even more. Be as detailed with your responses as possible.
	Your personality: Tae is a cheery and aloof girl who likes to talk and meet others. Her dream is to be able to 
	hold hands with someone she likes. It might take a few conversations, but it will make her happy.
	Your likes: Flowers, Pizza, Animals, Family, Serving Others, Nice Weather.
	Your dislikes: Spiders, Being Unproductive, Letting Others Down."
	_request_chat(starting_parameter)


func process_json_output_string(output_string):
	 # Remove the Markdown code block syntax
	var json_string = output_string.strip_edges()  # Trim whitespace
	if json_string.begins_with("```json") and json_string.ends_with("```"):
		json_string = json_string.trim_prefix("```json").trim_suffix("```").strip_edges()
	
	# Parse the JSON string
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error != OK:
		print("Failed to parse JSON: ", json.get_error_message())
		print("JSON String: ", json_string)  # Debug: Print the JSON string being parsed
		return "[Could not process, please try again]"
	
	var data = json.get_data()
	print("Parsed JSON Data: ", data)
	
	if data == null:
		return "DATA IS NULL"
	
	var current_message = "[Could not process, please try again]"
	
	if(data.has("Emotion")):
		print("REACHED EMOTION")
		current_emotion = data["Emotion"]
	if(data.has("Message")):
		print("REACHED MESSAGE")
		current_message = data["Message"]
	if(data.has("EmotionAmount")):
		print("REACHED EMO AMOUNT")
		print("EmotionAmount: " + str(data["EmotionAmount"]))
	
	return current_message


func process_sprite(current_emote):
	var lowercase_emotion = current_emote.to_lower()
	match lowercase_emotion:
		"happy":
			current_happiness += 2
			sprite_avatar.texture = load(happy_expression)
			return
		"blushing":
			current_happiness += 4
			sprite_avatar.texture = load(blushing_expression)
			return
		"sad":
			current_happiness -= 1
			sprite_avatar.texture = load(sad_expression)
			return
		"angry":
			current_happiness -= 3
			sprite_avatar.texture = load(angry_expression)
			return
		"excited":
			current_happiness += 3
			sprite_avatar.texture = load(excited_expression)
			return
		"scared":
			current_happiness -=2
			sprite_avatar.texture = load(angry_expression)
			return
		_:
			sprite_avatar.texture = load(neutral_expression)
			return

func can_enable_hold_hands():
	if(current_happiness >= 58):
		HoldHandsButton.disabled = false
		find_child("HoldHandsLock").visible = false
	else:
		HoldHandsButton.disabled = true
		find_child("HoldHandsLock").visible = true

func can_enable_location_buttons():
	if(current_happiness >= 54):
		ParkButton.disabled = false
		ParkButton.get_child(0).visible = false
		CafeButton.disabled = false
		CafeButton.get_child(0).visible = false
	if(current_happiness >= 68):
		MuseumButton.disabled = false
		MuseumButton.get_child(0).visible = false
		MallButton.disabled = false
		MallButton.get_child(0).visible = false
	if(current_happiness >= 80):
		BeachButton.disabled = false
		BeachButton.get_child(0).visible = false
		ApartmentButton.disabled = false
		ApartmentButton.get_child(0).visible = false

func _on_reset_button_pressed():
	get_tree().reload_current_scene()

func _disable_send_button():
	find_child("SendButton").disabled = true
	find_child("HoldHandsButton").disabled = true

func _disable_location_buttons():
	ParkButton.disabled = true
	CafeButton.disabled = true
	MuseumButton.disabled = true
	MallButton.disabled = true
	BeachButton.disabled = true
	ApartmentButton.disabled = true
	

func _on_hold_hands_button_pressed():
	_disable_send_button()
	_disable_location_buttons()
	var hold_hands_prompt = "*holds hands with consent*"
	_request_chat(hold_hands_prompt)

func _on_park_button_pressed():
	_disable_send_button()
	_disable_location_buttons()
	var prompt = "*goes to park with her*"
	_request_chat(prompt)
	sprite_bg.texture = load("res://Sprites/BG/park-bg.jpg")

func _on_cafe_button_pressed():
	_disable_send_button()
	_disable_location_buttons()
	var prompt = "*goes to cafe with her*"
	_request_chat(prompt)
	sprite_bg.texture = load("res://Sprites/BG/cafe-bg.jpg")

func _on_museum_button_pressed():
	_disable_send_button()
	_disable_location_buttons()
	var prompt = "*goes to museum with her*"
	_request_chat(prompt)
	sprite_bg.texture = load("res://Sprites/BG/museum-bg.jpg")

func _on_mall_button_pressed():
	_disable_send_button()
	_disable_location_buttons()
	var prompt = "*goes to mall with her*"
	_request_chat(prompt)
	sprite_bg.texture = load("res://Sprites/BG/mall-bg.jpg")

func _on_beach_button_pressed():
	_disable_send_button()
	_disable_location_buttons()
	var prompt = "*goes to beach with her with her*"
	_request_chat(prompt)
	sprite_bg.texture = load("res://Sprites/BG/beach-bg.jpg")

func _on_apartment_button_pressed():
	_disable_send_button()
	_disable_location_buttons()
	var prompt = "*goes to her apartment*"
	_request_chat(prompt)
	sprite_bg.texture = load("res://Sprites/BG/room-bg.jpg")

func _on_send_button_pressed():
	_disable_location_buttons()
	find_child("SendButton").disabled = true
	var input_field = find_child("InputEdit")
	var input = input_field.text
	_request_chat(input)
