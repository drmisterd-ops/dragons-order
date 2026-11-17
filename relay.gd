extends SceneTree

const PORT := 8787
const MAX_CONNECTIONS := 128
const MAX_PACKET := 262144
const IDLE_MS := 3600000
const INVITE_MS := 600000
var server := TCPServer.new()
var peers: Dictionary = {}
var rooms: Dictionary = {}
var tokens: Dictionary = {}

func _initialize() -> void:
	var port := PORT
	var address := "127.0.0.1"
	var hosted_port := OS.get_environment("PORT")
	if hosted_port.is_valid_int() and int(hosted_port) >= 1 and int(hosted_port) <= 65535:
		port = int(hosted_port)
		address = "0.0.0.0"
	if server.listen(port, address) != OK:
		printerr("Could not start Dragon's Order relay on port ", port)
		quit(1)
		return
	print("Dragon's Order relay listening on ", address, ":", port)
	process_frame.connect(_poll)

func _poll() -> void:
	while server.is_connection_available():
		var stream := server.take_connection()
		if peers.size() >= MAX_CONNECTIONS:
			stream.disconnect_from_host()
			continue
		var socket := WebSocketPeer.new()
		socket.inbound_buffer_size = MAX_PACKET
		socket.outbound_buffer_size = MAX_PACKET * 2
		if socket.accept_stream(stream) == OK:
			peers[socket] = {"code": "", "expires": Time.get_ticks_msec() + 12000}
	var now := Time.get_ticks_msec()
	for socket: WebSocketPeer in peers.keys():
		if not peers.has(socket):
			continue
		socket.poll()
		if socket.get_ready_state() == WebSocketPeer.STATE_CLOSED or now >= peers[socket].expires:
			_remove(socket)
			continue
		for index in range(mini(32, socket.get_available_packet_count())):
			if not peers.has(socket):
				break
			var packet := socket.get_packet()
			if packet.size() > MAX_PACKET:
				_remove(socket)
				break
			if peers[socket].code.is_empty():
				if peers[socket].get("rejected", false):
					break
				if not socket.was_string_packet() or packet.size() > 256:
					_remove(socket)
					break
				_register(socket, JSON.parse_string(packet.get_string_from_utf8()))
			elif not socket.was_string_packet():
				var room: Array = rooms[peers[socket].code]
				if room.size() == 2:
					var other: WebSocketPeer = room[1] if room[0] == socket else room[0]
					if other.send(packet) != OK:
						_remove(other)
					else:
						peers[socket].expires = now + IDLE_MS
						peers[other].expires = now + IDLE_MS

func _control(socket: WebSocketPeer, op: String, code := "", token := "") -> void:
	socket.send_text(JSON.stringify({"op": op, "code": code, "token": token}))

func _reject(socket: WebSocketPeer, reason: String) -> void:
	_control(socket, reason)
	peers[socket].rejected = true
	peers[socket].expires = Time.get_ticks_msec() + 1000

func _register(socket: WebSocketPeer, message: Variant) -> void:
	if not message is Dictionary:
		_remove(socket)
		return
	if message.get("version") != 1:
		_reject(socket, "version")
		return
	var code := ""
	var lifetime := IDLE_MS
	match message.get("op"):
		"host":
			code = str(randi_range(100000, 999999))
			while rooms.has(code):
				code = str(randi_range(100000, 999999))
			var token := Crypto.new().generate_random_bytes(16).hex_encode()
			rooms[code] = [socket]
			tokens[code] = token
			lifetime = INVITE_MS
			_control(socket, "room", code, token)
		"join":
			var candidate: Variant = message.get("code")
			if not candidate is String or not tokens.has(candidate) or message.get("token") != tokens[candidate]:
				_reject(socket, "missing")
				return
			var host: WebSocketPeer = rooms[candidate][0]
			if Time.get_ticks_msec() >= peers[host].expires:
				_remove(host)
				_reject(socket, "missing")
				return
			code = candidate
			tokens.erase(code)
			rooms[code].append(socket)
			_control(host, "paired")
			_control(socket, "paired")
			peers[host].expires = Time.get_ticks_msec() + IDLE_MS
		_:
			_remove(socket)
			return
	peers[socket] = {"code": code, "expires": Time.get_ticks_msec() + lifetime}

func _remove(socket: WebSocketPeer) -> void:
	var code: String = peers[socket].code
	peers.erase(socket)
	if rooms.has(code):
		for other: WebSocketPeer in rooms[code]:
			if other != socket and peers.has(other):
				_control(other, "left")
				peers.erase(other)
				other.close()
		rooms.erase(code)
		tokens.erase(code)
	socket.close()
