<?php
//-------------   script corrigé le 16.04.2026 ---------------
error_reporting(E_ALL);
ini_set('display_errors', 1);

// On autorise la page HTML à appeler ce script (CORS)
header("Access-Control-Allow-Origin: *");
// Le type de contenu par défaut (sera surchargé en application/json pour queue/reload)
header("Content-Type: text/plain; charset=utf-8");

$action = isset($_GET['action']) ? $_GET['action'] : '';
$file = isset($_GET['file']) ? $_GET['file'] : '';

$fp = @fsockopen("127.0.0.1", 1234, $errno, $errstr, 5);
if (!$fp) {
    http_response_code(500);
    echo "Erreur : Impossible de joindre Liquidsoap ($errstr)";
    exit;
}

usleep(100000); 
$response_text = "";

// --- FONCTION POUR LIRE TELNET ---
function get_telnet_val($fp, $cmd) {
    fwrite($fp, $cmd . "\n");
    $result = "";
    while ($line = fgets($fp, 512)) {
        $line = trim($line);
        if ($line == "END") break;
        if ($line != "" && $line != '""') $result = str_replace('"', '', $line);
    }
    return $result;
}

// ... (début du script inchangé)

switch ($action) {
    case 'skip':
        fwrite($fp, "icecast_out.skip\n");
        $response_text = "⏭ Passage au titre suivant";
        break;

    case 'jingle':
        if (!empty($file)) {
            // On envoie le chemin du fichier à la queue jingles via Telnet
            fwrite($fp, "jingles.push $file\n");
            $response_text = "📢 Jingle lancé : " . basename($file);
        } else {
            $response_text = "❌ Erreur : Aucun fichier spécifié";
        }
        break;

    case 'reload':
        // On récupère l'animateur actuel pour savoir quelle playlist recharger
        $current = get_telnet_val($fp, "choix_playlist.get");
        $id_to_reload = ($current == "onair" || $current == "tous" || empty($current)) ? "tous" : $current;
        
        fwrite($fp, $id_to_reload . ".reload\n");
        $response_text = "🔄 Playlist '$id_to_reload' rechargée depuis le disque";
        break;

 case 'playlist':
    $playlist = $_GET['playlist'] ?? 'tous';
    $dir = $_GET['dir'] ?? '';
    $m3u = $_GET['m3u'] ?? '';
    
    // 1. On définit id_telnet TOUT DE SUITE
    $id_telnet = ($playlist == "onair" || $playlist == "tous") ? "tous" : $playlist;

    $cleanList = []; 
    if (!empty($dir) && !empty($m3u)) {
        $files = shell_exec('find ' . escapeshellarg($dir) . ' -type f -name "*.mp3"');
        $fileList = explode("\n", trim($files));

        foreach ($fileList as $filePath) {
            if (empty($filePath)) continue;
            $check = shell_exec("ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 " . escapeshellarg($filePath));
            if (is_numeric(trim($check))) {
                $cleanList[] = $filePath;
            }
        }
        file_put_contents($m3u, implode("\n", $cleanList));
    }

    // --- LES ORDRES À LIQUIDSOAP ---
    // On utilise maintenant $id_telnet qui est bien défini
    fwrite($fp, "choix_playlist.set $playlist\n");
    usleep(100000);

    fwrite($fp, $id_telnet . ".reload\n");  // Ligne 94 corrigée
    usleep(200000);

    fwrite($fp, "radio.skip\n");            // Ligne 96 corrigée (ou $id_telnet.skip)
    
    $response_text = "✅ Playlist '" . ucfirst($playlist) . "' mise à jour (" . count($cleanList) . " titres)";
    break;
    
    //case 'queue':
        //header('Content-Type: application/json');
        //$current = get_telnet_val($fp, "choix_playlist.get");
        //$id_telnet = ($current == "onair" || $current == "tous" || empty($current)) ? "tous" : $current;

        //fwrite($fp, "$id_telnet.next\n");
        //$next_song = "";
        //while ($line = fgets($fp, 512)) {
            //$line = trim($line);
            //if ($line == "END") break;
            //if ($line != "" && $line != '""') $next_song = basename($line);
        //}
        //echo json_encode(["message" => $next_song ?: "Aucun titre suivant"]);
        //exit;
        
    case 'queue':
        header('Content-Type: application/json');
        
        // 1. On demande à Liquidsoap qui est l'animateur en cours
        $current = get_telnet_val($fp, "choix_playlist.get");
        
        // 2. On traduit cet animateur en ID de playlist technique
        // On force 'tous' si c'est vide ou si c'est 'onair'
        if (empty($current) || $current == "onair" || $current == "tous") {
            $id_telnet = "tous";
        } else {
            $id_telnet = $current;
        }
    
        // 3. On demande le prochain titre à la BONNE playlist
        fwrite($fp, "$id_telnet.next\n");
        
        $next_song = "";
        while ($line = fgets($fp, 512)) {
            $line = trim($line);
            if ($line == "END") break;
            // On ignore les messages d'erreur et les chaînes vides
            if ($line != "" && $line != '""' && !str_contains($line, "ERROR")) {
                $next_song = basename($line);
            }
        }
    
        // 4. Si c'est toujours vide, on met un message propre
        if (empty($next_song)) $next_song = "Recherche du titre...";
    
        echo json_encode(["message" => $next_song]);
        exit;
}

echo $response_text;
fclose($fp);