<?php
// Mantenedor generico: mantenedor.php?e=<nombre>  (ver config_mantenedores.php)
session_start();
require 'conexion.php';
$cfg = require 'config_mantenedores.php';

$e = $_GET['e'] ?? '';
if (!isset($cfg[$e])) { die('Mantenedor no existe'); }
$c = $cfg[$e];

if (!isset($_SESSION['usuario'])) { header('Location: login.php'); exit; }
$editar = in_array($_SESSION['rol'], $c['roles']);
$ver    = $editar || in_array($_SESSION['rol'], $c['ver']);
if (!$ver) {
    http_response_code(403);
    die('Sin permiso para esta sección. <a href="panel.php">Volver al panel</a>');
}
$conn = conectar();
$msg = '';
$ok  = true;

// Ejecuta y devuelve el mensaje limpio de Oracle, o null si salio bien
function ejecutar($st) {
    if (!@oci_execute($st)) {
        $er = oci_error($st);
        $linea = strtok($er['message'], "\n");
        return preg_replace('/^ORA-\d+:\s*/', '', $linea);
    }
    return null;
}

// Llama a un procedimiento con parametros IN (en orden) y un OUT numerico opcional
function llamar($conn, $proc, array $valores, $conOut = false) {
    $marcas = [];
    foreach ($valores as $i => $v) { $marcas[] = ':p' . $i; }
    if ($conOut) { $marcas[] = ':pout'; }
    $st = oci_parse($conn, 'BEGIN ' . $proc . '(' . implode(', ', $marcas) . '); END;');
    foreach ($valores as $i => $v) {
        oci_bind_by_name($st, ':p' . $i, $valores[$i]);
    }
    if ($conOut) { oci_bind_by_name($st, ':pout', $salida, 20); }
    return ejecutar($st);
}

function listar($conn, $proc) {
    $cur = oci_new_cursor($conn);
    $st = oci_parse($conn, 'BEGIN ' . $proc . '(:c); END;');
    oci_bind_by_name($st, ':c', $cur, -1, OCI_B_CURSOR);
    oci_execute($st);
    oci_execute($cur);
    oci_fetch_all($cur, $filas, 0, -1, OCI_FETCHSTATEMENT_BY_ROW);
    return $filas;
}

// Valor del formulario (vacio -> NULL si el campo lo permite)
function valorCampo($f, $post) {
    $v = trim($post[$f['col']] ?? '');
    if ($v === '' && $f['null']) { return null; }
    if ($f['kind'] === 'decimal') { $v = str_replace(',', '.', $v); }
    if ($f['kind'] === 'horario') {
        // Dos campos de hora (inicio y fin) -> "HH:MM-HH:MM"
        $ini = trim($post[$f['col'] . '_ini'] ?? '');
        $fin = trim($post[$f['col'] . '_fin'] ?? '');
        $v = ($ini !== '' && $fin !== '') ? substr($ini, 0, 5) . '-' . substr($fin, 0, 5) : '';
    }
    return $v;
}

// ---------- Acciones ----------
if ($editar && $_SERVER['REQUEST_METHOD'] === 'POST') {
    $accion = $_POST['accion'] ?? '';
    $pk = trim($_POST['pk'] ?? '');

    if ($accion === 'crear') {
        $vals = [];
        if (!$c['auto']) { $vals[] = $pk; }
        foreach ($c['campos'] as $f) {
            if (!$f['ins']) continue;
            if ($f['kind'] === 'password') {
                $plano = $_POST[$f['col']] ?? '';
                $vals[] = $plano === '' ? '' : password_hash($plano, PASSWORD_DEFAULT);
            } else {
                $vals[] = valorCampo($f, $_POST);
            }
        }
        $err = llamar($conn, $c['sp'] . '_INSERTAR', $vals, $c['auto']);
        $msg = $err ?? 'Registro creado'; $ok = $err === null;

    } elseif ($accion === 'actualizar') {
        $vals = [$pk];
        foreach ($c['campos'] as $f) {
            if ($f['upd']) { $vals[] = valorCampo($f, $_POST); }
        }
        $err = llamar($conn, $c['sp'] . '_ACTUALIZAR', $vals);
        // Usuario: cambio opcional de contraseña
        if ($err === null && $e === 'usuario' && ($_POST['Password_Hash'] ?? '') !== '') {
            $err = llamar($conn, 'PR_SP_USUARIO_CAMBIAR_CLAVE',
                          [$pk, password_hash($_POST['Password_Hash'], PASSWORD_DEFAULT)]);
        }
        $msg = $err ?? 'Registro actualizado'; $ok = $err === null;

    } elseif ($accion === 'eliminar') {
        $err = llamar($conn, $c['sp'] . '_ELIMINAR', [$pk]);
        $msg = $err ?? 'Registro eliminado'; $ok = $err === null;
    }
}

// ---------- Datos para mostrar ----------
$filas = listar($conn, $c['sp'] . '_LISTAR');

// Listas de las tablas relacionadas (para los desplegables)
// Texto que se muestra para un registro: usa la 'etiqueta' de la config
// ({COLUMNA} se reemplaza por su valor; si la columna es clave foranea,
// se muestra el nombre del registro relacionado, ej. la bodega).
function etiquetas($conn, $cfg, $nombre) {
    $p = $cfg[$nombre];
    $sub = [];
    foreach ($p['campos'] as $f) {
        if ($f['kind'] === 'fk') {
            $q = $cfg[$f['fk']];
            foreach (listar($conn, $q['sp'] . '_LISTAR') as $fila) {
                $vals = $fila; unset($vals[strtoupper($q['pk'])]);
                $sub[strtoupper($f['col'])][$fila[strtoupper($q['pk'])]] = (string)reset($vals);
            }
        }
    }
    $mapa = [];
    foreach (listar($conn, $p['sp'] . '_LISTAR') as $fila) {
        $id = $fila[strtoupper($p['pk'])];
        if (!empty($p['etiqueta'])) {
            $txt = preg_replace_callback('/\{(\w+)\}/', function ($m) use ($fila, $sub) {
                $v = $fila[$m[1]] ?? '';
                return $sub[$m[1]][$v] ?? $v;
            }, $p['etiqueta']);
        } else {
            $vals = $fila; unset($vals[strtoupper($p['pk'])]);
            $txt = implode(' ', $vals);
        }
        $mapa[$id] = $txt;
    }
    return $mapa;
}

$opciones = [];
foreach ($c['campos'] as $f) {
    if ($f['kind'] === 'fk') { $opciones[$f['col']] = etiquetas($conn, $cfg, $f['fk']); }
}

function h($s) { return htmlspecialchars((string)$s); }

function campoHtml($f, $valor, $opciones, $requerido = true, $form = '') {
    $n = h($f['col']);
    $fa = $form !== '' ? ' form="' . h($form) . '"' : '';
    switch ($f['kind']) {
        case 'fk':
            $o = '<select name="' . $n . '"' . $fa . ($f['null'] ? '' : ' required') . '>';
            if ($f['null']) { $o .= '<option value="">(ninguno)</option>'; }
            elseif ($valor === null) { $o .= '<option value="">Seleccione</option>'; }
            foreach ($opciones[$f['col']] as $id => $txt) {
                $sel = ((string)$id === (string)$valor) ? ' selected' : '';
                $o .= '<option value="' . h($id) . '"' . $sel . '>' . h($txt) . '</option>';
            }
            return $o . '</select>';
        case 'sn':
            $v = $valor ?? 'S';
            return '<select name="' . $n . '"' . $fa . '><option value="S"' . ($v === 'S' ? ' selected' : '') .
                   '>S (activo)</option><option value="N"' . ($v === 'N' ? ' selected' : '') . '>N (inactivo)</option></select>';
        case 'horario':
            $partes = explode('-', (string)$valor);
            return 'de <input type="time" name="' . $n . '_ini"' . $fa . ' value="' . h($partes[0] ?? '') . '" required>' .
                   ' a <input type="time" name="' . $n . '_fin"' . $fa . ' value="' . h($partes[1] ?? '') . '" required>';
        case 'number':
            return '<input type="text" inputmode="numeric" pattern="[0-9]+" title="Solo números enteros" size="8" ' .
                   'oninput="this.value=this.value.replace(/[^0-9]/g,\'\')" name="' . $n . '"' . $fa . ' value="' . h($valor) . '" required>';
        case 'decimal':
            return '<input type="text" inputmode="decimal" pattern="[0-9]+([.,][0-9]{1,2})?" title="Número, con hasta 2 decimales" size="10" ' .
                   'oninput="this.value=this.value.replace(/[^0-9.,]/g,\'\')" name="' . $n . '"' . $fa . ' value="' . h($valor) . '" required>';
        case 'password':
            return '<input type="password" name="' . $n . '"' . $fa . ' placeholder="' .
                   ($requerido ? '' : 'dejar vacío para no cambiar') . '"' . ($requerido ? ' required' : '') . '>';
        default:
            return '<input name="' . $n . '"' . $fa . ' value="' . h($valor) . '"' .
                   ($f['max'] ? ' maxlength="' . (int)$f['max'] . '"' : '') . ($f['null'] ? '' : ' required') . '>';
    }
}
?>
<!DOCTYPE html>
<html lang="es"><head><meta charset="UTF-8"><title><?= h($c['titulo']) ?></title>
<style>
 body{font-family:Arial,sans-serif;margin:20px}
 table{border-collapse:collapse} td,th{border:1px solid #999;padding:6px}
 .ok{color:green} .err{color:red}
</style></head>
<body>
  <h2><?= h($c['titulo']) ?></h2>
  <p><a href="panel.php">← Volver al panel</a></p>
  <?php if ($msg): ?><p class="<?= $ok ? 'ok' : 'err' ?>"><b><?= h($msg) ?></b></p><?php endif; ?>

  <?php if ($editar): ?>
  <h3>Nuevo registro</h3>
  <form method="post">
    <input type="hidden" name="accion" value="crear">
    <?php if (!$c['auto']): ?>
      <?= h($c['pk']) ?>: <input name="pk" required maxlength="12"> &nbsp;
    <?php endif; ?>
    <?php foreach ($c['campos'] as $f): if (!$f['ins']) continue; ?>
      <?= h($f['label']) ?>: <?= campoHtml($f, null, $opciones) ?> &nbsp;
    <?php endforeach; ?>
    <button>Crear</button>
  </form>
  <br>
  <?php endif; ?>

  <table>
    <tr>
      <th><?= $c['auto'] ? 'ID' : h($c['pk']) ?></th>
      <?php foreach ($c['campos'] as $f): if (!$f['lst'] && !$f['upd'] && $f['kind'] !== 'password') continue; ?>
        <th><?= h($f['label']) ?></th>
      <?php endforeach; ?>
      <?php if ($editar): ?><th>Acciones</th><?php endif; ?>
    </tr>
    <?php foreach ($filas as $r): $id = $r[strtoupper($c['pk'])]; $fid = 'f' . md5((string)$id); ?>
    <tr>
      <td>
        <?php if ($editar): ?>
        <form id="<?= $fid ?>" method="post">
          <input type="hidden" name="accion" value="actualizar">
          <input type="hidden" name="pk" value="<?= h($id) ?>">
        </form>
        <?php endif; ?>
        <?= h($id) ?>
      </td>
      <?php foreach ($c['campos'] as $f): if (!$f['lst'] && !$f['upd'] && $f['kind'] !== 'password') continue; ?>
        <td>
        <?php if ($editar && ($f['upd'] || $f['kind'] === 'password')): ?>
          <?= campoHtml($f, $r[strtoupper($f['col'])] ?? null, $opciones, false, $fid) ?>
        <?php elseif ($f['kind'] === 'fk'): ?>
          <?= h($opciones[$f['col']][$r[strtoupper($f['col'])] ?? ''] ?? ($r[strtoupper($f['col'])] ?? '')) ?>
        <?php elseif ($f['kind'] !== 'password'): ?>
          <?= h($r[strtoupper($f['col'])] ?? '') ?>
        <?php endif; ?>
        </td>
      <?php endforeach; ?>
      <?php if ($editar): ?>
      <td>
        <button form="<?= $fid ?>">Guardar</button>
        <form method="post" style="display:inline" onsubmit="return confirm('¿Eliminar?')">
          <input type="hidden" name="accion" value="eliminar">
          <input type="hidden" name="pk" value="<?= h($id) ?>">
          <button>Eliminar</button>
        </form>
      </td>
      <?php endif; ?>
    </tr>
    <?php endforeach; ?>
  </table>
</body></html>