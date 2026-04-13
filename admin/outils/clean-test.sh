#!/bin/bash

read -e -p "📂 Glissez-déposez le dossier ici (ou tapez son chemin) : " DIR_BASE
# Configuration
#DIR_BASE="/media/enjoy/Data/musique/zozio radio/Musique librairie/Folk - Country"

# Couleurs
ORANGE='\033[0;33m'
ROUGE_FLASH='\033[1;5;31m'
VERT='\033[0;32m'
RAZ='\033[0m'

lire_artiste_titre_annee() {
    local nom_fichier_seul=$(basename "$1")
    local nom_sans_ext="${nom_fichier_seul%.*}"
    
    # 1. TEST DU FORMAT ACTUEL (::)
    if [[ "$nom_sans_ext" == *"::"* ]]; then
        local nb_sep=$(echo "$nom_sans_ext" | grep -o "::" | wc -l)
        if [ "$nb_sep" -ge 2 ]; then
            local annee="${nom_sans_ext##*::}"
            if [[ "$annee" =~ ^[0-9]{4}$ ]]; then
                echo "${nom_sans_ext%%::*}|${nom_sans_ext#*::%::*}|$annee"
                return 0
            fi
        fi
        echo "${nom_sans_ext%%::*}|${nom_sans_ext#*::}|"
        return 0
    fi

    # 2. TEST DE L'ANCIEN FORMAT ( - )
    # On vérifie s'il y a bien au moins un " - " (espace tiret espace)
    if [[ "$nom_sans_ext" == *" - "* ]]; then
        local nb_sep=$(echo "$nom_sans_ext" | grep -o " - " | wc -l)
        local artiste="" titre="" annee=""

        if [ "$nb_sep" -ge 2 ]; then
            local possible_annee="${nom_sans_ext##* - }"
            if [[ "$possible_annee" =~ ^[0-9]{4}$ ]]; then
                artiste="${nom_sans_ext%% - *}"
                local reste="${nom_sans_ext#* - }"
                titre="${reste% - *}"
                annee="$possible_annee"
            fi
        fi

        # Si l'année n'était pas un nombre, on traite comme un simple Artiste - Titre
        if [ -z "$artiste" ]; then
            artiste="${nom_sans_ext%% - *}"
            titre="${nom_sans_ext#* - }"
        fi
        
        echo "$artiste|$titre|$annee"
        return 0
    fi

    return 1 # Aucun format reconnu (ni :: ni - )
}

i=1
find "$DIR_BASE" -type f \( -iname "*.mp3" -o -iname "*.ogg" \) -print0 | sort -z | while IFS= read -r -d '' FULL_PATH; do
    
    DIR_ACTUEL=$(dirname "$FULL_PATH")
    NOM_ORIGINAL=$(basename "$FULL_PATH")
    
    infos=$(lire_artiste_titre_annee "$FULL_PATH")
    RET_CODE=$?

    echo "------------------------------------------------------------------------------------------:"
    
    if [ $RET_CODE -eq 0 ]; then
        IFS="|" read -r r_artiste r_titre r_annee <<< "$infos"
        # On force la sortie vers le nouveau format CLEAN (::)
        if [ -n "$r_annee" ]; then
            NOUVEAU_NOM="${r_artiste}::${r_titre}::${r_annee}.mp3"
        else
            NOUVEAU_NOM="${r_artiste}::${r_titre}.mp3"
        fi

        if [ "$NOM_ORIGINAL" != "$NOUVEAU_NOM" ]; then
            mv "$FULL_PATH" "$DIR_ACTUEL/$NOUVEAU_NOM"
            echo -e "$i 🔄 ${VERT}Conversion vers ::${RAZ}"
            echo "   Ancien : $NOM_ORIGINAL"
            echo "   Nouveau: $NOUVEAU_NOM"
        else
            echo -e "$i ✅ ${VERT}Déjà conforme :${RAZ} $NOM_ORIGINAL"
        fi
    else
        # --- MODE MANUEL SI RIEN NE CORRESPOND ---
        echo -e "$i ⚠️  ${ROUGE_FLASH}NOM INCORRECT :${RAZ} $NOM_ORIGINAL"
        echo -e "${ORANGE}Saisissez le nouveau nom (Format: Artiste::Titre) :${RAZ}"
        echo -e "(Appuyez sur Entrée pour ignorer ce fichier)"
        
        read -p "> " SAISIE < /dev/tty
        
        if [ -n "$SAISIE" ]; then
            [[ "$SAISIE" != *.mp3 ]] && SAISIE="${SAISIE}.mp3"
            mv "$FULL_PATH" "$DIR_ACTUEL/$SAISIE"
            echo -e "✅ Corrigé manuellement."
        else
            echo "Fichier ignoré."
        fi
    fi
    ((i++))
done
