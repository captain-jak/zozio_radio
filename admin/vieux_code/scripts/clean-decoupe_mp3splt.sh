#!/bin/bash

# Decoupe en utilsant mp3splt
echo "=================================================="
echo "🔗 ASSISTANT DECOUPE DE FICHIERS MP3 avec mp3splt"
echo "=================================================="
# valeurs par defaut (silence de 4s créée avec audiacity)  DECIBEL=40  -- TEMPO=4
DECIBEL=50
TEMPO=3

# 1. Demande interactive du dossier
# L'option -e permet d'utiliser l'auto-complétion avec la touche TAB !
read -e -p "📂 Glissez-déposez le dossier ici (ou tapez son chemin) : " DOSSIER_SOURCE

# NETTOYAGE CRUCIAL : 
# On enlève les éventuels guillemets simples ou doubles ajoutés par le glisser-déposer
DOSSIER_SOURCE="${DOSSIER_SOURCE#\'}"
DOSSIER_SOURCE="${DOSSIER_SOURCE%\'}"
DOSSIER_SOURCE="${DOSSIER_SOURCE#\"}"
DOSSIER_SOURCE="${DOSSIER_SOURCE%\"}"

# On vérifie si le dossier existe vraiment
if [ ! -d "$DOSSIER_SOURCE" ]; then
    echo "❌ Erreur : Chemin introuvable -> $DOSSIER_SOURCE"
    exit 1
fi

# On se déplace dans le dossier
cd "$DOSSIER_SOURCE" || exit 1

for fichier in *.mp3; do
    # On vérifie que le fichier existe bien (évite les bugs si le dossier est vide)
    [[ -f "$fichier" ]] || continue
    
    echo "--------------------------------------------------"
    echo "🎵 Analyse et découpe de : $fichier"
    echo "--------------------------------------------------"
    
    # Création d'un sous-dossier portant le nom du fichier pour ranger les morceaux
    nom_dossier="${fichier%.mp3}_decoupe"
    mkdir -p "$nom_dossier"
    
    # mp3splt : 
    # -s : mode silence
    # -p : paramètres (th = seuil dB, min = durée en secondes, rm = supprime le blanc)
    # -o : format de sortie (@f = nom d'origine, @n = numéro de piste)
    # -d : dossier de destination
    
    mp3splt -s -p th=-$DECIBEL,min=$TEMPO,rm -o "@f_piste_@n" -d "$nom_dossier" "$fichier"
    # Tres agressif
    #mp3splt -s -p th=-60,min=0.1,off=0.5,rm -o "@f_piste_@n" -d "$nom_dossier" "$fichier"
    
    echo "✅ Découpe terminée pour $fichier !"
done