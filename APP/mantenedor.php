<?php
// Mantenedor generico: mantenedor.php?e=<nombre>  (ver config_mantenedores.php)
session_start();
require 'conexion.php';
$cfg = require 'config_mantenedores.php';

$e = $_GET['e'] ?? '';
if (!isset($cfg[$e])) { die('Mantenedor no existe'); }
$c = $cfg[$e];

if (!isset($_SESSION['usuario']) || !in_array($_SESSION['rol'], $c['roles'])) {
    header('Location: login.php'); exit;
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
    return $v;
}

// ---------- Acciones ----------
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
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
$opciones = [];
foreach ($c['campos'] as $f) {
    if ($f['kind'] !== 'fk') continue;
    $p = $cfg[$f['fk']];
    $mapa = [];
    foreach (listar($conn, $p['sp'] . '_LISTAR') as $fila) {
        $id = $fila[strtoupper($p['pk'])];
        $partes = [];
        foreach ($fila as $col => $val) {
            if ($col !== strtoupper($p['pk'])) { $partes[] = $val; }
        }
        $mapa[$id] = ($p['auto'] ? '' : $id . ' - ') . implode(' ', $partes);
    }
    $opciones[$f['col']] = $mapa;
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
        case 'number':
            return '<input type="number" name="' . $n . '"' . $fa . ' value="' . h($valor) . '" required>';
        case 'decimal':
            return '<input type="number" step="0.01" min="0" name="' . $n . '"' . $fa . ' value="' . h($valor) . '" required>';
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

  <table>
    <tr>
      <th><?= $c['auto'] ? 'ID' : h($c['pk']) ?></th>
      <?php foreach ($c['campos'] as $f): if (!$f['lst'] && !$f['upd'] && $f['kind'] !== 'password') continue; ?>
        <th><?= h($f['label']) ?></th>
      <?php endforeach; ?>
      <th>Acciones</th>
    </tr>
    <?php foreach ($filas as $r): $id = $r[strtoupper($c['pk'])]; $fid = 'f' . md5((string)$id); ?>
    <tr>
      <td>
        <form id="<?= $fid ?>" method="post">
          <input type="hidden" name="accion" value="actualizar">
          <input type="hidden" name="pk" value="<?= h($id) ?>">
        </form>
        <?= h($id) ?>
      </td>
      <?php foreach ($c['campos'] as $f): if (!$f['lst'] && !$f['upd'] && $f['kind'] !== 'password') continue; ?>
        <td>
        <?php if ($f['upd'] || $f['kind'] === 'password'): ?>
          <?= campoHtml($f, $r[strtoupper($f['col'])] ?? null, $opciones, false, $fid) ?>
        <?php else: ?>
          <?= h($r[strtoupper($f['col'])] ?? '') ?>
        <?php endif; ?>
        </td>
      <?php endforeach; ?>
      <td>
        <button form="<?= $fid ?>">Guardar</button>
        <form method="post" style="display:inline" onsubmit="return confirm('¿Eliminar?')">
          <input type="hidden" name="accion" value="eliminar">
          <input type="hidden" name="pk" value="<?= h($id) ?>">
          <button>Eliminar</button>
        </form>
      </td>
    </tr>
    <?php endforeach; ?>
  </table>
</body></html>