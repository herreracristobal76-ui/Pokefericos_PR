<?php
// Gestor de auditoria fisica (PR_Examina): el operario registra lo que conto
// en un estante y el sistema muestra la diferencia contra lo registrado.
session_start();
require 'conexion.php';
require 'funciones.php';
exigir_roles(['ADMINISTRADOR', 'SUPERVISOR', 'OPERARIO']);
$conn = conectar();

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $rut  = $_POST['rut_operario'] ?? '';
    $prod = $_POST['id_producto'] ?? '';
    $ubi  = $_POST['id_ubicacion'] ?? '';
    $cant = solo_digitos($_POST['cantidad'] ?? '');
    // Este procedimiento tiene dos parametros OUT, por eso se llama directo
    $st = oci_parse($conn, 'BEGIN PR_SP_REGISTRAR_EXAMEN(:rut, :prod, :ubi, :cant, :id, :dif); END;');
    oci_bind_by_name($st, ':rut', $rut);
    oci_bind_by_name($st, ':prod', $prod);
    oci_bind_by_name($st, ':ubi', $ubi);
    oci_bind_by_name($st, ':cant', $cant);
    oci_bind_by_name($st, ':id', $idExamen, 40);
    oci_bind_by_name($st, ':dif', $dif, 40);
    if (!@oci_execute($st)) {
        flash(db_error($st), false);
    } elseif ((int)$dif === 0) {
        flash("Revisión N° $idExamen registrada: el conteo coincide con el sistema.");
    } else {
        flash("Revisión N° $idExamen registrada: DIFERENCIA de " . ((int)$dif > 0 ? '+' : '') . (int)$dif .
              " unidades respecto del sistema. Revise el estante.", false);
    }
    header('Location: auditoria.php');
    exit;
}

$productos = mapa(db_listar($conn, 'PR_SP_PRODUCTO_LISTAR'), 'ID_PRODUCTO', fn($f) => $f['NOMBRE_PRODUCTO']);
$bodegas   = mapa(db_listar($conn, 'PR_SP_BODEGA_LISTAR'), 'ID_BODEGA', fn($f) => $f['NOMBRE_RECINTO']);
$ubicaciones = mapa(db_listar($conn, 'PR_SP_UBICACION_LISTAR'), 'ID_UBICACION',
    fn($f) => ($bodegas[$f['ID_BODEGA']] ?? 'Bodega ' . $f['ID_BODEGA']) . ' - Pasillo ' . $f['PASILLO'] . ', Nivel ' . $f['NIVEL']);
$operarios = mapa(db_listar($conn, 'PR_SP_OPERARIO_LISTAR'), 'RUT_OPERARIO',
    fn($f) => $f['NOMBRES'] . ' ' . $f['APELLIDOS'] . ' (' . $f['RUT_OPERARIO'] . ')');
$examenes = db_listar($conn, 'PR_SP_EXAMEN_LISTAR');
?>
<!DOCTYPE html>
<html lang="es"><head><meta charset="UTF-8"><title>Auditoría física</title>
<style><?= CSS_BASE ?> .dif{background:#fde2e2}</style></head>
<body>
  <h2>Auditoría física de estantes</h2>
  <p><a href="panel.php">← Volver al panel</a></p>
  <?php mostrar_flash(); ?>

  <div class="caja">
    <h3>Registrar conteo</h3>
    <form method="post">
      Operario: <select name="rut_operario" required><option value="">Seleccione</option><?= opciones($operarios) ?></select>
      Producto: <select name="id_producto" required><option value="">Seleccione</option><?= opciones($productos) ?></select>
      <br><br>
      Estante: <select name="id_ubicacion" required><option value="">Seleccione</option><?= opciones($ubicaciones) ?></select>
      Cantidad contada: <input name="cantidad" inputmode="numeric" pattern="[0-9]+" size="6" required
                               oninput="this.value=this.value.replace(/[^0-9]/g,'')">
      <button>Registrar</button>
    </form>
  </div>

  <h3>Últimas revisiones</h3>
  <table>
    <tr><th>N°</th><th>Fecha</th><th>Operario</th><th>Producto</th><th>Estante</th><th>Contado</th><th>Sistema hoy</th></tr>
    <?php foreach ($examenes as $e): $distinto = (int)$e['CANTIDAD_CONTADA'] !== (int)$e['CANTIDAD_ACTUAL_SISTEMA']; ?>
    <tr class="<?= $distinto ? 'dif' : '' ?>">
      <td><?= h($e['ID_EXAMEN']) ?></td>
      <td><?= h($e['FECHA']) ?></td>
      <td><?= h($operarios[$e['RUT_OPERARIO']] ?? $e['RUT_OPERARIO']) ?></td>
      <td><?= h($e['NOMBRE_PRODUCTO']) ?></td>
      <td><?= h($ubicaciones[$e['ID_UBICACION']] ?? $e['ID_UBICACION']) ?></td>
      <td class="num"><?= h($e['CANTIDAD_CONTADA']) ?></td>
      <td class="num"><?= h($e['CANTIDAD_ACTUAL_SISTEMA']) ?></td>
    </tr>
    <?php endforeach; ?>
    <?php if (!$examenes): ?><tr><td colspan="7">No hay revisiones.</td></tr><?php endif; ?>
  </table>
  <p><small>En rojo: el conteo no coincide con lo que el sistema tiene hoy en ese estante.</small></p>
</body></html>
