<?php
function conectar() {
    $cfg = file_exists(__DIR__ . '/config_local.php')
         ? require __DIR__ . '/config_local.php'
         : ['usuario' => 'inventario', 'clave' => 'Cristobal_200503', 'cadena' => 'DESKTOP-DTBT03T:1521/XEPDB1'];
    $conn = oci_connect($cfg['usuario'], $cfg['clave'], $cfg['cadena'], 'AL32UTF8');
    if (!$conn) {
        $e = oci_error();
        die('Error de conexion: ' . htmlspecialchars($e['message']));
    }
    // Punto como separador decimal, sin importar la configuracion regional de Windows
    $st = oci_parse($conn, "ALTER SESSION SET NLS_NUMERIC_CHARACTERS = '.,'");
    oci_execute($st);
    return $conn;
}