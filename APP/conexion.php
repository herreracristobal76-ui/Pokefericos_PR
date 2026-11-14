<?php
function conectar() {
    $cfg = require __DIR__ . '/config_local.php';
    $conn = oci_connect($cfg['usuario'], $cfg['clave'], $cfg['cadena'], 'AL32UTF8');
    if (!$conn) {
        $e = oci_error();
        die('Error de conexion: ' . htmlspecialchars($e['message']));
    }
    return $conn;
}