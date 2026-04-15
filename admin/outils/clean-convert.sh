#!/bin/bash

# ce script convertit tout les fichiers .wma, .mp4. .aac, .ogg, . flac, . m4a 
#d'un répertoire et sous-répertoire en mp3

read -e -p "📂 Glissez-déposez le dossier ici (ou tapez son chemin) : " DIR_BASE

if [ ! -d "$DIR_BASE" ]; then
  echo "❌ Dossier invalide"
  exit 1
fi

cd "$DIR_BASE" || exit 1

echo "🔍 Scan des fichiers..."

find . -type f \( -iname "*.wma" -o -iname "*.ogg" -o -iname "*.flac" -o -iname "*.mp4" -o -iname "*.aac" -o -iname "*.m4a" -o -iname "*.wav" \) -print0 |
parallel -0 --bar -j+0 '
file={}
out="${file%.*}.mp3"



# sécurité anti re-conversion
[ -f "$out" ] && exit 0

# conversion SAFE (quotes obligatoires)
ffmpeg -hide_banner -loglevel error -fflags +genpts -i "$file" -vn -acodec libmp3lame -b:a 128k "$out" && rm -- "$file"
'

echo "✅ Conversion terminée !"