<?php
// Funciones comunes para las pantallas de gestores y reportes

function h($s) { return htmlspecialchars((string)$s); }

// Exige sesion iniciada y uno de los roles indicados
function exigir_roles(array $roles) {
    if (!isset($_SESSION['usuario'])) { header('Location: login.php'); exit; }
    if (!in_array($_SESSION['rol'], $roles)) {
        http_response_code(403);
        die('Sin permiso para esta sección. <a href="panel.php">Volver al panel</a>');
    }
}

// Mensaje limpio del error de Oracle (primera linea, sin "ORA-xxxxx:")
function db_error($st) {
    $e = oci_error($st);
    $linea = strtok($e['message'], "\n");
    return preg_replace('/^ORA-\d+:\s*/', '', $linea);
}

// Llama un procedimiento: parametros IN en orden y, si $conOut, un OUT al final.
// Devuelve [error|null, valorOut|null]
function db_llamar($conn, $proc, array $in, $conOut = false) {
    $marcas = [];
    foreach ($in as $i => $v) { $marcas[] = ':p' . $i; }
    if ($conOut) { $marcas[] = ':pout'; }
    $st = oci_parse($conn, 'BEGIN ' . $proc . '(' . implode(', ', $marcas) . '); END;');
    foreach ($in as $i => $v) { oci_bind_by_name($st, ':p' . $i, $in[$i]); }
    $salida = null;
    if ($conOut) { oci_bind_by_name($st, ':pout', $salida, 40); }
    if (!@oci_execute($st)) { return [db_error($st), null]; }
    return [null, $salida];
}

// Llama un procedimiento cuyo ULTIMO parametro es un SYS_REFCURSOR y devuelve las filas
function db_listar($conn, $proc, array $in = []) {
    $marcas = [];
    foreach ($in as $i => $v) { $marcas[] = ':p' . $i; }
    $marcas[] = ':cur';
    $cur = oci_new_cursor($conn);
    $st = oci_parse($conn, 'BEGIN ' . $proc . '(' . implode(', ', $marcas) . '); END;');
    foreach ($in as $i => $v) { oci_bind_by_name($st, ':p' . $i, $in[$i]); }
    oci_bind_by_name($st, ':cur', $cur, -1, OCI_B_CURSOR);
    oci_execute($st);
    oci_execute($cur);
    $filas = [];
    oci_fetch_all($cur, $filas, 0, -1, OCI_FETCHSTATEMENT_BY_ROW);
    return $filas;
}

// Mensajes que sobreviven a la redireccion despues de un POST
function flash($texto, $ok = true) { $_SESSION['flash'] = [$texto, $ok]; }
function mostrar_flash() {
    if (empty($_SESSION['flash'])) return;
    [$t, $ok] = $_SESSION['flash'];
    unset($_SESSION['flash']);
    echo '<p class="' . ($ok ? 'ok' : 'err') . '"><b>' . h($t) . '</b></p>';
}

function solo_digitos($v) { return preg_replace('/\D/', '', (string)$v); }
function decimal($v) { return str_replace(',', '.', preg_replace('/[^0-9.,]/', '', (string)$v)); }
function dinero($v) { return '$' . number_format((float)$v, 0, ',', '.'); }

// Convierte filas en [id => texto]
function mapa(array $filas, $colId, callable $texto) {
    $m = [];
    foreach ($filas as $f) { $m[$f[$colId]] = $texto($f); }
    return $m;
}

function opciones(array $mapa, $seleccion = null) {
    $o = '';
    foreach ($mapa as $id => $txt) {
        $sel = ((string)$id === (string)$seleccion) ? ' selected' : '';
        $o .= '<option value="' . h($id) . '"' . $sel . '>' . h($txt) . '</option>';
    }
    return $o;
}

const CSS_BASE = 'body{font-family:Arial,sans-serif;margin:20px}
table{border-collapse:collapse;margin:8px 0} td,th{border:1px solid #999;padding:6px}
th{background:#eee} .ok{color:green} .err{color:red} .num{text-align:right}
.caja{border:1px solid #ccc;padding:10px;margin:10px 0;border-radius:6px}';
