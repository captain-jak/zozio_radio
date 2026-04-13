#!/bin/bash

# 1. Configuration
# Configuration - On s'assure que le chemin est ABSOLU (commence par /)


PREFIXE="Wilson Pickett - piste"
COMPTEUR=1

read -e -p "📂 Glissez-déposez le dossier ici (ou tapez son chemin) : " DOSSIER

# 2. On se déplace dans le dossier
cd "$DOSSIER" || exit 1

echo "🚀 Début du renommage dans : $PWD"

# 3. Boucle sur les fichiers (triés par nom pour garder un ordre logique)
# On ne cible que les fichiers audio pour éviter de renommer le rapport CSV
for fichier in *.{mp3,wav,ogg,m4a}; do
    
    # Vérifier si le fichier existe (évite l'erreur si aucune extension n'est trouvée)
    [ -e "$fichier" ] || continue

    # Récupérer l'extension d'origine (.mp3, .wav, etc.)
    EXT="${fichier##*.}"

    # Définir le nouveau nom
    NOUVEAU_NOM="${PREFIXE}${COMPTEUR}.${EXT}"

    # Renommage effectif
    echo "📦 '$fichier'  ->  '$NOUVEAU_NOM'"
    mv "$fichier" "$NOUVEAU_NOM"

    # Incrémenter le compteur
    ((COMPTEUR++))
done

echo "✅ Terminé ! $COMPTEUR fichiers traités."