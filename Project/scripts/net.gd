extends Node

# Host-authoritative races over Godot's ENet peer. The host runs the cars, the
# battle and the items. Everyone else sends inputs and applies the host's
# snapshot. One machine hosts; the others join it. There is no dedicated server.

signal changed

const MAX_PLAYERS := 4
const DEFAULT_PORT := 7777

var online := false
var in_match := false
var port := DEFAULT_PORT
var status := ""
var peers: Array[Dictionary] = []
var slot := 0
var local_model := 0
var local_expert := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(_connection_failed)
	multiplayer.server_disconnected.connect(_server_disconnected)


func is_host() -> bool:
	return online and multiplayer.is_server()


func puppet() -> bool:
	return in_match and online and not multiplayer.is_server()


func host(listen_port: int) -> void:
	close()
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(listen_port, MAX_PLAYERS - 1) != OK:
		status = "Port %d is already in use" % listen_port
		changed.emit()
		return
	multiplayer.multiplayer_peer = peer
	online = true
	port = listen_port
	local_model = 0
	local_expert = 0
	peers.clear()
	peers.append({id = 1, model = 0, expert = 0})
	sort_peers()
	status = "Hosting"
	changed.emit()


func join(address: String, join_port: int) -> void:
	close()
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(address, join_port) != OK:
		status = "Could not connect"
		changed.emit()
		return
	multiplayer.multiplayer_peer = peer
	online = true
	port = join_port
	status = "Connecting..."
	changed.emit()


func close() -> void:
	online = false
	in_match = false
	peers.clear()
	slot = 0
	drop_peer()
	changed.emit()


func push_profile() -> void:
	if not online or in_match:
		return
	if multiplayer.is_server():
		apply_profile(1, local_model, local_expert)
	else:
		submit_profile.rpc_id(1, local_model, local_expert)


func begin_battle(path: String, level_text := "", source := "", bumper := false) -> void:
	if not is_host() or peers.size() < 2:
		status = "Need at least two players"
		changed.emit()
		return
	if level_text != "":
		share_level.rpc(path, level_text)
	if source.ends_with(".json"):
		Session.queue_course(source, path)
	var models := PackedInt32Array()
	var experts := PackedInt32Array()
	for peer in peers:
		models.append(int(peer.model))
		experts.append(int(peer.expert))
	begin.rpc(path, models, experts, Battle.target, Battle.pickups, false, -1, bumper)


func begin_trial(path: String, level_text := "", source := "") -> void:
	if not is_host() or peers.size() < 2:
		status = "Need at least two players"
		changed.emit()
		return
	if level_text != "":
		share_level.rpc(path, level_text)
	if source.ends_with(".json"):
		Session.queue_course(source, path)
	var models := PackedInt32Array()
	var experts := PackedInt32Array()
	for peer in peers:
		models.append(int(peer.model))
		experts.append(int(peer.expert))
	begin.rpc(path, models, experts, Battle.target, Battle.pickups, true, Settings.ghost_model(path), false)


func restart_trial(path: String) -> void:
	var models := PackedInt32Array()
	var experts := PackedInt32Array()
	for i in Battle.players:
		models.append(Battle.models[i])
		experts.append(Battle.experts[i])
	begin.rpc(path, models, experts, Battle.target, Battle.pickups, true, Settings.ghost_model(path), false)


func publish_input() -> void:
	var accel := clampi(roundi(Input.get_action_strength("accelerate") * 7.0), 0, 7)
	var brake := clampi(roundi(Input.get_action_strength("brake") * 7.0), 0, 7)
	var steer := clampi(roundi(Input.get_axis("steer_left", "steer_right") * 7.0), -7, 7)
	var bits := accel | brake << 3 | (steer + 7) << 6
	if Input.is_action_pressed("fire_item"):
		bits |= 1 << 10
	if Input.is_action_pressed("cycle_item"):
		bits |= 1 << 11
	drive.rpc_id(1, bits)


func write_trial(buffer: StreamPeerBuffer, session: Session) -> void:
	var race := session.race
	buffer.put_32(int(race.time * 100.0))
	buffer.put_u8(race.countdown)
	for i in race.cars.size():
		var finish := race.finish_time[i]
		var shown := race.race_time(i)
		buffer.put_u16(race.nodes[i])
		buffer.put_u8(race.laps_left[i])
		buffer.put_u8(race.places[i])
		buffer.put_32(-1 if finish < 0.0 else int(finish * 100.0))
		buffer.put_32(int(maxf(shown - race.lap_started[i], 0.0) * 100.0))
		buffer.put_u8(1 if i == session.trial_best_index else 0)


func read_trial(buffer: StreamPeerBuffer, session: Session, count: int) -> void:
	var race := session.race
	race.time = buffer.get_32() / 100.0
	race.countdown = buffer.get_u8()
	for i in count:
		race.nodes[i] = buffer.get_u16()
		race.laps_left[i] = buffer.get_u8()
		race.places[i] = buffer.get_u8()
		var finish_cs := buffer.get_32()
		var lap_cs := buffer.get_32()
		var best := buffer.get_u8()
		if finish_cs < 0:
			race.finish_time[i] = -1.0
			race.lap_started[i] = race.time - lap_cs / 100.0
		else:
			race.finish_time[i] = finish_cs / 100.0
		if best == 1 and i == race.player:
			race.new_best = true


func publish_state() -> void:
	var session := get_tree().current_scene as Session
	var buffer := StreamPeerBuffer.new()
	var cars := session.race.cars
	var count := cars.size()
	buffer.put_u8(count)
	buffer.put_u32(session.race.frame)
	if Session.time_trial:
		write_trial(buffer, session)
	else:
		buffer.put_u32(session.battle.score_serial)
		buffer.put_u16(session.battle.round_frame)
		buffer.put_8(session.battle.match_winner)
		buffer.put_u8(session.race.countdown)
		buffer.put_u8(1 if session.race.bumper else 0)
		for i in count:
			buffer.put_16(session.battle.points[i])
			buffer.put_16(session.battle.round_points[i])
			buffer.put_16(session.battle.score_from[i] if i < session.battle.score_from.size() else 0)
			buffer.put_u8(session.battle.out[i])
	var items := cars[0].items
	buffer.put_u8(1 if items.pickup else 0)
	buffer.put_u8(items.pickup_type)
	buffer.put_u16(items.pickup_node)
	buffer.put_u8(items.pickup_orientation)
	buffer.put_32(items.pickup_units.x)
	buffer.put_32(items.pickup_units.y)
	buffer.put_32(items.pickup_units.z)
	for slot in Items.POOL:
		buffer.put_u16(maxi(items.pool_timers[slot], 0))
		buffer.put_u8(items.pool_kinds[slot])
		buffer.put_u8(items.pool_owners[slot])
		buffer.put_8(items.pool_targets[slot])
		buffer.put_float(items.pool_positions[slot].x)
		buffer.put_float(items.pool_positions[slot].y)
		buffer.put_float(items.pool_positions[slot].z)
		buffer.put_float(items.pool_tilts[slot].x)
		buffer.put_float(items.pool_tilts[slot].y)
	for car in cars:
		var q := car.global_transform.basis.get_rotation_quaternion()
		buffer.put_float(car.global_position.x)
		buffer.put_float(car.global_position.y)
		buffer.put_float(car.global_position.z)
		buffer.put_float(q.x)
		buffer.put_float(q.y)
		buffer.put_float(q.z)
		buffer.put_float(q.w)
		buffer.put_float(car.vel.x)
		buffer.put_float(car.vel.y)
		buffer.put_float(car.vel.z)
		buffer.put_16(car.heading)
		buffer.put_float(car.body.rotation.z)
		buffer.put_float(car.steer_input)
		buffer.put_float(car.visual.position.y)
		buffer.put_16(car.item_scale)
		buffer.put_16(car.body_lift)
		buffer.put_8(car.stretch)
		buffer.put_8(car.rear_spread)
		buffer.put_u8(mini(car.burn_frames, 255))
		buffer.put_u8(mini(car.wreck_frames, 255))
		buffer.put_u8(1 if car.splash_wreck else 0)
		buffer.put_u8(1 if car.visible else 0)
		buffer.put_u8(1 if car.grounded else 0)
		buffer.put_u8(car.surface)
		buffer.put_u8(car.selected_item)
		for held in car.item_counts:
			buffer.put_u8(mini(held, 255))
	if not Session.time_trial:
		var view := session.camera as BattleCamera
		var aim := view.global_transform.basis.get_rotation_quaternion()
		buffer.put_float(view.global_position.x)
		buffer.put_float(view.global_position.y)
		buffer.put_float(view.global_position.z)
		buffer.put_float(aim.x)
		buffer.put_float(aim.y)
		buffer.put_float(aim.z)
		buffer.put_float(aim.w)
	snapshot.rpc(buffer.data_array)


func _peer_connected(id: int) -> void:
	if not multiplayer.is_server():
		return
	if in_match:
		refuse.rpc_id(id)
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	apply_profile(id, first_free_model(), 0)


func _peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	var keep: Array[Dictionary] = []
	for peer in peers:
		if int(peer.id) != id:
			keep.append(peer)
	peers = keep
	var playing := in_match
	if playing:
		status = "A player left"
	broadcast_lobby()
	if playing:
		end_match.rpc(Battle.wins)


func _connected() -> void:
	status = "Connected"
	changed.emit()


func _connection_failed() -> void:
	status = "Could not connect"
	online = false
	drop_peer()
	changed.emit()


func _server_disconnected() -> void:
	var playing := in_match
	if online:
		status = "Host closed the connection"
	online = false
	in_match = false
	peers.clear()
	slot = 0
	drop_peer()
	get_tree().paused = false
	if playing:
		MainMenu.start_page = MainMenu.PAGE_ONLINE
		Wipe.to(MainMenu.SCENE)
	changed.emit()


@rpc("any_peer", "reliable")
func submit_profile(model: int, expert: int) -> void:
	if not multiplayer.is_server() or in_match:
		return
	apply_profile(multiplayer.get_remote_sender_id(), model, expert)


@rpc("authority", "reliable", "call_local")
func lobby(ids: PackedInt32Array, models: PackedInt32Array, experts: PackedInt32Array, tally: PackedInt32Array) -> void:
	peers.clear()
	for i in ids.size():
		peers.append({id = ids[i], model = models[i], expert = experts[i]})
		Battle.wins[i] = tally[i]
	sort_peers()
	if slot >= 0:
		local_model = int(peers[slot].model)
		local_expert = int(peers[slot].expert)
	changed.emit()


@rpc("authority", "reliable", "call_remote")
func refuse() -> void:
	status = "That match has already started"
	online = false
	in_match = false
	peers.clear()
	drop_peer()
	changed.emit()


@rpc("authority", "reliable", "call_remote")
func share_level(path: String, text: String) -> void:
	var source := LevelBuild.DIR + "/play/_shared.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(LevelBuild.DIR + "/play"))
	var file := FileAccess.open(source, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	Session.queue_course(source, path)


@rpc("authority", "reliable", "call_local")
func begin(path: String, models: PackedInt32Array, experts: PackedInt32Array, target: int, pickups: int, trial: bool, ghost: int, bumper: bool) -> void:
	in_match = true
	get_tree().paused = false
	Session.time_trial = trial
	Session.bumper = bumper
	Session.ghost_model = ghost
	Battle.players = models.size()
	Battle.target = target
	Battle.pickups = pickups
	for i in models.size():
		Battle.models[i] = models[i]
		Battle.experts[i] = experts[i]
	Session.play(path)


@rpc("any_peer", "unreliable_ordered")
func drive(bits: int) -> void:
	if not multiplayer.is_server() or not in_match:
		return
	var cars := get_tree().get_nodes_in_group("cars")
	var index := slot_of(multiplayer.get_remote_sender_id())
	if index < 0 or index >= cars.size():
		return
	var car: Car = cars[index]
	car.net_accel = bits & 7
	car.net_brake = (bits >> 3) & 7
	car.net_steer = ((bits >> 6) & 15) - 7
	car.net_fire = ((bits >> 10) & 1) == 1
	car.net_cycle = ((bits >> 11) & 1) == 1
	car.net_reset = ((bits >> 12) & 1) == 1


@rpc("authority", "unreliable_ordered", "call_remote")
func snapshot(blob: PackedByteArray) -> void:
	if not in_match:
		return
	var session := get_tree().current_scene as Session
	if not session is Session or session.race == null:
		return
	if not Session.time_trial and session.battle == null:
		return
	var cars := session.race.cars
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = blob
	var count := buffer.get_u8()
	if count != cars.size():
		return
	if not Session.time_trial and session.battle.points.size() != count:
		return
	session.race.frame = buffer.get_u32()
	if Session.time_trial:
		read_trial(buffer, session, count)
	else:
		var battle := session.battle
		battle.score_serial = buffer.get_u32()
		battle.round_frame = buffer.get_u16()
		battle.match_winner = buffer.get_8()
		session.race.countdown = buffer.get_u8()
		session.race.bumper = buffer.get_u8() == 1
		if battle.score_from.size() != count:
			battle.score_from.resize(count)
		for i in count:
			battle.points[i] = buffer.get_16()
			battle.round_points[i] = buffer.get_16()
			battle.score_from[i] = buffer.get_16()
			battle.out[i] = buffer.get_u8()
	var items := cars[0].items
	items.pickup = buffer.get_u8() == 1
	items.pickup_type = buffer.get_u8()
	items.pickup_node = buffer.get_u16()
	items.pickup_orientation = buffer.get_u8()
	items.pickup_units = Vector3i(buffer.get_32(), buffer.get_32(), buffer.get_32())
	for slot_index in Items.POOL:
		items.pool_timers[slot_index] = buffer.get_u16()
		items.pool_kinds[slot_index] = buffer.get_u8()
		items.pool_owners[slot_index] = buffer.get_u8()
		items.pool_targets[slot_index] = buffer.get_8()
		items.pool_positions[slot_index] = Vector3(buffer.get_float(), buffer.get_float(), buffer.get_float())
		items.pool_tilts[slot_index] = Vector2(buffer.get_float(), buffer.get_float())
	for car in cars:
		var pos := Vector3(buffer.get_float(), buffer.get_float(), buffer.get_float())
		var basis := Basis(Quaternion(buffer.get_float(), buffer.get_float(), buffer.get_float(), buffer.get_float())).orthonormalized()
		var vel := Vector3(buffer.get_float(), buffer.get_float(), buffer.get_float())
		var counts := PackedByteArray()
		var heading := buffer.get_16()
		var lean := buffer.get_float()
		var steer := buffer.get_float()
		var lift := buffer.get_float()
		var scale := buffer.get_16()
		var body_lift := buffer.get_16()
		var stretch := buffer.get_8()
		var spread := buffer.get_8()
		var burn := buffer.get_u8()
		var wreck := buffer.get_u8()
		var splash := buffer.get_u8() == 1
		var show := buffer.get_u8() == 1
		var grounded := buffer.get_u8() == 1
		var surface := buffer.get_u8()
		var item := buffer.get_u8()
		counts.resize(Items.TYPES)
		for i in Items.TYPES:
			counts[i] = buffer.get_u8()
		car.apply_puppet(Transform3D(basis, pos), vel, heading, lean, steer, lift, scale, body_lift, stretch, spread, burn, wreck, splash, show, grounded, surface, item, counts)
	if Session.time_trial:
		return
	var eye := Vector3(buffer.get_float(), buffer.get_float(), buffer.get_float())
	var view_basis := Basis(Quaternion(buffer.get_float(), buffer.get_float(), buffer.get_float(), buffer.get_float())).orthonormalized()
	(session.camera as BattleCamera).apply_puppet(Transform3D(view_basis, eye))


@rpc("authority", "reliable", "call_remote")
func share_effect(program: int, tone: int, volume: int, note: int) -> void:
	Sound.play_effect(program, tone, volume, note)


@rpc("authority", "reliable", "call_remote")
func share_rumble(pattern: int, priority: int) -> void:
	var session := get_tree().current_scene as Session
	session.race.cars[slot].queue_rumble(pattern, priority)


@rpc("any_peer", "reliable")
func ask_pause(paused: bool) -> void:
	if not multiplayer.is_server() or not in_match:
		return
	var session := get_tree().current_scene as Session
	session.set_paused(paused)


@rpc("authority", "reliable", "call_remote")
func set_paused_remote(paused: bool) -> void:
	var session := get_tree().current_scene as Session
	session.apply_pause(paused)


@rpc("any_peer", "reliable")
func ask_end() -> void:
	if not multiplayer.is_server() or not in_match:
		return
	var session := get_tree().current_scene as Session
	if session.battle:
		session.battle.finish_match()
	else:
		end_match.rpc(PackedInt32Array())


@rpc("authority", "reliable", "call_local")
func prompt_rematch(next: PackedInt32Array) -> void:
	Battle.wins = next
	var session := get_tree().current_scene as Session
	session.show_rematch()


@rpc("any_peer", "reliable")
func rematch_pick(move: int, accept: bool) -> void:
	if not is_host():
		return
	var session := get_tree().current_scene as Session
	session.apply_rematch(move, accept)


@rpc("authority", "reliable", "call_remote")
func rematch_choice(yes: bool) -> void:
	var session := get_tree().current_scene as Session
	session.set_rematch_choice(yes)


@rpc("authority", "reliable", "call_local")
func rematch_tracks() -> void:
	in_match = false
	get_tree().paused = false
	MainMenu.start_page = MainMenu.PAGE_ONLINE_TRACK
	Wipe.to(MainMenu.SCENE)


@rpc("authority", "reliable", "call_local")
func end_match(wins: PackedInt32Array) -> void:
	Session.time_trial = false
	in_match = false
	get_tree().paused = false
	Battle.wins = wins
	MainMenu.start_page = MainMenu.PAGE_ONLINE
	Wipe.to(MainMenu.SCENE)


func apply_profile(id: int, model: int, expert: int) -> void:
	var found := false
	for peer in peers:
		if peer.id == id:
			peer.model = resolve_model(id, model)
			peer.expert = expert
			found = true
	if not found:
		peers.append({id = id, model = resolve_model(id, model), expert = expert})
	broadcast_lobby()


func broadcast_lobby() -> void:
	sort_peers()
	var ids := PackedInt32Array()
	var models := PackedInt32Array()
	var experts := PackedInt32Array()
	var tally := PackedInt32Array()
	for i in peers.size():
		ids.append(int(peers[i].id))
		models.append(int(peers[i].model))
		experts.append(int(peers[i].expert))
		tally.append(Battle.wins[i])
	lobby.rpc(ids, models, experts, tally)


func sort_peers() -> void:
	peers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.id) < int(b.id))
	slot = -1
	var me := multiplayer.get_unique_id()
	for i in peers.size():
		if int(peers[i].id) == me:
			slot = i


func slot_of(id: int) -> int:
	for i in peers.size():
		if int(peers[i].id) == id:
			return i
	return -1


func first_free_model() -> int:
	return resolve_model(-1, 0)


func resolve_model(id: int, want: int) -> int:
	var used := {}
	for peer in peers:
		if int(peer.id) != id:
			used[int(peer.model)] = true
	var model := wrapi(want, 0, Car.CAR_MODELS)
	if not used.has(model):
		return model
	for _step in Car.CAR_MODELS:
		model = (model + 1) % Car.CAR_MODELS
		if not used.has(model):
			return model
	return wrapi(want, 0, Car.CAR_MODELS)


func drop_peer() -> void:
	var peer := multiplayer.multiplayer_peer
	if peer == null:
		return
	peer.close()
	multiplayer.multiplayer_peer = null
