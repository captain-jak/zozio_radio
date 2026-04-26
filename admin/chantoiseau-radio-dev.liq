# --- CONFIGURATION SERVEUR ---
# démarrage:
#sudo systemctl restart chantoiseau-radio
# debug
# sudo journalctl -u chantoiseau-radio.service -f
settings.server.telnet.set(true)
settings.server.telnet.port.set(1234)
settings.server.telnet.bind_addr.set("127.0.0.1")

# 1. --- VARIABLES ET SOURCES ---
current_choice = ref("tous")
jingle_queue = request.queue(id="jingle_source")
current_host_name = ref("Radio Zozio") # Nom par défaut

# syntaxe liquidsoap
#=> mode="random"    -----> À chaque fois qu'un titre se termine, Liquidsoap pioche un nouveau morceau au hasard dans la liste (mode par défaut)
#=> mode="normal"    -----> Lit la playlist dans l'ordre exact du fichier .m3u, de haut en bas
#=> mode="strict"    -----> Lit la playlist dans l'ordre, mais s'arrête une fois le dernier titre atteint. Elle ne boucle pas.
#=> mode="random_finite"    -----> Liquidsoap mélange la playlist (comme un paquet de cartes), joue tous les titres un par un jusqu'à épuisement, puis remélange tout le paquet pour un nouveau cycle.
#=> reload_mode="watch"   -----> Recharge le .m3u dès que le fichier est modifié sur le disque
#=> reload_mode="seconds"   -----> Recharge toutes les X secondes
#=>prefetch=2  + track_sensitive=true -----> permet à Liquidsoap de préparer (décoder en avance) les 2 prochains titres. Cela garantit une transition instantanée sans "blanc" entre les morceaux, car le fichier est déjà prêt en mémoire.
#=>track_sensitive=false   ---->  Le changement est instantané à la seconde près.
#=>track_sensitive=true   ----> Liquidsoap attend la fin de la chanson en cours pour changer d'animateur à l'heure pile.

#tous = playlist(id='tous', prefetch=2, mode="random_finite", reload_mode="watch", "/srv/www/chantoiseau-radio/admin/playlist/onair.m3u")
#anime1 = playlist(id='anime1', mode="random_finite", reload_mode="watch", prefetch=2, "/srv/www/chantoiseau-radio/admin/playlist/anime1.m3u")
#anime2 = playlist(id='anime2', mode="random_finite", reload_mode="watch", prefetch=2, "/srv/www/chantoiseau-radio/admin/playlist/anime2.m3u")
#anime3 = playlist(id='anime3', mode="random_finite", prefetch=2, "/srv/www/chantoiseau-radio/admin/playlist/anime3.m3u")
#anime4 = playlist(id='anime4', mode="strict", "/srv/www/chantoiseau-radio/admin/playlist/anime4.m3u")


tous = playlist(id='tous', prefetch=2, "/srv/www/chantoiseau-radio/admin/playlist/onair.m3u")
anime1 = playlist(id='anime1', mode="random_finite", reload_mode="watch", prefetch=2, "/srv/www/chantoiseau-radio/admin/playlist/anime1.m3u")
anime2 = playlist(id='anime2', mode="random_finite", reload_mode="watch", prefetch=2, "/srv/www/chantoiseau-radio/admin/playlist/anime2.m3u")
anime3 = playlist(id='anime2', mode="random_finite", reload_mode="watch", prefetch=2, "/srv/www/chantoiseau-radio/admin/playlist/anime3.m3u")
anime4 = playlist(id='anime2', mode="random_finite", reload_mode="watch", prefetch=2, "/srv/www/chantoiseau-radio/admin/playlist/anime4.m3u")
# ------------------------------

#-------------------------- programmation horaire --------------------------
def check_schedule() =
  let result = process.read("php /srv/www/chantoiseau-radio/admin/radio_scheduler.php")
  let val = string.trim(result)
  log("PROGRAMMATION : Scheduler  [#{val}]") # Cette ligne va écrire dans ton journalctl
  current_choice.set(val)
end

# On demande à thread.run de lancer la fonction toutes les 60 secondes
thread.run(every=60.0, check_schedule)
#---------------------------------------------------------------------------

# 2. LOGIQUE DE SWITCH
radio_switched = switch(id="radio", track_sensitive=true, [
    ({ current_choice() == "anime1" }, anime1),
    ({ current_choice() == "anime1" }, anime1),
    ({ current_choice() == "anime1" }, anime1),
    ({ current_choice() == "tous" }, tous),
    ({ true }, tous)
])

# 3. MÉLANGE ET SÉCURITÉ
radio_finale = smooth_add(normal=radio_switched, special=jingle_queue)
radio_finale = mksafe(radio_finale)

# 4. NOTIFICATIONS METADATA
last_track = ref("---")
current_track = ref("---")

def metadata_notification(m) =
  last_track.set(current_track()) 
  art = m["artist"]
  tit = m["title"]
  #==> old=   host = !current_host_name # On récupère le nom de l'animateur
 # let host = current_host_name()# On récupère le nom de l'animateur
  # On construit un titre qui inclut l'animateur pour Icecast (optionnel)
  # new_title = "[#{host}] #{art} - #{tit}"
  new_title = if art != "" and tit != "" then "#{art} - #{tit}" else "#{tit}" end
  current_track.set(new_title)
end

#radio_finale.on_metadata(metadata_notification)
radio_finale.on_metadata(synchronous=false, metadata_notification)

# 5. COMMANDES TELNET
server.register(namespace="radio", "last", fun (_) -> last_track())
server.register(namespace="radio", "current", fun (_) -> current_track())
server.register(namespace="choix_playlist", "set", fun (v) -> begin current_choice.set(v) "OK" end)
server.register(namespace="choix_playlist", "get", fun (_) -> current_choice())
# Namespace dédié aux jingles
server.register(namespace="jingles", "push", fun (v) -> begin jingle_queue.push(request.create(v)) "Jingle ajouté !" end)
# Permet au PHP de mettre à jour le nom humain
server.register(namespace="choix_playlist", "set_name", fun (v) -> begin current_host_name.set(v) "Nom mis a jour" end)
# Permet au PHP de récupérer le nom humain
#==>old =server.register(namespace="choix_playlist", "get_name", fun (_) -> !current_host_name)
server.register(namespace="choix_playlist", "get_name", fun (_) -> current_host_name())

# 6. SORTIE FFmpeg (Vérifie bien que ton libmp3lame est installé via opam)
output.icecast(
  %ffmpeg(format="mp3", %audio(codec="libmp3lame", b="128k")),
  host="localhost", port=8000, password="Olicout5000", mount="radio.mp3",
  id="icecast_out", radio_finale
)