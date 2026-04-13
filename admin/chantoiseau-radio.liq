 # --- CONFIGURATION SERVEUR ---
settings.server.telnet := true
settings.server.telnet.port := 1234
settings.server.telnet.bind_addr := "127.0.0.1"

# --- SOURCES ---
# On garde les IDs simples pour le PHP
tous = playlist(id="tous", mode="random_finite", prefetch=2, "/srv/admin/chantoiseau-radio/onair.m3u")
guillaume = playlist(id="guillaume", mode="random_finite", prefetch=2, "/srv/admin/chantoiseau-radio/guillaume.m3u")
jacques = playlist(id="jacques", mode="random_finite", prefetch=2, "/srv/admin/chantoiseau-radio/jacques.m3u")

# --- VARIABLE ANIMATEUR ---
current_choice = ref("tous")
server.register(namespace="choix_playlist", "set", fun (v) -> begin current_choice.set(v) "Animateur mis à jour !" end)
server.register(namespace="choix_playlist", "get", fun (_) -> current_choice()) 

# --- JINGLES ---
# IMPORTANT : On définit l'ID "jingles" pour le PHP
jingles = request.queue(id="jingles")

# --- LOGIQUE DE SWITCH ---
# On garde l'ID "radio" pour le skip et l'historique
radio_switched = switch(id="radio", track_sensitive=false, [
  ({ current_choice() == "guillaume" }, guillaume),
  ({ current_choice() == "jacques" }, jacques),
  ({ true }, tous)
])

# --- SORTIE FINALE ---
# On mixe le switch ET les jingles
radio_finale = smooth_add(normal=radio_switched, special=jingles)

# Sécurité (mksafe doit être à la toute fin)
radio_finale = mksafe(radio_finale)

output.icecast(
  %mp3(bitrate=128),
  host="localhost",
  port=8000,
  password="Olicout5000",
  mount="radio.mp3",
  id="icecast_out", # ID de la sortie Icecast,
  radio_finale
)