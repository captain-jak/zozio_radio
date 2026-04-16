#!/bin/bash

# Dossier contenant les MP3
read -e -p "📂 Glissez-déposez le dossier ici (ou tapez son chemin) : " DIR_BASE

GENRE="Musique du monde"
GENRE_ID3V2=   # id3v2 -L  pour avoir la lise des catégories
LALBUM=""
TITRE_FORCE="True"
ARTISTE_FORCE="True"
ANNEE_FORCE=""

# ===============  Fonction : Découpe le nom de fichier (Format: Artiste::Titre::Année)  ======================
extraire_nom() {
    local expression="$1"
    local nom_sans_ext="${expression%.*}" # Enlève .mp3 ou .ogg
    
    artiste=""
    titre=""
    annee=""

    # On compte le nombre de séparateurs "::"
    local nb_sep=$(echo "$nom_sans_ext" | grep -o "::" | wc -l)

    if [ "$nb_sep" -ge 2 ]; then
        # Format: Artiste::Titre::Année
        local possible_annee="${nom_sans_ext##*::}"
        if [[ "$possible_annee" =~ ^[0-9]{4}$ ]]; then
            artiste="${nom_sans_ext%%::*}"
            local reste="${nom_sans_ext#*::}"
            titre="${reste%::*}"
            annee="$possible_annee"
            echo "Artiste: $artiste - Titre: $titre - Année: $annee"
            return 0
        fi
    fi

    if [ "$nb_sep" -ge 1 ]; then
        # Format: Artiste::Titre
        artiste="${nom_sans_ext%%::*}"
        titre="${nom_sans_ext#*::}"
        echo "Artiste: $artiste - Titre: $titre"
        return 0
    fi
    
    return 1
}

# ===============  Fonction : Découpe le nom du répertoire (Format: Album::Année)  ======================
extraire_nom_dir() {
    local entree="$1"
    album=""
    annee_dir=""

    if [[ "$entree" == *"::"* ]]; then
        local possible_annee="${entree##*::}"
        if [[ "$possible_annee" =~ ^[0-9]{4}$ ]]; then
            album="${entree%%::*}"
            annee_dir="$possible_annee"
        else
            album="$entree"
        fi
    else
        album="$entree"
    fi
}

#=================              Programme principal               ==========================
i=1
find "$DIR_BASE" -type f | sort | while read -r fichier; do
    if exiftool -s3 -FileType "$fichier" | grep -qE "MP3|OGG"; then
        base=$(basename "$fichier")
        dir=$(dirname "$fichier")
        
        # Initialisation pour ce fichier
        artiste="" ; titre="" ; annee=""

        # ------------------------- Extraction Artiste / Titre -----------------
        if [ "$ARTISTE_FORCE" = "True" ] || [ "$TITRE_FORCE" = "True" ]; then
            extraire_nom "$base" > /dev/null
        fi

        # Si non forcé ou non trouvé dans le nom, on cherche dans les tags
        if [ -z "$artiste" ]; then
            artiste=$(exiftool -s3 -Artist "$fichier")
            if [[ -z "$artiste" || "$artiste" == "Unknown artist" ]]; then
                artiste=$(mid3v2 --list "$fichier" | grep "^TPE1=" | cut -d= -f2-)
            fi
        fi

        if [ -z "$titre" ]; then
            titre=$(exiftool -s3 -Title "$fichier")
            if [[ -z "$titre" || "$titre" == "Unknown" ]]; then
                titre=$(mid3v2 --list "$fichier" | grep "^TIT2=" | cut -d= -f2-)
            fi
        fi

        # ------------------------- Injections -----------------
        
        # Injection ARTISTE
        if [[ -n "$artiste" && "$artiste" != "Unknown artist" && "$ARTISTE_FORCE" == "True" ]]; then
            mid3v2 --TPE1="$artiste" "$fichier"
            id3v2 -a "$artiste"  "$fichier"
            echo "✅ Tag Artiste: $artiste"
        fi

        # Injection TITRE
        if [[ -n "$titre" && "$titre" != "Unknown" && "$TITRE_FORCE" == "True" ]]; then
            mid3v2 --song="$titre" "$fichier"
            id3v2 -t "$titre"  "$fichier"
            echo "✅ Tag Titre: $titre"
        fi

        # Injection ANNEE
        LANNEE=""
        if [ -n "$ANNEE_FORCE" ]; then
            LANNEE="$ANNEE_FORCE"
        else
            parent=$(basename "$dir")
            extraire_nom_dir "$parent"
            if [ -n "$annee_dir" ]; then
                LANNEE="$annee_dir"
            elif [ -n "$annee" ]; then
                LANNEE="$annee"
            fi
        fi

        if [ -n "$LANNEE" ]; then
            mid3v2 --date="$LANNEE" "$fichier"
            id3v2 -y "$LANNEE"  "$fichier"
            echo "✅ Tag Année: $LANNEE"
        fi

        # Injection GENRE
        if [ -n "$GENRE" ]; then
            mid3v2 --genre="$GENRE" "$fichier"
            id3v2 -g $GENRE_ID3V2  "$fichier"
        fi

        # Injection ALBUM
        if [ -n "$LALBUM" ]; then
            mid3v2 --TALB="$LALBUM" "$fichier"
        else
            extraire_nom_dir "$(basename "$dir")"
            if [ -n "$album" ]; then
                mid3v2 --TALB="$album" "$fichier"
                echo "✅ Tag Album: $album"
            fi
        fi

        # Affichage final
        echo -e "$i 🎵 Artiste: \e[32m${artiste:-Inconnu}\e[0m - 🎤 Titre: \e[32m${titre:-Inconnu}\e[0m - 📅 Date: \e[32m${LANNEE:-....}\e[0m"
        echo "--------------------------"
        ((i++))
    fi
done