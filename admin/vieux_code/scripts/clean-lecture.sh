#!/bin/bash

# Lit les metadonnées d'un fichier MP3 ou OGG

# L'option -e permet d'utiliser l'auto-complétion avec la touche TAB !
read -e -p "📂 Glissez-déposez le dossier ici (ou tapez son chemin) : " DIR_BASE
# Par ordre alphabétique
i=1
find "$DIR_BASE" -type f | sort | while read -r fichier; do
    # numérotation des résultats:
    # On vérifie le type MIME pour chaque fichier  et on ne garde que MP3
    # if exiftool -FileType "$fichier" | grep -q "MP3"; then
    if exiftool -s3 -FileType "$fichier" | grep -qE "MP3|OGG"; then
        base=$(basename "$fichier")
        dir=$(dirname "$fichier")
        # Lecture des tags (on utilise -s3 pour avoir la valeur brute) si unknown ou vide
        # en 1er lecture titre avec mid3v2
        #titre=$(mid3v2 --list "$fichier" | grep "^TIT2=" | cut -d= -f2-)
        titre=$(mid3v2 --list "$fichier" | grep -a "TIT2" | cut -d= -f2-)
        # Remplacez votre commande par :
        if [[ -z "$titre" || "$titre" == "Unknown title" ]]; then
            titre=$(exiftool -s3 -Title "$fichier")
        fi
         #if [[ -z "$titre" || "$titre" == "Unknown " ]]; then
            #titre="❌ $titre"
        #fi
        # en 1er lecture artiste avec mid3v2
        artiste=$(mid3v2 --list "$fichier" | grep -a "^TPE1=" | cut -d= -f2-)
        # essai d'extraction artiste avec exiftool
         if [[ -z "$artiste" || "$artiste" == "Unknown artist" ]]; then
            artiste=$(exiftool -s3 -Artist "$fichier")
        fi
        if [[ -z "$artiste" || "$artiste" == "Unknown Artist" ]]; then
            artiste="❌ $artiste"
        fi
        # en 1er lecture artiste avec mid3v2
        ALBUM=$(mid3v2 --list "$fichier" | grep -a "^TALB=" | cut -d= -f2-)
        if [[ -z "$ALBUM" ]]; then
            ALBUM=$(exiftool -s3 -Album "$fichier")
        fi
        # en 1er DATE avec mid3v2
        DATE=$(mid3v2 --list "$fichier" | grep -a "^TDRC=" | cut -d= -f2-)
        if [[ -z "$DATE" ]]; then
            DATE=$(exiftool -s3 -Date "$fichier")
        fi
        #duree_sec=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nocov=1 "$fichier" | cut -d= -f2)
        duree_hms=$(ffprobe -v error -sexagesimal -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$fichier" | cut -d. -f1)
        #DUREE=$(exiftool -s3 -Duration "$fichier")
        GENRE=$(exiftool -s3 -Genre "$fichier")
         if [[ -z "$GENRE" ]]; then
            GENRE=$(mid3v2 --list "$fichier" | grep -a "^TCON=" | cut -d= -f2-)
        fi
        echo "Répertoire: $dir"
        # \e[32m : Allume la couleur verte
        # \e[0m  : Réinitialise la couleur (TRÈS IMPORTANT pour ne pas colorer tout le terminal)
        # Définition des codes ANSI
        GRAS='\033[1m'
        RAZ='\033[0m' # Rétablit le texte par défaut (Remise À Zéro)
        echo  -e "$i🎵  Artiste: ${GRAS}\e[32m$artiste\e[0m${RAZ} - 🎤 Titre: \e[32m$titre\e[0m \nDate: \e[32m$DATE\e[0m - Durée: \e[32m$duree_hms\e[0m- Album:  \e[32m$ALBUM\e[0m- Genre: \e[32m$GENRE\e[0m"
        # Incrémentation du compteur
        ((i++))
    fi
done

