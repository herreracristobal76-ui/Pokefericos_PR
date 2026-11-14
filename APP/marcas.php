<?php
session_start();
require 'conexion.php';
if (!isset($_SESSION['usuario']) ||
    !in_array($_SESSION['rol'], ['ADMINISTRADOR', 'SUPERVISOR'])) {
    header('Location: login.php'); exit;
}
$conn = conectar();
$msg = '';

// Devuelve el mensaje limpio del error de Oracle, o null si todo salió bien
function ejecutar($st) {
    if (!@oci_execute($st)) {
        $e = oci_error($st);
        $linea = strtok($e['message'], "\n");
        return preg_replace('/^ORA-\d+:\s*/', '', $linea);
    }
    return null;
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $accion = $_POST['accion'] ?? '';
    if ($accion === 'crear') {
        $st = oci_parse($conn, 'BEGIN PR_SP_MARCA_INSERTAR(:n, :id); END;');
        oci_bind_by_name($st, ':n', $_POST['nombre']);
        oci_bind_by_name($st, ':id', $nuevo, 20);
        $msg = ejecutar($st) ?? 'Marca creada';
    } elseif ($accion === 'actualizar') {
        $st = oci_parse($conn, 'BEGIN PR_SP_MARCA_ACTUALIZAR(:id, :n); END;');
        oci_bind_by_name($st, ':id', $_POST['id']);
        oci_bind_by_name($st, ':n', $_POST['nombre']);
        $msg = ejecutar($st) ?? 'Marca actualizada';
    } elseif ($accion === 'eliminar') {
        $st = oci_parse($conn, 'BEGIN PR_SP_MARCA_ELIMINAR(:id); END;');
        oci_bind_by_name($st, ':id', $_POST['id']);
        $msg = ejecutar($st) ?? 'Marca eliminada';
    }
}

// Lectura con cursor
$cur = oci_new_cursor($conn);
$st = oci_parse($conn, 'BEGIN PR_SP_MARCA_LISTAR(:c); END;');
oci_bind_by_name($st, ':c', $cur, -1, OCI_B_CURSOR);
oci_execute($st);
oci_execute($cur);
?>
<!DOCTYPE html>
<html lang="es"><head><meta charset="UTF-8"><title>Marcas</title></head>
<body>
  <h2>Marcas</h2>
  <p><a href="panel.php">← Volver al panel</a></p>
  <?php if ($msg) echo '<p><b>' . htmlspecialchars($msg) . '</b></p>'; ?>

  <form method="post">
    <input type="hidden" name="accion" value="crear">
    Nueva marca: <input name="nombre" required maxlength="50">
    <button>Crear</button>
  </form>
  <br>
  <table border="1" cellpadding="6">
    <tr><th>ID</th><th>Nombre</th><th>Acciones</th></tr>
    <?php while ($r = oci_fetch_assoc($cur)): ?>
    <tr>
      <td><?= $r['ID_MARCA'] ?></td>
      <td>
        <form method="post" style="display:inline">
          <input type="hidden" name="accion" value="actualizar">
          <input type="hidden" name="id" value="<?= $r['ID_MARCA'] ?>">
          <input name="nombre" value="<?= htmlspecialchars($r['NOMBRE_MARCA']) ?>" maxlength="50">
          <button>Guardar</button>
        </form>
      </td>
      <td>
        <form method="post" style="display:inline" onsubmit="return confirm('¿Eliminar?')">
          <input type="hidden" name="accion" value="eliminar">
          <input type="hidden" name="id" value="<?= $r['ID_MARCA'] ?>">
          <button>Eliminar</button>
        </form>
      </td>
    </tr>
    <?php endwhile; ?>
  </table>
</body></html>