#!/bin/bash

# Nom du gros fichier MP3 à découper
FICHIER_AUDIO="Blues Harmonica - A two hour long compilation.mp3"
FICHIER_LISTE="tracklist.txt"

# Vérification de la présence des fichiers
if [ ! -f "$FICHIER_AUDIO" ] || [ ! -f "$FICHIER_LISTE" ]; then
    echo "❌ Erreur : Assurez-vous que le MP3 et tracklist.txt sont dans le dossier."
    exit 1
fi

# On crée un dossier pour stocker les morceaux découpés
DOSSIER_SORTIE="Compilation_Decoupee"
mkdir -p "$DOSSIER_SORTIE"

# Lecture du fichier ligne par ligne dans un tableau
mapfile -t lignes < "$FICHIER_LISTE"
total_lignes=${#lignes[@]}

echo "🚀 Début de la découpe et du taggage de $total_lignes morceaux..."
echo "--------------------------------------------------"

for ((i=0; i<total_lignes; i++)); do
    ligne_actuelle="${lignes[$i]}"
    
    # On extrait le timing, l'artiste et le titre
    debut=$(echo "$ligne_actuelle" | awk -F ' - ' '{print $1}')
    artiste=$(echo "$ligne_actuelle" | awk -F ' - ' '{print $2}')
    titre=$(echo "$ligne_actuelle" | awk -F ' - ' '{print $3}')
    
    # Numérotation pour garder l'ordre (01, 02...)
    num=$(printf "%02d" $((i+1)))
    #nom_fichier_propre="$DOSSIER_SORTIE/${num} - ${artiste} - ${titre}.mp3"
    nom_fichier_propre="${artiste} - ${titre}.mp3"

    # 1. On calcule la durée et on découpe
    if (( i + 1 < total_lignes )); then
        prochain_debut=$(echo "${lignes[$i+1]}" | awk -F ' - ' '{print $1}')
        echo "🎵 Extraction : $artiste - $titre"
        ffmpeg -ss "$debut" -to "$prochain_debut" -i "$FICHIER_AUDIO" -c copy "$nom_fichier_propre" -y -loglevel error
    else
        echo "🎵 Extraction du dernier morceau : $artiste - $titre"
        ffmpeg -ss "$debut" -i "$FICHIER_AUDIO" -c copy "$nom_fichier_propre" -y -loglevel error
    fi
    
    # 2. On applique les tags ID3 avec eyeD3
    # --artist : Nom de l'artiste
    # --title : Titre de la chanson
    # --track : Numéro de la piste
    # --album : Nom générique pour regrouper les pistes
    eyed3 -a "$artiste" -t "$titre" -n "$((i+1))" -A "Blues Harmonica Compilation" "$nom_fichier_propre" > /dev/null 2>&1
    
    echo "✅ Enregistré et tagué : $nom_fichier_propre"
done

echo "--------------------------------------------------"
echo "🎉 Terminé ! Tout est propre dans le dossier : $DOSSIER_SORTIE"