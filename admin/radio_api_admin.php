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

switch ($action) {
case 'skip':
    // On utilise l'ID qui a fonctionné en Telnet
    fwrite($fp, "icecast_out.skip\n");
    $res = fgets($fp, 512); // Pour lire le "Done"
    $response_text = "⏭ Passage au titre suivant effectué";
    break;
    case 'jingle':
        if (!empty($file)) {
            // Utilisation de guillemets pour gérer les espaces dans le chemin
            fwrite($fp, 'jingles.push "' . $file . "\"\n");
            // On lit la réponse pour vider le buffer telnet
            $res = fgets($fp, 512); 
            $response_text = "Jingle envoyé !";
        }
        break;

    case 'playlist':
        $playlist = isset($_GET['playlist']) ? $_GET['playlist'] : 'tous';
        $dir = isset($_GET['dir']) ? $_GET['dir'] : '';
        $m3u = isset($_GET['m3u']) ? $_GET['m3u'] : '';
        
        if (!empty($dir) && !empty($m3u)) {
            exec('find ' . escapeshellarg($dir) . ' -type f -name "*.mp3" > ' . escapeshellarg($m3u));
        }

        fwrite($fp, "choix_playlist.set " . $playlist . "\n");
        usleep(100000);
        fwrite($fp, "radio.skip\n"); // Basculement immédiat
        $response_text = "Animateur changé : " . ucfirst($playlist);
        break;

case 'reload':
        // 1. On demande à Liquidsoap qui est l'animateur actuel
        $current = get_telnet_val($fp, "choix_playlist.get");
        
        // 2. Traduction : Liquidsoap connaît l'ID "tous", pas "onair"
        $id = "tous"; 
        if ($current == "guillaume") $id = "guillaume";
        if ($current == "jacques") $id = "jacques";
        
        // 3. Envoi de l'ordre de rechargement
        fwrite($fp, $id . ".reload\n");
        
        // 4. Réponse propre pour le JavaScript
        header('Content-Type: application/json');
        echo json_encode(["message" => "Playlist $id mise à jour sur le serveur !"]);
        
        fwrite($fp, "quit\n");
        fclose($fp);
        exit;
        
    case 'queue':
        // Nettoyage radical de la sortie pour éviter toute pollution du JSON
        if (ob_get_length()) ob_clean();
        
        // 1. On récupère l'animateur actuel
        $current = get_telnet_val($fp, "choix_playlist.get");
        $id_telnet = ($current == "onair" || $current == "tous" || empty($current)) ? "tous" : $current;

        // 2. On demande le prochain titre à la playlist active
        fwrite($fp, $id_telnet . ".next\n");
        $next_song = "";
        while ($line = fgets($fp, 512)) {
            $line = trim($line);
            if ($line == "END") break;
            if