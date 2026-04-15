#!/bin/bash

#/-------------------------------------------------------------------------------------------------------------------------
# Ce script va calculer la durèe totale des fichiers MP3 dans le répertoire BASE_DIR
# cas N° 1 = duree trop longue  ==> Déplacement dans repertoire DIR_DUREE_TROP_LONG pour être retravaillé -- affichage en rouge
# cas N° 2 = durtee trop courte  ==> Avertissement  -- affichage avertissement
# cas N° 3 = duree pas reconnue ou nulle  ==> Déplacement dans repertoire DIR_DUREE_TROP_LONG pour être retravaillé -- affichage en rouge
# cas N° 4 = duree est conforme
#/-------------------------------------------------------------------------------------------------------------------------

SEUIL_X=99000  # seuil supérieur en secondes
SEUIL_Y=30  # seuil inférieur en secondes
#DIR_DUREE_TROP_LONG="/srv/Musique à découper" # Répertoire dans lequel sont deplacés les fichiers trop long
DIR_DUREE_TROP_LONG="/media/enjoy/Data/musique/xx-NON-CONFORME"
# supprime $DIR_ORIGINE du fichier trop long (par défaut "/media/enjoy/Data/musique/zozio radio/Musque librairie")
DIR_ORIGINE="/media/enjoy/Data/musique/zozio radio/Musique librairie"
# si AFFICHAGE non vide = affiche tout les fichiers
# si AFFICHAGE  vide  = affiche uniquement les fichiers de + de $SEUIL_X secondes ou -  $SEUIL_Y secondes
AFFICHAGE="ok"
# si DEBUG vide = pas d'affichage messages de debugging 
DEBUG=""
# Valeur par défaut
EFFACER_ORIGINE=false

# Dossier contenant les MP3
read -e -p "📂 Glissez-déposez le dossier ici (ou tapez son chemin) : " DIR_BASE
#DIR_BASE="/srv/www/nextcloud/data/enjoy/files/zozio-radio/musique-librarie/Humour/"
#DIR_BASE="/media/enjoy/Data/musique/zozio radio/Musique librairie/Humour"

total_sec=0
ORANGE='\033[0;33m'
ORANGE_FLASH='\033[1;5;33m'
ROUGE='\033[0;31m'
ROUGE_FLASH='\033[1;5;31m'
VERT='\033[0;32m'
VERT_FLASH='\033[1;5;32m'
RAZ='\033[0m' # Rétablit la couleur par défaut

# Analyse des arguments passés au script
for arg in "$@"; do
  case $arg in
    -e=true)
      EFFACER_ORIGINE=true
      shift # supprime l'argument de la liste
      ;;
    -e=false)
      EFFACER_ORIGINE=false
      shift
      ;;
    *)
      # Option inconnue ou autre argument
      ;;
  esac
done

# =============================================================================================
#                    LES              FONCTIONS 
# =============================================================================================
# ----------------- Fonction de gestion de la pause (Touche ESPACE) --------------------------------

# ----------------- Fonction de gestion de la pause (Touche ESPACE) --------------------------------
# ----------------- Fonction de gestion de la pause (Touche ESPACE) --------------------------------
# ----------------- Fonction de gestion de la pause (Touche ESPACE) --------------------------------
check_pause() {
    # On force stty à regarder le terminal (/dev/tty) et non le flux de fichiers
    # On sauvegarde les paramètres et on passe en mode non-bloquant
    old_tty_settings=$(stty -g < /dev/tty)
    stty -icanon min 0 time 0 < /dev/tty
    
    # Lecture d'un caractère au vol
    key=$(dd bs=1 count=1 if=/dev/tty 2>/dev/null)
    
    # Restauration immédiate
    stty "$old_tty_settings" < /dev/tty
    if [[ "$key" == " " ]]; then
        echo -e "\n${ORANGE_FLASH} ⏸  PAUSE (Appuyez sur une touche pour reprendre...)${RAZ}"
        # On attend sans timeout pour la reprise
        read -n 1 -s < /dev/tty
        echo -e "${VERT} ▶  REPRISE...${RAZ}\n"
    elif [[ "$key" == "q" ]]; then
        echo -e "\n${ROUGE}🛑 Arrêt par l'utilisateur.${RAZ}"
        exit 0
    fi
}

# --------      Fonction de conversion flexible (gère H:M:S ,M:S et S) qui  doit retourner des secondes ---------------------------------
to_seconds() {
    local duree="$1"
    lefichier="$2"
    # On supprime tout ce qui n'est pas un chiffre ou le séparateur ":"
    duree=$(echo "$duree" | sed 's/[^0-9:]//g')
    local heures=0 minutes=0 secondes=0 secondes_totales=0
    # On découpe la chaîne en ignorant les séparateurs (:) 
    # en comptant le nombre d'éléments
    IFS=':' read -r -a parties <<< "$duree"
    local nb_elements=${#parties[@]}
    if [ "$nb_elements" -eq 3 ]; then
        # Format HH:MM:SS
        [[ -n "$DEBUG" ]] && echo "     ⚡$LINENO:to_seconds : Format HH:MM:SS" >&2
        heures="${parties[0]}"
        minutes="${parties[1]}"
        secondes="${parties[2]}"
    elif [ "$nb_elements" -eq 2 ]; then
        # Format MM:SS
       [[ -n "$DEBUG" ]] && echo "     ⚡$LINENO:to_seconds : Format MM:SSS" >&2
        minutes="${parties[0]}"
        secondes="${parties[1]}"
    else
        # Déjà en secondes ou format inconnu
        secondes="${parties[0]}"
        [[ -n "$DEBUG" ]] && echo  -e "     ⚡$LINENO:to_seconds : Appel de la fonction convertir_S_en_HMS" >&2
        # lconvertir en , pour l'inkecter dans le titre
        sec=$(convertir_S_en_HMS "$secondes")
    fi
        heures=$((10#${heures:-0}))
        minutes=$((10#${minutes:-0}))
        secondes=$((10#${secondes:-0}))
        # Calcul mathématique final
        secondes_totales=$(( heures * 3600 + minutes * 60 + secondes ))
        echo "$secondes_totales"
}

# -----------------------------      Fonction de conversion secondes en H:M:S ,M:S et S ------------------------------------------------------------
convertir_S_en_HMS() {
    local secondes_totales=$1
    # Nettoyage : on s'assure que l'entrée ne contient que des chiffres
    secondes_totales=$(echo "$secondes_totales" | tr -dc '0-9')
    # Si la variable est vide après nettoyage, on met 0
    [[ -z "$secondes_totales" ]] && secondes_totales=0
    # Calculs mathématiques
    local h=$(( secondes_totales / 3600 ))
    local m=$(( (secondes_totales % 3600) / 60 ))
    local s=$(( secondes_totales % 60 ))
    # Formatage avec des zéros devant (02d = 2 chiffres minimum)
    printf "%02d:%02d:%02d\n" "$h" "$m" "$s"
}

# ----------------- Fonction qui détecte et retourne la duree d'un fichier---------------------------------------------------------------------------
detect_duree() {
    # On récupère le premier argument passé à la fonction
    local fichier_recu="$1"
    fichier_recu=$(printf "%s" "$fichier_recu")
    local laduree=""
    local ensec=0
    local source="mid3v2"
# -- 1 -- detection avec mid3v2
    laduree=$(mid3v2 --list "$fichier_recu" | grep -a "^TXXX=duration=" | cut -d= -f3)
   [[ -n "$DEBUG" ]] && echo -e "     ⚡$LINENO:detect_duree : mid3v2:  $laduree" >&2
# -- 2 -- detection avec ffprobe (exécuté SI $laduree est vide OU > $SEUIL_X OU  <1)
    if [[ -z "$laduree" || "$laduree" -lt 1 || "$laduree" -gt "$SEUIL_X" ]]; then
        source="ffprobe"
        laduree=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$fichier" | awk '{print int($1)}')
         [[ -n "$DEBUG" ]] && echo -e "     ⚡$LINENO:detect_duree : ffprobe:  $laduree" >&2
        # on en profite pour corriger IDv2 tag
        [[ -n "$DEBUG" ]] && echo "💾 $LINENO: Injection de la durée ($laduree sec) dans les tags ID3v2..." >&2
         #if [ "$EFFACER_ORIGINE" = true ]; then
            #echo -e "$LINENO:inject_duree: ${VERT}✔${RAZ}  Durée réelle détectée : ${VERT}$laduree${RAZ} secondes (inférieure à $SEUIL_X)." >&2
            #mid3v2 --TXXX "duration:$laduree" "$fichier_recu"
        #fi
    fi
    ensec=$(to_seconds "$laduree" "$fichier")
    # retourne $laduree en secondes
   [[ -n "$DEBUG" ]] && echo "     ⚡$LINENO : Retour de la fonction  $ensec" >&2
    echo $ensec $source
}

# ----------------- Fonction deplacement du fichier dans un repertoire de travail---------------------------------------------------------------
deplace_fichier() {
    # On récupère le premier argument passé à la fonction
    local fichier_recu="$1"
     # 1. Extraction de la durée
    # Étape 1 - Déplacement de $fichier_recu vers le répertoire de travail
    # 1. On COPIE le fichier ET toute son arborescence
    # Note : On utilise bien ici $fichier_recu passé en paramètre !
    # Le motif à supprimer (le début du chemin)
    # Extraction du dossier uniquement
    dossier_seul=$(dirname "$fichier_recu")
    motif="$DIR_ORIGINE"
    # Suppression du motif au début de la chaîne (#)
    dir_nettoye="${dossier_seul#$motif}"

    echo "\n✅ $DIR_DUREE_TROP_LONG$dir_nettoye"
    mkdir -p "$DIR_DUREE_TROP_LONG$dir_nettoye"
    cp  "$fichier_recu" "$DIR_DUREE_TROP_LONG$dir_nettoye/"
    #cp --parents "$fichier_nettoye" "$DIR_DUREE_TROP_LONG/"
   # test si cp rate , pas de suppression
    if [ $? -eq 0 ]; then
        #echo "\n✅ Copie réussie de $fichier_recu dans : $DIR_DUREE_TROP_LONG$dir_nettoye"
        # 2. On SUPPRIME le fichier d'origine
        #rm "$fichier_recu"
        chemin_absolu="$DIR_DUREE_TROP_LONG$dir_nettoye"
        echo "$chemin_absolu"
    else
        echo "\n❌ Erreur : Échec de la copie de $fichier_recu"
    fi
    # Étape 2 - Calcul du chemin absolu du fichier fraîchement créé
    # On combine le dossier de destination et le chemin du fichier reçu
    #local chemin_absolu="$(realpath "$DIR_DUREE_TROP_LONG/$fichier_recu")"
    local chemin_absolu="$DIR_DUREE_TROP_LONG$dir_nettoye/$(basename "$fichier_recu")"
    # Étape 3 - On "retourne" le nom de la fonction et le chemin absolu
     [[ -n "$DEBUG" ]] && echo  -e"     ⚡$LINENO:deplace_fichier : ${ROUGE_FLASH}==> $chemin_absolu${EAZ}" >&2
    echo "$chemin_absolu"
}

# ----------------- Fonction injection duree correctel -----------------------------------------------------------------------------------------------------
inject_duree() {
    # On récupère le premier argument passé à la fonction avec $1
    local fichier_recu="$1"
    [[ -n "$DEBUG" ]] && echo -e "     ⚡$LINENO:inject_duree: Traitement inject_duree" >&2
    # ------- étape 1 =  détection de la duréé--------------------------------------
    [[ -n "$DEBUG" ]] && echo -e "     ⚡$LINENO:inject_duree: Appel fonction detect_duree" >&2
    resultat=( $(detect_duree "$fichier_recu") )
    local laduree="${resultat[0]}"
    local lasource="${resultat[1]}"
    [[ -n "$DEBUG" ]] && echo -e "     ⚡$LINENO:inject_duree: résultat detect_duree = ${ORANGE_FLASH}$laduree${RAZ}" >&2
    # Vérification que l'extraction a fonctionné
    if [[ -n "$laduree" ]]; then
        # La condition : supérieure à 0 ET inférieure à SEUIL_X ET la source est mid3v2
        if [[ "$laduree" -gt 1 && "$laduree" -lt "$SEUIL_X" && $lasource == "mid3v2" ]]; then
            # Tout va tres bien - le tag ID3v2 $DUREE est conforme
            [[ -n "$DEBUG" ]] && echo -e "     ⚡$LINENO:inject_durée : $laduree" >&2
        # La condition : supérieure à 0 ET inférieure à SEUIL_X ET la source est ffprobe
        elif [[ "$laduree" -gt 1 && "$laduree" -lt "$SEUIL_X" && $lasource == "ffprobe" ]]; then
             # ------- étape 1 =  iAffichage du message de réussite en VERT --------------------------------------
             # mode edition, on injecte $DUREE dans $fichier
             if [ "$EFFACER_ORIGINE" = true ]; then
                echo -e "$LINENO:inject_duree: ${VERT}✔${RAZ}  Durée réelle détectée : ${VERT}$laduree${RAZ} secondes (inférieure à $SEUIL_X)." >&2
                # ------- étape 2 =  injection nouvelle duree  --------------------------------------
                [[ -n "$DEBUG" ]] && echo -e "     💾$LINENO:inject_duree: Injection de la durée ($laduree sec) dans les tags ID3v2..." >&2
                mid3v2 --TXXX "duration:$laduree" "$fichier"
            fi
            [[ -n "$DEBUG" ]] && echo -e "${ORANGE}[DBG] Ligne $LINENO :${RAZ} Tag ID3v2 injecté avec succès pour $fichier" >&2
        else
                [[ -n "$DEBUG" ]] && echo -e "     ⚠️ $LINENO:inject_duree $fichier, durée incorrecte ou trop longue" >&2
        fi
        # La fonction retourne $la duree
        echo $laduree
    else
        [[ -n "$DEBUG" ]] && echo -e "     ⚠️$LINENOinject_duree: Impossible de lire la durée de $fichier on le deplace dans DIR_DUREE_TROP_LONG" >&2
        #Déplacement de $fichier dans DIR_DUREE_TROP_LONG
        new_fichier=$(deplace_fichier "$fichier_recu")
        [[ -n "$DEBUG" ]] && echo -e "     ⚡$LINENOinject_duree : Le titre est maintenant ici $new_fichier" >&2
    fi
}

# =============================================================================================
#                                                      PROGRAMME PRINCIPAL
# =============================================================================================
# Vérification si le dossier existe
if [ ! -d "$DIR_BASE" ]; then
    echo "❌$LINENO: Erreur : Le dossier '$DIR_BASE' est introuvable."
    exit 1
fi
echo "--------------------------------------------------------------------------------------"
echo "⏳              Analyse de la discographie $DIR_BASE"
echo "--------------------------------------------------------------------------------------"

# Utilisation de la redirection < <() pour que total_sec survive à la boucle
# classement par ordre alphabétique
i=1
while read -r fichier; do
    [[ -n "$DEBUG" ]] && echo -e "⚡--------------------------------------------------------\n$LINENO : Analyse de $fichier\n--------------------------------------------------------" >&2
   
   # APPEL DE LA PAUSE (on redirige l'entrée vers le terminal actuel)
# 1. Gestion de la pause (Vérifiée à chaque fichier)
    check_pause

    [[ -n "$DEBUG" ]] && echo -e "⚡---------------------------" >&2
   
    # On filtre uniquement les MP3 via ExifTool
    if exiftool -FileType "$fichier" | grep -q "MP3"; then
  
        IFS= read -r TITRE <<< "$(mid3v2 --list "$fichier" | grep -a "^TIT2=" | cut -d= -f2-)"
        # 2. On supprime les espaces au début (Ligne séparée !)
        TITRE="${TITRE#"${TITRE%%[![:space:]]*}"}" 
        # 3. On supprime les espaces à la fin (Ligne séparée !)
        TITRE="${TITRE%"${TITRE##*[![:space:]]}"}"
        
        IFS= read -r ARTISTE <<< "$(mid3v2 --list "$fichier" | grep -a "^TPE1=" | cut -d= -f2-)"
        # -- -- Extraction de la duréee du titre
        [[ -n "$DEBUG" ]] && echo -e "⚡$LINENO : appel fonction inject_duree" >&2
        DUREE=$(inject_duree "$fichier")
        [[ -n "$DEBUG" ]] && echo -e "⚡$LINENO : retour fonction inject_duree = $DUREE" >&2
         #----------------------------------------------
         # cas N° 1 = duree trop longue
        #----------------------------------------------
        if [[ "$DUREE" -gt "$SEUIL_X" ]]; then
            echo -e "🛑$LINENO : $fichier === Durée du fichier ${ROUGE_FLASH}$DUREE${RAZ} secondes trop long ."
            # Déplacement du fichier dans $DIR_DUREE_TROP_LONG
            if [ "$EFFACER_ORIGINE" = true ]; then
                leresultat=$(deplace_fichier "$fichier")
            fi
            echo -e "⚠️ $LINENO : Maintenant ici ${ORANGE}$leresultat${RAZ}"
            #leresultat=$(inject_duree "$fichier")
           [[ -n "$DEBUG" ]] && echo "⚡$LINENO : Le titre est maintenant ici ${ORANGE}$leresultat${RAZ}" >&2
        #----------------------------------------------
        # cas N° 2 = durtee trop courte  mais pas nulle (1s)
        #----------------------------------------------
        elif [[ "$DUREE" -lt "$SEUIL_Y" && "$sec" -gt 1 ]]; then
            echo -e "⚠️ $LINENO : $fichier  === Durée du fichier ${ORANGE}$DUREE${RAZ} secondes trop court ?${RAZ}"
            total_sec=$((total_sec + sec))
        #----------------------------------------------
        # cas N° 3 = durtee nulle (<1s) 
        #----------------------------------------------
        elif [[ "$DUREE" -lt 1 ]]; then
            echo -e "🛑$LINENO : $fichier === Durée du fichier ${ROUGE}$DUREE${RAZ} secondes nulle ou pas reconnue."
#==>             leresultat=$(deplace_fichier "$fichier")
            echo -e "⚠️ $LINENO : Maintenant ici ${ORANGE}$leresultat${RAZ}"
            #leresultat=$(inject_duree "$fichier")
           [[ -n "$DEBUG" ]] && echo "⚡$LINENO : Le titre est maintenant ici ${ORANGE}$leresultat${RAZ}" >&2
        #----------------------------------------------
        # cas N° 4 = La durée est conforme
        #----------------------------------------------
        else
            total_sec=$((total_sec + DUREE))
            #Plus lisible lecture $DUREE au format HMS
            laduree=$(convertir_S_en_HMS "$DUREE")
            [[ -n "$AFFICHAGE" ]] && echo "$i🔹$ARTISTE - $TITRE - $laduree " >&2
        fi
        ((i++))
    fi
done < <(find "$DIR_BASE" -type f -iname "*.mp3" | sort)

# --- Calculs finaux ---
temps_total=$(convertir_S_en_HMS "$total_sec")

echo "------------------------------------------------"
echo "🎼$LINENO : Total fichiers : $(find "$DIR_BASE" -type f -iname "*.mp3" | wc -l)"
echo "🕒$LINENO : Durée cumulée  : $temps_total"
echo "📊 $LINENO :Total secondes : $total_sec s"
echo "------------------------------------------------"
