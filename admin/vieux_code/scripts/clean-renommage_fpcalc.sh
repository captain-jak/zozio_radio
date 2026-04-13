#!/bin/bash

# Decoupe en utilsant fpcalc (avec api key acoustid.org WIp54ED47r )
echo "=================================================="
echo "🔗 ASSISTANT Renommage de fichiers MP3 avec fpcalc"
echo "=================================================="
# ⚠️ REMPLACEZ PAR VOTRE CLÉ ACOUSTID ICI
API_KEY="WIp54ED47r"

# Dossier contenant les MP3
read -e -p "📂 Glissez-déposez le dossier ici (ou tapez son chemin) : " DOSSIER_CIBLE

cd "$DOSSIER_CIBLE" || exit 1

for fichier in *.mp3; do
    [[ -f "$fichier" ]] || continue
    
    echo "--------------------------------------------------"
    echo "🔍 Analyse AcoustID de : $fichier"
    echo "--------------------------------------------------"
    
    # 1. Génération de l'empreinte avec fpcalc
    # fpcalc renvoie deux lignes : DURATION=... et FINGERPRINT=...
    infos_fpcalc=$(fpcalc "$fichier" 2>/dev/null)
    
    # Extraction propre de la durée et de l'empreinte
    duree=$(echo "$infos_fpcalc" | grep "DURATION=" | cut -d'=' -f2)
    fingerprint=$(echo "$infos_fpcalc" | grep "FINGERPRINT=" | cut -d'=' -f2)
    
    if [[ -z "$fingerprint" ]]; then
        echo "❌ Impossible de générer l'empreinte pour ce fichier."
        continue
    fi
    
    # 2. Envoi à l'API AcoustID pour chercher une correspondance
    # On demande les métadonnées de base (recordings)
    url="https://api.acoustid.org/v2/lookup?client=$API_KEY&meta=recordings&duration=$duree&fingerprint=$fingerprint"
    reponse_json=$(curl -s "$url")
    
    # 3. Extraction de l'artiste et du titre avec jq
    # AcoustID peut renvoyer plusieurs correspondances, on prend la première [0]
    artiste=$(echo "$reponse_json" | jq -r '.results[0].recordings[0].artists[0].name' 2>/dev/null)
    titre=$(echo "$reponse_json" | jq -r '.results[0].recordings[0].title' 2>/dev/null)
    
    # Vérification du résultat
    if [[ -z "$artiste" || "$artiste" == "null" ]]; then
        echo "⚠️ Aucun résultat trouvé dans la base AcoustID."
        continue
    fi
    
    # Nettoyage des caractères interdits
    artiste=$(echo "$artiste" | tr '/' '-')
    titre=$(echo "$titre" | tr '/' '-')
    
    nouveau_nom="$artiste - $titre.mp3"
    echo "🎵 Trouvé : $artiste - $titre"
    
    # 4. Renommage du fichier
    if [[ -f "$nouveau_nom" && "$fichier" != "$nouveau_nom" ]]; then
        echo "⚠️ Un fichier nommé '$nouveau_nom' existe déjà."
    else
        mv "$fichier" "$nouveau_nom"
        echo "✅ Renommé en : $nouveau_nom"
    fi
    
done