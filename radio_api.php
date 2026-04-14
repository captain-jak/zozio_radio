<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=utf-8");

$fp = @fsockopen("127.0.0.1", 1234, $errno, $errstr, 2);
if (!$fp) {
    echo json_encode(["error" => "Liquidsoap injoignable"]);
    exit;
}

function query_ls($fp, $cmd) {
    fwrite($fp, $cmd . "\n");
    $data = [];
    while ($line = fgets($fp, 512)) {
        $line = trim($line);
        if ($line == "END") break;
        if ($line != "" && strpos($line, '---') === false) {
            $data[] = str_replace('"', '', $line);
        }
    }
    return $data;
}

// 1. On récupère l'animateur actuel
$auth_res = query_ls($fp, "choix_playlist.get");
$auth = (!empty($auth_res)) ? trim($auth_res[0]) : "tous";

// 2. Mapping FORCÉ selon ton résultat Telnet "help"
// playlist = tous, playlist.1 = guillaume, playlist.2 = jacques
$id_telnet = "playlist"; // par défaut
if ($auth == "guillaume") $id_telnet = "playlist.1";
if ($auth == "jacques")   $id_telnet = "playlist.2";

// 3. Récupérer le titre SUIVANT (via .remaining ou .next)
$next_res = query_ls($fp, $id_telnet . ".remaining");
$next_track = "Sélection en cours...";
if (!empty($next_res)) {
    $next_track = basename($next_res[0]);
}

// 4. Récupérer le titre ACTUEL (via metadata de la sortie)
$meta_res = query_ls($fp, "icecast_out.metadata");
$current_title = "Musique en cours...";
if (!empty($meta_res)) {
    foreach ($meta_res as $line) {
        if (strpos($line, 'title=') === 0) {
            $current_title = str_replace('title=', '', $line);
            break;
        }
    }
}

// 5. Fermeture et JSON
fwrite($fp, "quit\n");
fclose($fp);

echo json_encode([
    "animateur" => ucfirst($auth),
    "current"   => $current_title,
    "next"      => $next_track
], JSON_UNESCAPED_UNICODE);