<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=utf-8");

$fp = @fsockopen("127.0.0.1", 1234, $errno, $errstr, 2);
if (!$fp) {
    echo json_encode(["error" => "Liquidsoap injoignable"]);
    exit;
}

function get_ls_array($fp, $cmd) {
    fwrite($fp, $cmd . "\n");
    $lines = [];
    while ($line = fgets($fp, 512)) {
        $line = trim($line);
        if ($line == "END") break;
        if ($line != "" && strpos($line, '---') === false) {
            $lines[] = str_replace('"', '', $line);
        }
    }
    return $lines;
}

// 1. Déterminer l'animateur
$auth_res = get_ls_array($fp, "choix_playlist.get");
$auth = (!empty($auth_res)) ? trim($auth_res[0]) : "tous";

// 2. Mapping EXACT des IDs (doit correspondre à id="xxxx" dans ton .liq)
$id = "playlist"; 
if ($auth == "guillaume") $id = "guillaume"; // ID mis à jour selon ton message précédent
if ($auth == "jacques") $id = "jacques";

// 3. Récupérer le titre SUIVANT réel
// .remaining renvoie la liste des titres en attente. Le premier est le VRAI prochain.
$remaining = get_ls_array($fp, $id . ".remaining");
$next_track = (!empty($remaining)) ? basename($remaining[0]) : "Sélection en cours";

// 4. Récupérer le titre PRÉCÉDENT
// Si .last ne marche pas sur la playlist, on interroge l'historique de la sortie Icecast
$history = get_ls_array($fp, "radio.history"); // Remplace 'radio' par l'ID de ta sortie (ex: output_icecast)
// Souvent l'historique est une liste, le 2ème élément est le titre précédent (le 1er étant l'actuel)
$last_track = (count($history) >= 2) ? basename($history[1]) : "---";

echo json_encode([
    "playlist" => $auth,
    "next" => $next_track,
    "last" => $last_track
], JSON_UNESCAPED_UNICODE);

fwrite($fp, "exit\n");
fclose($fp);