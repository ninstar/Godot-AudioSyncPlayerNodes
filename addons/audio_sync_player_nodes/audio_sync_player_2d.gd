@tool
@icon("audio_sync_player_2d.svg")

class_name AudioSyncPlayer2D extends AudioStreamPlayer2D


## Plays positional sound in 2D space while keeping other
## [b]AudioStreamPlayer2D[/b] in sync.
## 
## Plays positional sound in 2D space while keeping other
## [b]AudioStreamPlayer2D[/b] in sync. [member audio_players] are kept
## in sync if one or more exceeds the [member desync_threshold],
## checked every [member sync_interval]. [br][br]
## The following properties are also synchronized if changed on this node:
## [member AudioStreamPlayer2D.pitch_scale],
## [member AudioStreamPlayer2D.playing],
## [member AudioStreamPlayer2D.stream_paused]
## and [member AudioStreamPlayer2D.autoplay]. [br][br]
## See also [AudioSyncPlayer] to synchronize audios non-positionally.


enum ProcessCallback {
	## Synchronizes [member audio_players] during physics frames.
	## (See [constant Node.NOTIFICATION_INTERNAL_PHYSICS_PROCESS])
	PROCESS_PHYSICS,
	## Synchronizes [member audio_players] during process frames.
	## (See [constant Node.NOTIFICATION_INTERNAL_PROCESS])
	PROCESS_IDLE,
}


## The [AudioStreamPlayer2D] that will have its playback position and properties
## synchronized to this node.
@export var audio_players: Array[AudioStreamPlayer2D] = []: get = get_audio_players, set = set_audio_players

## The interval in which audio players are synchronized, in seconds.
@export_range(0.0, 4096.0, 0.001, "or_greater", "exp", "suffix:s") var sync_interval: float = 5.0: get = get_sync_interval, set = set_sync_interval

## The threshold for how far behind or ahead audio players can be, in seconds.
## Audio players are synchronized when the playback position of one of them
## exceeds this threshold.
@export_range(0.001, 4096.0, 0.001, "or_greater", "exp", "suffix:s") var desync_threshold: float = 0.01: get = get_desync_threshold, set = set_desync_threshold

## The process callback of the timer that synchronizes the audio players.
## (See [enum ProcessCallback])
@export var process_callback := ProcessCallback.PROCESS_IDLE: get = get_process_callback, set = set_process_callback

@onready var _sync_timer := Timer.new()


## Synchronizes all audio players.
## This method is called automatically by the process callback
## after every [member sync_interval].
func sync() -> void:
	if stream == null:
		return
	
	var delta: float = (get_process_delta_time()
			if process_callback == ProcessCallback.PROCESS_IDLE
			else get_physics_process_delta_time())
	var playback_position: float = get_playback_position()
	
	for i: int in audio_players.size():
		if not is_instance_valid(audio_players[i]):
			continue
		
		var diff: float = absf(playback_position-audio_players[i].get_playback_position())
		if audio_players[i].playing and diff > desync_threshold:
			audio_players[i].seek(playback_position+delta)


## Plays all audio players in sync from the given position
## ([param from_position]), in seconds.
func play_in_sync(from_position: float = 0.0) -> void:
	play(from_position)
	for i: int in audio_players.size():
		if is_instance_valid(audio_players[i]):
			audio_players[i].play(from_position)
	if sync_interval > 0.0:
		_sync_timer.start(sync_interval)


## Sets the position from which the audio players will be
## played in sync, in seconds.
func seek_in_sync(to_position: float) -> void:
	seek(to_position)
	for i: int in audio_players.size():
		if is_instance_valid(audio_players[i]):
			audio_players[i].seek(to_position)


## Stops all audio players simultaneously.
func stop_all() -> void:
	stop()
	for i: int in audio_players.size():
		if is_instance_valid(audio_players[i]):
			audio_players[i].stop()
	_sync_timer.stop()

#region Virtual methods

func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		add_child(_sync_timer)
		_sync_timer.timeout.connect(sync)
		
		for i: int in audio_players.size():
			audio_players[i].set_pitch_scale(pitch_scale)
			audio_players[i].set_stream_paused(stream_paused)
			audio_players[i].set_autoplay(autoplay)
			if playing:
				audio_players[i].play()
		
		if playing:
			if sync_interval > 0.0:
				_sync_timer.start(sync_interval)
			call_deferred(&"sync")


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"pitch_scale":
			for i: int in audio_players.size():
				if is_instance_valid(audio_players[i]):
					audio_players[i].set_pitch_scale(clampf(value, 0.00, 4.0))
			if playing:
				call_deferred(&"sync")
		&"stream_paused":
			for i: int in audio_players.size():
				if is_instance_valid(audio_players[i]):
					audio_players[i].set_stream_paused(value)
			if value == true:
				_sync_timer.stop()
			else:
				_sync_timer.start(sync_interval)
				call_deferred(&"sync")
		&"autoplay":
			for i: int in audio_players.size():
				if is_instance_valid(audio_players[i]):
					audio_players[i].set_autoplay(value)
		&"playing":
			if value == true:
				for i: int in audio_players.size():
					if is_instance_valid(audio_players[i]):
						audio_players[i].play(get_playback_position())
				if sync_interval > 0.0:
					_sync_timer.start(sync_interval)
				call_deferred(&"sync")
			else:
				for i: int in audio_players.size():
					if is_instance_valid(audio_players[i]):
						audio_players[i].stop()
				_sync_timer.stop()
	return false

#endregion
#region Getters & Setters

# Getters

func get_audio_players() -> Array[AudioStreamPlayer2D]:
	return audio_players


func get_sync_interval() -> float:
	return sync_interval


func get_desync_threshold() -> float:
	return desync_threshold


func get_process_callback() -> ProcessCallback:
	return process_callback

# Setters

func set_audio_players(value: Array[AudioStreamPlayer2D]) -> void:
	audio_players = value


func set_sync_interval(value: float) -> void:
	sync_interval = value
	if not is_node_ready():
		await ready
	if sync_interval > 0.0 and playing:
		_sync_timer.wait_time = sync_interval
		_sync_timer.start(sync_interval)
	else:
		if not _sync_timer.is_stopped():
			_sync_timer.stop()


func set_desync_threshold(value: float) -> void:
	desync_threshold = value


func set_process_callback(value: ProcessCallback) -> void:
	process_callback = value
	if not is_node_ready():
		await ready
	_sync_timer.process_callback = int(process_callback)

#endregion
