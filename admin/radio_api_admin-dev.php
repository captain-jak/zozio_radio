<?php
//-------------   script corrigé le 13.04.2026 ---------------
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

case 'playlist':
    $playlist = $_GET['playlist'] ?? 'tous';
    $dir = $_GET['dir'] ?? '';
    $m3u = $_GET['m3u'] ?? '';
    
    $cleanList = []; // Initialisation pour éviter l'erreur de count()
    if (!empty($dir) && !empty($m3u)) {
        $files = shell_exec('find ' . escapeshellarg($dir) . ' -type f -name "*.mp3"');
        $fileList = explode("\n", trim($files));

        foreach ($fileList as $filePath) {
            if (empty($filePath)) continue;
            // Contrôle de conformité rapide
            $check = shell_exec("ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 " . escapeshellarg($filePath));
            if (is_numeric(trim($check))) {
                $cleanList[] = $filePath;
            }
        }
        file_put_contents($m3u, implode("\n", $cleanList));
    }

    // --- LES ORDRES À LIQUIDSOAP ---
    // 1. On change la variable de l'animateur
    fwrite($fp, "choix_playlist.set $playlist\n");
    usleep(100000);

    // 2. IMPORTANT : On force la playlist concernée à relire son fichier M3U sur le disque
    // Si $playlist est 'onair', l'ID telnet est 'tous'
    $id_to_reload = ($playlist == "onair") ? "tous" : $playlist;
    fwrite($fp, $id_to_reload . ".reload\n"); 
    usleep(200000);

    // 3. On skip pour appliquer le changement immédiatement
    fwrite($fp, "radio.skip\n"); 
    
    $response_text = "✅ Playlist '" . ucfirst($playlist) . "' mise à jour (" . count($cleanList) . " titres)";
    break;
    
    case 'queue':
        header('Content-Type: application/json');
        $current = get_telnet_val($fp, "choix_playlist.get");
        $id_telnet = ($current == "onair" || $current == "tous" || empty($current)) ? "tous" : $current;

        fwrite($fp, "$id_telnet.next\n");
        $next_song = "";
        while ($line = fgets($fp, 512)) {
            $line = trim($line);
            if ($line == "END") break;
            if ($line != "" && $line != '""') $next_song = basename($line);
        }
        echo json_encode(["message" => $next_song ?: "Aucun titre suivant"]);
        exit;
}

echo $response_text;
fclose($fp);