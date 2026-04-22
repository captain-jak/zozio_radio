#!/bin/bash

# Fabriquer la playlist
find "/srv/zozio-radio/Musique onair" -type f -name "*.mp3" > "/srv/admin/chantoiseau-radio/onair.m3u"
# mp3 ou ogg
find "/srv/www/nextcloud/data/enjoy/files/zozio-radio/musique-onair" -type f \( -name "*.mp3" -o -name "*.ogg" \) | sort > "/srv/www/chantoiseau-radio/admin/onair.m3u"
find "/srv/www/nextcloud/data/enjoy/files/zozio-radio//musique-animateurs/Tosha-onair" -type f \( -name "*.mp3" -o -name "*.ogg" \) | sort > "/srv/www/chantoiseau-radio/admin/tosha.m3u"
sudo systemctl restart chantoiseau-radio
mpv http://zozio.uk &
# Redémarrer icecast
sudo systemctl start icecast2
# Editer lea config de liquidsoap
nano chantoiseau-radio.liq
# Lire la radio:
mpv http://chantoiseau.selfmicro.com:8000/radio.mp3 & >/dev/null
# Monter le volume:
wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+

                                                           chantoiseau-radio.liq                                                               
    set("log.stdout", true)
    # 1. La playlist
    radio_playlist = playlist("/srv/Musique/bashung_playlist.m3u", mode="random")
    # 2. On applique le crossfade directement sur la playlist
    # On accepte que cette étape soit "fallible" pour l'instant
    radio_transition = crossfade(radio_playlist, duration=1.0)
    # 3. On rend le TOUT infallible (C'est l'étape CRUCIALE)
    # On sécurise la sortie du crossfade pour qu'Icecast soit content
    radio = mksafe(radio_transition)
    # 4. Sortie Icecast (On diffuse la variable 'radio' qui est mksafe)
    output.icecast(
      %mp3(bitrate=128),
      host="localhost",
      port=8000,
      password="Olicout5000",
      mount="radio.mp3",
      name="Chantoiseau radio",
      description="Mise en onde par l'école de voile de Chante-oiseau",
      radio
    )

# Diffusion vers Icecast
liquidsoap chantoiseau-radio.liq
# en mode debug:
liquidsoap -v --debug chantoiseau-radio.liq


#######    en dev ######################################
locate -0i "Franz Schubert - Fantaisie D940" | xargs -0 exiftool

#######  Installation Nextcloud #####################
#------------    Montage dossier de partage ----------------------
mkdir "/srv/www/nextcloud/data/enjoy/files/zozio-radio/"
sudo mount --bind /srv/zozio-radio "/srv/www/nextcloud/data/enjoy/files/zozio-radio/"
sudo -u www-data php /srv/www/nextcloud/occ files:scan --all
# Nettoyer les logs:
sudo truncate -s 0 /srv/www/nextcloud/data/nextcloud.log

# si erreur de type  ......  will not be accessible due to incompatible encoding  (encodage UTF-8,  pb accent dans nom de fichier)
convmv -r -f utf-8 -t utf-8 --nfc --notest /srv/zozio-radio
convmv -r -f utf-8 -t utf-8 --nfc --notest .
# Reconstruire la playlist
find "/srv/www/nextcloud/data/enjoy/files/zozio-radio/musique-onair" -type f -name "*.mp3" > "/srv/www/chantoiseau-radio/admin/onair.m3u"
# playlist guillaume:
find "/srv/www/nextcloud/data/enjoy/files/zozio-radio/musique-animateurs/Guillaume-onair" -type f -name "*.mp3" > "/srv/www/chantoiseau-radio/admin/guillaume.m3u"
# playlist jacques:
find "/srv/www/nextcloud/data/enjoy/files/zozio-radio/musique-animateurs/Jacques-onair" -type f -name "*.mp3" > "/srv/www/chantoiseau-radio/admin/jacques.m3u"

# Redémarrer la radio:
sudo systemctl restart chantoiseau-radio
# Ecoutez:
mpv http://zozio.uk &
# Monter le volume:
wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+


###########################################################################################################
########      Procédure de nommage des fichiers MP3        
###########################################################################################################
Toit les fichiers sont obligatoirement au format
Avant dêtre injecté dans la radio, ils sont verifiées, et notamment leurs noms qui permettra de determiner
lors du passage à la radio:
ARTISTE   -  TITRE -- ANNEE
Le format du fichier est ARTISTE::TITRE::ANNEE  (le séparateur est "::"
Des outils on été développés pour vérifier et convertir la cohérence de ces fichiers:
./clean_renommage_songreg.sh # lis la base de données shazam pour récupérer artiste et titre  des fichiers du répertoire entré - renome le fichier avec ces infos au format artiste::titre::annee
clean-inject.sh  # injecte au format mp3db artiste, titre et duree des fichiers du répertoire entré
clean-duree.sh   # injecte au format mp3db a duree en secondes + totalise la durée totale cumulée des fichiers du répertoire entré
clean-lecture.sh   # affichage des noms artiste - titre durée des fichiers du répertoire entré


Tester les réponses LiquidSoap:
telnet localhost 1234
choix_playlist.get -> Pour voir si animateur est bon.
radio.history -> Pour voir si historique s affiche.
choix_playlist.get
choix_playlist.set guillaume

# voir lesz erreurs au demarrage liquidsoap
sudo journalctl -u chantoiseau-radio.service -n 50 --no-pager

sudo -u www-data bash ./clean-duree.sh
# supprime TAG 
sudo -u www-data mid3v2 --delete-frames=TXXX 

# =========  github ===================
# 1 - Initialisation du projet locale:
cd /srv/www/chantoiseau-radio
git init
git add .
git commit -m "Initial commit from Geany"
# 2 - Link to GitHub
git remote add origin https://github.com/captain-jak/zozio_radio.git
git remote set-url origin git@github.com:captain-jak/zozio_radio.git

git branch -M main
# 3 - Push all the Code
git add . && git commit -m "update 1.01d" && git push -u origin main
# 3 - Push juste le fichier README.md
git add README.md && git commit -m "update" && git push -u origin main


###########################################################################################################
########      compilatio n LiquidSoap     -  Ubuntu 22.04
###########################################################################################################
#------------- 1. Install System Dependencies
sudo apt update
sudo apt install -y build-essential m4 pkg-config libpcre3-dev libmad0-dev \
libmp3lame-dev libogg-dev libvorbis-dev libflac-dev libtag1-dev \
libsamplerate0-dev libssl-dev libcurl4-gnutls-dev
#------  si erreur de dependance , downgrader:
sudo apt install --allow-downgrades \
libflac8=1.3.3-2ubuntu0.2 \
libflac-dev \
libmad0=0.15.1b-10ubuntu1 \
libmad0-dev \
libmp3lame0=3.100-3build2 \
libmp3lame-dev

#------------- 2. Install OPAM ---------
# Install OPAM
sudo apt install opam
# Initialize OPAM (this takes a few minutes)
# It creates a hidden folder ~/.opam
opam init
eval $(opam env)
# Update the package list
opam update
#-------------   3. Install Liquidsoap via OPAM
opam install liquidsoap
#Pour installer une version spécifique
opam install liquidsoap.2.4.3
#To install the absolute latest (Development/Git) version:
opam pin add liquidsoap --dev-repo


#-------------4. Enabling Optional Features
opam install ffmpeg ladspa cry samplerate taglib
opam install lame mad ffmpeg liquidsoap

#-------------5. System Integration (Systemd)
sudo ln -sf $(which liquidsoap) /usr/bin/liquidsoap
sudo nano /etc/systemd/system/chantoiseau-radio.service
ExecStart=/home/votre_user/.opam/default/bin/liquidsoap home/enjoy/chantoiseau-radio.liq

#-------------6. Verify the Installation
liquidsoap --version
#==========    DESINSTALLATION  ============
opam remove liquidsoap liquidsoap-lang  lame mad ffmpeg liquidsoap
opam unpin liquidsoap liquidsoap-lang
opam update
