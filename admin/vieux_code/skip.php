<?php
// On autorise la page HTML à appeler ce script (CORS)
header("Access-Control-Allow-Origin: *");
header("Content-Type: text/plain");

// On ouvre la connexion Telnet vers Liquidsoap sur la machine locale
$fp = @fsockopen("127.0.0.1", 1234, $errno, $errstr, 5);

if (!$fp) {
    http_response_code(500);
    echo "Erreur : Impossible de joindre Liquidsoap sur le port 1234 ($errstr)";
} else {
    // On attend un tout petit peu que Liquidsoap affiche son message d'accueil
    usleep(100000); 
    
    // On envoie la commande avec un saut de ligne \n
    fwrite($fp, "tous.skip\n");
    
    // On récupère la réponse de Liquidsoap
    $response = fgets($fp, 128);
    
    // On quitte proprement
    fwrite($fp, "exit\n");
    fclose($fp);
    
    echo "OK : Passage au titre suivant réussi !";
}
?>