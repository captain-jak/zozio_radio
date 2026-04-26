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
        // On skip la sortie finale pour être immédiat
        fwrite($fp, "icecast_out.skip\n");
        echo "⏭ Passage au titre suivant";
        break;
    case 'jingle':
        if (!empty($file)) {
            // Utilisation du namespace défini dans le .liq
            fwrite($fp, "jingles.push $file\n");
            echo "📢 Jingle lancé : " . basename($file);
        }
        break;
    case 'playlist':
        $playlist = $_GET['playlist'] ?? 'tous';
        $dir = $_GET['dir'] ?? '';
        $m3u = $_GET['m3u'] ?? '';
    
        // TRÈS IMPORTANT : Mapping pour faire le lien avec le .liq
        $id_telnet = "tous";
        if ($playlist == "jacques") $id_telnet = "anime1";
        if ($playlist == "guillaume") $id_telnet = "anime1";
        if ($playlist == "tosha") $id_telnet = "anime1";
        
        // ... (Logique de génération M3U via find/ffprobe inchangée)
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
        // memorisation du nom de l'animateur:
        fwrite($fp, "choix_playlist.set_name $playlist\n");
        usleep(100000);
        // On utilise maintenant $id_telnet qui est bien défini
        fwrite($fp, "choix_playlist.set $id_telnet\n");
        usleep(100000);
        // On recharge la playlist physique
        fwrite($fp, $id_telnet . ".reload\n");  
        usleep(200000);
        // On force le passage au premier titre de la nouvelle playlist
        fwrite($fp, "radio.skip\n"); 
    
        $response_text = "✅ Playlist '" . ucfirst($playlist) . "' mise à jour (" . count($cleanList) . " titres)";
        break;
    case 'queue':
        header('Content-Type: application/json');
        // 1. On demande à Liquidsoap qui est l'animateur en cours
        $current = get_telnet_val($fp, "choix_playlist.get");
    
        // On demande le titre suivant à la playlist active
        fwrite($fp, "$current.next\n");
    
        $next_song = "";
        while ($line = fgets($fp, 512)) {
            $line = trim($line);
            if ($line == "END") break;
            if (!empty($line) && strpos($line, '/') !== false) {
                // Nettoyage : On enlève le chemin et l'extension
                $next_song = basename($line);
                $next_song = str_replace(['.mp3', '_', '::'], ['', ' ', ' - '], $next_song);
                break;
            }
        }
        echo json_encode(["message" => $next_song ?: "Titres suivants en cours de préparation..."]);
        exit;
}



echo $response_text;
fclose($fp);