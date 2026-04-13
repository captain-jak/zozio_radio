zozio_radio: outils pour administrer la radio
# Régie zozio radio

Outils de gestion de la radio

## 📌 Description

Ce projet est destiné à zozio radio [ouitls administration de la radio].  

## 🚀 Utilisation:

Tout les fichiers sont obligatoirement au format mp3<br>
Avant d'être injecté dans la radio, ils sont verifiées, et notamment leurs noms qui permettra de determiner les infos affichées, 
lors du passage à la radio:<br>
ARTISTE   -  TITRE -- ANNEE
Le format du fichier est ARTISTE::TITRE::ANNEE  (le séparateur est "::"<br>
Des outils on été développés pour vérifier et convertir la cohérence de ces fichiers:<br>
🎤./clean_renommage_songreg.sh<br>
lis la base de données shazam pour récupérer artiste et titre  des fichiers du répertoire entré - renome le fichier avec ces infos au format artiste::titre::annee<br>
🎤 clean-inject.sh<br>
injecte au format mp3db artiste, titre et duree des fichiers du répertoire entré<br>
🎤clean-duree.sh<br>
injecte au format mp3db a duree en secondes + totalise la durée totale cumulée des fichiers du répertoire entré<br>
🎤 clean-lecture.sh<br>
affichage des noms artiste - titre durée des fichiers du répertoire entré<br>


## 🛠️ Installation

Clone the repository:

```bash
git clone https://github.com/your-username/your-repository.git
# =========  github ===================
# 1 - Initialisation du projet locale:
cd ~/dev/Reconnaissance_vocale/gen/srv/AndroidStudioProjects/RadioCommande
git init
git add .
git commit -m "Initial commit from Geany 2.10"
# 2 - Link to GitHub
git remote add origin https://github.com/captain-jak/RadioCommande
git remote set-url origin git@github.com:captain-jak/RadioCommande.git
# 3 - Push the Code
git add . && git commit -m "update" && git push -u origin main
git push -u origin main

## 🛠️ Prerequis

Sur le serveur:
sudo apt install sshfs mpv socat id3v2 ffmpeg
