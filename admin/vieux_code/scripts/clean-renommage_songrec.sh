#!/bin/bash

# Configuration - On s'assure que le chemin est ABSOLU
read -e -p "📂 Glissez-déposez le dossier ici (ou tapez son chemin) : " DIR_BASE
REPORT_FILE="$DIR_BASE/recognition_report.csv"
TEMP_SAMPLE="/tmp/sample_songrec.wav"
PAUSE_TIME=2 

echo "=================================================="
echo "🔄  RENOMMAGE RÉCURSIF (SÉPARATEUR ::)"
echo "=================================================="

# Initialisation du rapport
echo "Dossier;Ancien Nom;Artiste;Titre" > "$REPORT_FILE"

# On utilise readlink pour être 100% sûr que DIR_BASE est absolu
DIR_BASE=$(readlink -f "$DIR_BASE")
i=1

find "$DIR_BASE" -type f \( -iname "*.mp3" -o -iname "*.ogg" \) -print0 | sort -z | while IFS= read -r -d '' FULL_PATH; do
    
    [[ "$FULL_PATH" != /* ]] && FULL_PATH="/$FULL_PATH"

    CUR_DIR=$(dirname "$FULL_PATH")
    FILE_NAME=$(basename "$FULL_PATH")

    echo "📂 Dossier : $CUR_DIR"
    echo "🔍 Analyse : $FILE_NAME"

    # 1. Extraction de l'échantillon
    ffmpeg -ss 10 -t 15 -i "$FULL_PATH" -ar 44100 -ac 1 -loglevel error -y "$TEMP_SAMPLE"
    
    if [ ! -s "$TEMP_SAMPLE" ]; then
        echo "❌ Erreur : Impossible d'accéder au fichier."
        continue
    fi

    # 2. Reconnaissance
    RESULT=$(songrec recognize "$TEMP_SAMPLE" --json 2>/dev/null)
    
    # 3. Extraction des infos via jq
    TITLE=$(echo "$RESULT" | jq -r '.track.title // "Inconnu"')
    ARTIST=$(echo "$RESULT" | jq -r '.track.subtitle // "Inconnu"')

    if [ "$TITLE" != "Inconnu" ] && [ "$TITLE" != "" ]; then
        # CHANGEMENT ICI : Utilisation de :: comme séparateur
        # On garde tr pour nettoyer les caractères interdits par le système de fichiers
        #CLEAN_NAME=$(echo "${ARTIST}::${TITLE}.mp3" | tr '/' '-' | tr -d '*?:"<>|')
        #-----------------------------------------------------------------------------------------------------------------------------------------
        # On nettoie les caractères interdits SAUF le deux-points pour l'instant
# Puis on change les slashes en tirets
CLEAN_NAME=$(echo "${ARTIST}::${TITLE}.mp3" | tr '/' '-')
        #-----------------------------------------------------------------------------------------------------------------------------------------

# On supprime les caractères vraiment interdits (sauf le deux-points :)
CLEAN_NAME=$(echo "$CLEAN_NAME" | tr -d '*?"<>|')
        
        echo -e "$i ✅ Trouvé : ${ARTIST} :: ${TITLE}"
        echo "$CUR_DIR;$FILE_NAME;$ARTIST;$TITLE" >> "$REPORT_FILE"

        NEW_FULL_PATH="$CUR_DIR/$CLEAN_NAME"

        if [ "$FULL_PATH" != "$NEW_FULL_PATH" ]; then
            # Gestion des doublons : on ajoute le timestamp si le fichier existe déjà
            if [ -f "$NEW_FULL_PATH" ]; then
                NEW_FULL_PATH="$CUR_DIR/${ARTIST}::${TITLE}_$(date +%s).mp3"
            fi
            mv "$FULL_PATH" "$NEW_FULL_PATH"
            echo "📦 Renommé : $(basename "$NEW_FULL_PATH")"
        else
            echo "ℹ️ Déjà bien nommé."
        fi
    else
        echo "❌ Non identifié."
        echo "$CUR_DIR;$FILE_NAME;NON_IDENTIFIE;NON_IDENTIFIE" >> "$REPORT_FILE"
    fi

    [ -f "$TEMP_SAMPLE" ] && rm -f "$TEMP_SAMPLE"
    sleep $PAUSE_TIME
    echo "--------------------------"
    ((i++))
done

echo "🏁 Terminé ! Rapport disponible dans : $REPORT_FILE"