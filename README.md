# Dragon's Order relay

Deploy this directory once as a Docker web service on a host that supports WebSockets. The container listens on the provider's PORT and expects the provider to terminate TLS. Use a TCP health check if the provider offers one. The public endpoint should be wss://YOUR-HOSTNAME/ws.

Test the deployed endpoint by connecting over WSS and sending {"op":"host","version":1}. It should reply with a room number and a private join token. Treat the token as a secret. Set the deployed URL in the client project under [dragons_order] as online/relay_url, then export and sign the Android build. Players need only that APK.

A host taps Multiplayer → Host Game → Copy code. The guest taps Paste code → Join duel. Invites are single use and expire after ten minutes while waiting. The host phone runs the game. A disconnected match ends and requires a new invite.

For a self-hosted installation, run Godot 4.7.2 with --headless --path . --script relay.gd --max-fps 60, and put the included Caddy example in front of it. With no PORT environment variable the relay listens on 127.0.0.1:8787.
