<?php
header("Content-Type: application/json");
$file = 'planning.json';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $data = json_decode(file_get_contents('php://input'), true);
    if ($data) {
        file_put_contents($file, json_encode($data, JSON_PRETTY_PRINT));
        echo json_encode(["status" => "success"]);
    }
    exit;
}

echo file_get_contents($file);