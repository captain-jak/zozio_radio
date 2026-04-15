# --- CONFIGURATION SERVEUR ---
settings.server.telnet := true
settings.server.telnet.port := 1234
settings.server.telnet.bind_addr := "127.0.0.1"

# 1. --- VARIABLES ET JINGLES (On définit tout avant l'usage) ---
current_choice = ref("tous")
jingles = request.queue(id="jingles")

# 2--- SOURCES ---
tous = playlist(id="tous", mode="random_finite", prefetch=2, "/srv/www/chantoiseau-radio/admin/onair.m3u")
guillaume = playlist(id="guillaume", mode="random_finite", prefetch=2, "/srv/www/chantoiseau-radio/admin/guillaume.m3u")
jacques = playlist(id="jacques", mode="random_finite", prefetch=2, "/srv/www/chantoiseau-radio/admin/onair.m3u")

# 3. LOGIQUE DE SWITCH (animateur)
radio_switched = switch(id="radio", track_sensitive=false, [
  ({ current_choice() == "guillaume" }, guillaume),
  ({ current_choice() == "jacques" }, jacques),
  ({ true }, tous)
])

# 4. --- MÉLANGE ET SÉCURITÉ ---
radio_finale = smooth_add(normal=radio_switched, special=jingles)
radio_finale = mksafe(radio_finale)


# 5. --- MÉMOIRE ET NOTIFICATION ---
last_track = ref("---")
current_track = ref("---")

def metadata_notification(m) =
  #=> 1. L'ancien "actuel" devient le "précédent"
  last_track.set(!current_track)
  
  #=> 2. On construit le nouveau "actuel"
  art = m["artist"]
  tit = m["title"]
  new_title = if art != "" and tit != "" then "#{art} - #{tit}" else "#{tit}" end
  
  #=> 3. On met à jour l'actuel pour le prochain coup
  current_track.set(new_title)
end

 # 6.   On écoute les changements de métadonnées sur le flux final
radio_finale.on_metadata(metadata_notification)

# 7. --- ENREGISTREMENT COMMANDES ---
#server.register(namespace="radio", "last", fun (_) -> !last_track)

# 8. --- ENREGISTREMENT COMMANDES TELNET ---
server.register(namespace="radio", "last", fun (_) -> !last_track)
server.register(namespace="choix_playlist", "set", fun (v) -> begin current_choice.set(v) "Animateur mis a jour !" end)
server.register(namespace="choix_playlist", "get", fun (_) -> !current_choice)

# 9 --- JINGLES ---
jingles = request.queue(id="jingles")

# 10 --- LA SORTIE ---
output.icecast(
  %mp3(bitrate=128),
  host="localhost",
  port=8000,
  password="Olicout5000",
  mount="radio.mp3",
  id="icecast_out",
  radio_finale
)