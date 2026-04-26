<?php
// Configuration des chemins
$adminPath    = "/srv/www/chantoiseau-radio/admin/";
$logFile      = $adminPath . 'scheduler_debug.log';
$jsonFile     = $adminPath . 'planning.json';
$lastHostFile = $adminPath . 'last_host.txt';
$baseDir      = "/srv/www/nextcloud/data/enjoy/files/zozio-radio/musique-animateurs/";

// 1. Configuration des profils
$config = [
    "jacques"   => ["dir" => $baseDir . "Jacques-onair",   "m3u" => $adminPath . "playlist/anime1.m3u", "id_telnet" => "anime1"],
    "guillaume" => ["dir" => $baseDir . "Guillaume-onair", "m3u" => $adminPath . "playlist/anime1.m3u", "id_telnet" => "anime1"],
    "tosha"     => ["dir" => $baseDir . "Tosha-onair",     "m3u" => $adminPath . "playlist/anime1.m3u", "id_telnet" => "anime1"],
    // Le cas "tous" ou "Musique" (id_telnet "tous" correspond à ta source par défaut dans Liquidsoap)
    "tous"      => ["dir" => "/srv/www/nextcloud/data/enjoy/files/zozio-radio/musique-onair", "m3u" => $adminPath . "playlist/onair.m3u", "id_telnet" => "tous"],
    "Musique"   => ["dir" => "/srv/www/nextcloud/data/enjoy/files/zozio-radio/musique-onair", "m3u" => $adminPath . "playlist/onair.m3u", "id_telnet" => "tous"]
];

date_default_timezone_set('Europe/Paris');

function write_log($message) {
    global $logFile;
    $timestamp = date("Y-m-d H:i:s");
    file_put_contents($logFile, "[$timestamp] $message\n", FILE_APPEND);
}

write_log("--- DEBUG : radio_scheduler.php ---");

// 2. Chargement du planning
if (!file_exists($jsonFile)) {
    write_log("ERREUR : Fichier planning.json absent.");
    echo "tous"; exit;
}

$planning = json_decode(file_get_contents($jsonFile), true);
$day = date('w'); 
$now = date('H:i');
$active = "tous"; // Valeur par défaut si rien n'est trouvé dans le planning

// 3. Détermination de l'animateur actif
if (isset($planning[$day])) {
    ksort($planning[$day]); 
    foreach ($planning[$day] as $time => $host) {
        if ($now >= $time) { 
            $active = $host; 
        }
    }
}

// 4. Initialisation des variables de travail
if (isset($config[$active])) {
    $dir = $config[$active]['dir'];
    $m3u = $config[$active]['m3u'];
    $id_telnet = $config[$active]['id_telnet'];
} else {
    // Sécurité si l'animateur est inconnu dans $config
    $dir = $config["tous"]["dir"];
    $m3u = $config["tous"]["m3u"];
    $id_telnet = "tous";
}

// 5. Récupération de l'ancien état
$lastHost = file_exists($lastHostFile) ? trim(file_get_contents($lastHostFile)) : "";
write_log("ANCIEN: $lastHost | ACTUEL: $active");

// 6. GESTION DU CHANGEMENT
if ($active == $lastHost) {
    write_log("Pas de changement.");
} else {
    write_log("CHANGEMENT DÉTECTÉ : $lastHost -> $active");
    file_put_contents($lastHostFile, $active);
    
    // Reconstruction de la playlist physique
    write_log("Reconstruction de la playlist pour $active...");
    
    // On vérifie si le répertoire existe avant le find
    if (is_dir($dir)) {
        $files = shell_exec('find ' . escapeshellarg($dir) . ' -type f -name "*.mp3"');
        $fileList = explode("\n", trim($files));
        $cleanList = [];

        foreach ($fileList as $filePath) {
            if (empty($filePath)) continue;
            $check = shell_exec("ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 " . escapeshellarg($filePath));
            if (is_numeric(trim($check))) {
                $cleanList[] = $filePath;
            }
        }
        
        file_put_contents($m3u, implode("\n", $cleanList));
        write_log("Playlist $m3u générée : " . count($cleanList) . " titres.");
    } else {
        write_log("ERREUR : Répertoire $dir introuvable.");
    }

    // --- ORDRES TELNET ---
    $fp = @fsockopen("127.0.0.1", 1234, $errno, $errstr, 2);
    
    if (!$fp) {
        write_log("ERREUR TELNET : Impossible de joindre Liquidsoap ($errstr)");
    } else {
        // 1. Nom métadonnée
        fwrite($fp, "choix_playlist.set_name " . $active . "\n");
        usleep(50000); 

        // 2. Recharge la playlist
        write_log("TELNET : Reload de $id_telnet");
        fwrite($fp, $id_telnet . ".reload\n");
        usleep(100000);

        // 3. Bascule vers la source choisie
        write_log("TELNET : Bascule vers: $id_telnet");
        fwrite($fp, "choix_playlist.set " . $id_telnet . "\n");
        usleep(100000);
        
        // 4. Skip ?? - desactiver =>  attente de la fin du morceau en cours pour jouer la nouvelle playlist
        fwrite($fp, ".skip\n"); 
         // 4.b Next  ?? - desactiver =>  attente de la fin du morceau en cours pour jouer la nouvelle playlist
        //fwrite($fp, ".next\n"); 

        fwrite($fp, "quit\n");
        fclose($fp);
        write_log("Ordres Telnet envoyés avec succès.");
    }
}

// 7. Retour pour Liquidsoap
write_log("RETOURNE : $id_telnet");
echo trim($id_telnet);
?>