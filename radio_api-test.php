<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=utf-8");

// Initialisation par défaut
$res = [
    "animateur" => "tous",
    "current"   => "Musique en cours...",
    "next"      => "Sélection...",
    "last"      => "---"
];

$fp = @fsockopen("127.0.0.1", 1234, $errno, $errstr, 2);

if ($fp) {
    function query_clean($fp, $cmd) {
        fwrite($fp, $cmd . "\n");
        $data = [];
        while ($line = fgets($fp, 512)) {
            $line = trim($line);
            if ($line == "END") break;
            if ($line != "" && !str_contains($line, '---') && !str_contains($line, 'ERROR')) {
                $data[] = $line;
            }
        }
        return $data;
    }

    // 1. Récupérer l'animateur
    $auth_data = query_clean($fp, "choix_playlist.get");
    $auth = !empty($auth_data) ? str_replace('"', '', $auth_data[0]) : "tous";
    $res["animateur"] = ucfirst($auth);

    // 2. Déterminer l'ID pour le titre suivant
    $id = "playlist";
    if (strtolower($auth) == "guillaume") $id = "playlist.1";
    if (strtolower($auth) == "jacques")   $id = "playlist.2";

//// --- 3. Titre Actuel (Artiste + Titre) ---
    //$meta = query_clean($fp, "icecast_out.metadata");
    //$artist = "";
    //$title = "";
    
    
    // --- 3. Titre Actuel (Artiste + Titre) ---
    $meta = query_clean($fp, "icecast_out.metadata");
    $artist = ""; $title = "";
    foreach($meta as $l) {
        $l = str_replace('"', '', $l);
        if (str_starts_with($l, 'artist=')) $artist = str_replace('artist=', '', $l);
        if (str_starts_with($l, 'title='))  $title = str_replace('title=', '', $l);
    }
    
    if (!empty($artist) && !empty($title)) {
        $res["current"] = $artist . " - " . str_replace("::", " - ", $title);
    } else {
        $res["current"] = str_replace("::", " - ", $title);
    }

    // --- 4. Titre Suivant ---
    $next_data = query_clean($fp, $id . ".next");
    if (!empty($next_data)) {
        $line = str_replace("[ready] ", "", $next_data[0]);
        $filename = basename(str_replace(['"', '.mp3', '.MP3'], '', $line));
        $res["next"] = str_replace("::", " - ", $filename);
    }

    // --- 5. Titre Précédent (Nouvelle commande !) ---
    $prev_data = query_clean($fp, "radio.last");
    if (!empty($prev_data)) {
        $res["last"] = str_replace("::", " - ", $prev_data[0]);
    }

    foreach($meta as $l) {
        // On nettoie la ligne des guillemets
        $l = str_replace('"', '', $l);
        
        if (str_starts_with($l, 'artist=')) {
            $artist = str_replace('artist=', '', $l);
        }
        if (str_starts_with($l, 'title=')) {
            $title = str_replace('title=', '', $l);
        }
    }

    // Si on a les deux, on assemble. 
    // Si le titre contient déjà "::", on le nettoie aussi.
    if (!empty($artist) && !empty($title)) {
        $res["current"] = $artist . " - " . str_replace("::", " - ", $title);
    } elseif (!empty($title)) {
        // Si on n'a que le titre mais qu'il contient l'artiste avec "::"
        $res["current"] = str_replace("::", " - ", $title);
    } else {
        $res["current"] = "Musique en cours...";
    }
// --- 4. Titre Suivant (Découpage Artiste / Titre) ---
    $next_data = query_clean($fp, $id . ".next");
    if (!empty($next_data)) {
        $line = str_replace("[ready] ", "", $next_data[0]);
        $filename = basename(str_replace('"', '', $line)); // Ex: "Susheela Raman::Trust in Me.mp3"
        
        // On enlève le .mp3
        $filename = str_replace(['.mp3', '.MP3'], '', $filename);
        
        // On remplace les double-deux-points par un séparateur plus propre
        $res["next"] = str_replace("::", " - ", $filename);
    }
    fclose($fp);
}

echo json_encode($res, JSON_UNESCAPED_UNICODE);