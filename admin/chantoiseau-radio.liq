# --- CONFIGURATION SERVEUR ---
settings.server.telnet := true
settings.server.telnet.port := 1234
settings.server.telnet.bind_addr := "127.0.0.1"

# --- SOURCES ---
tous = playlist(id="tous", mode="random_finite", prefetch=2, "/srv/www/chantoiseau-radio/admin/onair.m3u")
guillaume = playlist(id="guillaume", mode="random_finite", prefetch=2, "/srv/www/chantoiseau-radio/admin/guillaume.m3u")
jacques = playlist(id="jacques", mode="random_finite", prefetch=2, "/srv/www/chantoiseau-radio/admin/onair.m3u")

# --- VARIABLE ANIMATEUR ---
current_choice = ref("tous")

# Correction: Registered functions for Telnet/PHP interaction
server.register(namespace="choix_playlist", "set", fun (v) -> begin current_choice.set(v) "Animateur mis a jour !" end)
server.register(namespace="choix_playlist", "get", fun (_) -> current_choice()) 

# --- JINGLES ---
jingles = request.queue(id="jingles")

# --- LOGIQUE DE SWITCH ---
radio_switched = switch(id="radio", track_sensitive=false, [
  ({ !current_choice == "guillaume" }, guillaume),
  ({ !current_choice == "jacques" }, jacques),
  ({ true }, tous)
])

# --- SORTIE FINALE ---
radio_finale = smooth_add(normal=radio_switched, special=jingles)
radio_finale = mksafe(radio_finale)

output.icecast(
  %mp3(bitrate=128),
  host="localhost",
  port=8000,
  password="Olicout5000",
  mount="radio.mp3",
  id="icecast_out",
  radio_finale
)