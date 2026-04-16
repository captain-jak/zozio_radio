# --- CONFIGURATION SERVEUR ---
settings.server.telnet.set(true)
settings.server.telnet.port.set(1234)
settings.server.telnet.bind_addr.set("127.0.0.1")

# 1. --- VARIABLES ET SOURCES ---
current_choice = ref("tous")
jingles = request.queue(id="jingles")

tous = playlist(id="tous", mode="random_finite", prefetch=2, "/srv/www/chantoiseau-radio/admin/onair.m3u")
guillaume = playlist(id="guillaume", mode="random_finite", reload_mode="watch", prefetch=2, "/srv/www/chantoiseau-radio/admin/guillaume.m3u")
jacques = playlist(id="jacques", mode="random_finite", prefetch=2, "/srv/www/chantoiseau-radio/admin/jacques.m3u")

# 2. LOGIQUE DE SWITCH
radio_switched = switch(id="radio", track_sensitive=false, [
  ({ current_choice() == "guillaume" }, guillaume),
  ({ current_choice() == "jacques" }, jacques),
  ({ true }, tous)
])

# 3. MÉLANGE ET SÉCURITÉ
radio_finale = smooth_add(normal=radio_switched, special=jingles)
radio_finale = mksafe(radio_finale)

# 4. NOTIFICATIONS METADATA
last_track = ref("---")
current_track = ref("---")

def metadata_notification(m) =
  last_track.set(current_track()) 
  art = m["artist"]
  tit = m["title"]
  new_title = if art != "" and tit != "" then "#{art} - #{tit}" else "#{tit}" end
  current_track.set(new_title)
end

radio_finale.on_metadata(metadata_notification)

# 5. COMMANDES TELNET PERSO
#server.register(namespace="radio", "last", fun (_) -> !last_track)
#server.register(namespace="radio", "current", fun (_) -> !current_track)
#server.register(namespace="choix_playlist", "get", fun (_) -> !current_choice)

server.register(namespace="radio", "last", fun (_) -> last_track())
server.register(namespace="radio", "current", fun (_) -> current_track())
server.register(namespace="choix_playlist", "set", fun (v) -> begin current_choice.set(v) "Animateur mis a jour !" end)
server.register(namespace="choix_playlist", "get", fun (_) -> current_choice())

# Commande pour pousser un jingle dans la file d'attente
server.register(namespace="jingles", "push", fun (v) -> begin jingles.push(request.create(v)) "Jingle ajouté !" end)

# 6. SORTIE
output.icecast(
  %mp3(bitrate=128),
  host="localhost", port=8000, 
  password="Olicout5000", mount="radio.mp3",
  id="icecast_out", radio_finale
)