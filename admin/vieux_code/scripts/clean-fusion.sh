#!/bin/bash

echo "=================================================="
echo "🔗 ASSISTANT DE FUSION DE FICHIERS MP3"
echo "=================================================="

# 1. Demande interactive du dossier
# L'option -e permet d'utiliser l'auto-complétion avec la touche TAB !
read -e -p "📂 Glissez-déposez le dossier ici (ou tapez son chemin) : " DOSSIER_CIBLE

# Nettoyage des guillemets si l'utilisateur a glissé/déposé le dossier
DOSSIER_CIBLE="${DOSSIER_CIBLE%\"}"
DOSSIER_CIBLE="${DOSSIER_CIBLE#\"}"
DOSSIER_CIBLE="${DOSSIER_CIBLE%\'}"
DOSSIER_CIBLE="${DOSSIER_CIBLE#\'}"

# On vérifie si le dossier existe vraiment
if [ ! -d "$DOSSIER_CIBLE" ]; then
    echo "❌ Erreur : Le dossier '$DOSSIER_CIBLE' n'existe pas."
    exit 1
fi

# On se déplace dans le dossier
cd "$DOSSIER_CIBLE" || exit 1

echo "--------------------------------------------------"
echo "📁 Dossier sélectionné : $DOSSIER_CIBLE"
echo "--------------------------------------------------"

# 2. On crée le fichier de liste requis par FFmpeg
> liste.txt

#for fichier in *.mp3; do
    #if [[ "$fichier" != "album_complet.mp3" && -f "$fichier" ]]; then
        #echo "file '$fichier'" >> liste.txt
        #echo "➕ Ajouté à la liste : $fichier"
    #fi
#done

for fichier in *.mp3; do
    if [[ "$fichier" != "album_complet.mp3" && -f "$fichier" ]]; then
        # CORRECTION ICI : 
        # On remplace chaque ' par '\'' pour que FFmpeg ne soit pas perdu
        NOM_SECURISE="${fichier//\'/\'\\\'\'}"
        
        echo "file '$NOM_SECURISE'" >> liste.txt
        echo "➕ Ajouté à la liste : $fichier"
    fi
done

echo "--------------------------------------------------"

# 3. On lance la fusion avec FFmpeg
if [ -s liste.txt ]; then
    echo "🚀 Fusion en cours..."
    
    ffmpeg -f concat -safe 0 -i liste.txt -c copy "album_complet.mp3"
    
    if [ $? -eq 0 ]; then
        echo "--------------------------------------------------"
        echo "✅ SUCCESS : Le fichier 'album_complet.mp3' a été créé !"
        echo "--------------------------------------------------"
        rm liste.txt
    else
        echo "❌ Erreur lors de la fusion par FFmpeg."
        rm liste.txt
    fi
else
    echo "⚠️ Aucun fichier MP3 trouvé dans ce dossier."
    rm liste.txt
fi