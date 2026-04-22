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

    // 1. Récupére ID de la playlist (tableau)
    $id_raw = query_clean($fp, "choix_playlist.get");
    // 2. On extrait la première ligne du tableau et on nettoie (on enlève les guillemets)
    $id = !empty($id_raw) ? trim(str_replace('"', '', $id_raw[0])) : "tous";
    // 3. On s'assure que l'ID n'est pas "END" ou vide, sinon on met "tous" par défaut
    if ($id == "END" || empty($id)) {
        $id = "tous";
    }

    // 2. Récupére animateur de la playlist
    $auth_data  = query_clean($fp, "choix_playlist.get_name");
    $auth = !empty($auth_data) ? str_replace('"', '', $auth_data[0]) : "tous";
    $res["animateur"] = ucfirst($auth);

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
    //------4. Titre Suivant------------ --------------------------------------------------------------------------------
    $next_data = query_clean($fp, $id . ".next");
    if (!empty($next_data)) {
        foreach ($next_data as $line) {
            $line = trim($line);
            // On ignore les lignes vides ou les simples IDs numériques
            if (empty($line) || is_numeric($line) || $line == "END") continue;
            // On nettoie les résidus de Liquidsoap (guillemets, crochets, préfixes)
            $clean_line = str_replace(['"', '[', ']', '[ready] '], '', $line);
            // Si la ligne contient un slash ou .mp3, c'est notre fichier !
            if (strpos($clean_line, '/') !== false || stripos($clean_line, '.mp3') !== false) {
                $filename = basename($clean_line);
                // Nettoyage final du nom
                $filename = str_ireplace(['.mp3', '.wav', '_'], ['', '', ' '], $filename);
                $res["next"] = str_replace("::", " - ", $filename);
                break; // On a trouvé le titre, on arrête la boucle
            }
        }
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