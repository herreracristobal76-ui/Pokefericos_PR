<?php
// Gestor de movimientos de stock: registrar ENTRADA / SALIDA y ver los ultimos 100
session_start();
require 'conexion.php';
require 'funciones.php';
exigir_roles(['ADMINISTRADOR', 'SUPERVISOR', 'OPERARIO']);
$conn = conectar();

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    [$err, $id] = db_llamar($conn, 'PR_SP_REGISTRAR_MOVIMIENTO', [
        $_POST['tipo'] ?? '',
        solo_digitos($_POST['cantidad'] ?? ''),
        $_POST['id_producto'] ?? '',
        $_POST['id_ubicacion'] ?? '',
        $_POST['rut_operario'] ?? '',
        null                              // Nro_Orden: solo lo usa la recepcion de ordenes
    ], true);
    flash($err ?? "Movimiento N° $id registrado. El stock del estante fue actualizado.", $err === null);
    header('Location: movimientos.php');
    exit;
}

$productos = mapa(db_listar($conn, 'PR_SP_PRODUCTO_LISTAR'), 'ID_PRODUCTO', fn($f) => $f['NOMBRE_PRODUCTO']);
$bodegas   = mapa(db_listar($conn, 'PR_SP_BODEGA_LISTAR'), 'ID_BODEGA', fn($f) => $f['NOMBRE_RECINTO']);
$ubicaciones = mapa(db_listar($conn, 'PR_SP_UBICACION_LISTAR'), 'ID_UBICACION',
    fn($f) => ($bodegas[$f['ID_BODEGA']] ?? 'Bodega ' . $f['ID_BODEGA']) . ' - Pasillo ' . $f['PASILLO'] . ', Nivel ' . $f['NIVEL']);
$operarios = mapa(db_listar($conn, 'PR_SP_OPERARIO_LISTAR'), 'RUT_OPERARIO',
    fn($f) => $f['NOMBRES'] . ' ' . $f['APELLIDOS'] . ' (' . $f['RUT_OPERARIO'] . ')');
$movs = db_listar($conn, 'PR_SP_MOVIMIENTO_LISTAR');
?>
<!DOCTYPE html>
<html lang="es"><head><meta charset="UTF-8"><title>Movimientos de stock</title>
<style><?= CSS_BASE ?> .ENTRADA{color:green;font-weight:bold} .SALIDA{color:#b00;font-weight:bold}</style></head>
<body>
  <h2>Movimientos de stock</h2>
  <p><a href="panel.php">← Volver al panel</a></p>
  <?php mostrar_flash(); ?>

  <div class="caja">
    <h3>Registrar movimiento</h3>
    <form method="post">
      Tipo: <select name="tipo" required>
        <option value="SALIDA">SALIDA (venta / retiro)</option>
        <option value="ENTRADA">ENTRADA (ingreso manual)</option>
      </select>
      Producto: <select name="id_producto" required><option value="">Seleccione</option><?= opciones($productos) ?></select>
      Cantidad: <input name="cantidad" inputmode="numeric" pattern="[0-9]+" size="6" required
                       oninput="this.value=this.value.replace(/[^0-9]/g,'')">
      <br><br>
      Estante: <select name="id_ubicacion" required><option value="">Seleccione</option><?= opciones($ubicaciones) ?></select>
      Operario: <select name="rut_operario" required><option value="">Seleccione</option><?= opciones($operarios) ?></select>
      <button>Registrar</button>
    </form>
    <p><small>Si una salida deja el stock en el mínimo o por debajo, se genera automáticamente una alerta de reposición.</small></p>
  </div>

  <h3>Últimos movimientos</h3>
  <table>
    <tr><th>N°</th><th>Fecha</th><th>Tipo</th><th>Cantidad</th><th>Producto</th><th>Estante</th><th>Operario</th><th>Orden</th></tr>
    <?php foreach ($movs as $m): ?>
    <tr>
      <td><?= h($m['ID_MOVIMIENTO']) ?></td>
      <td><?= h($m['FECHA']) ?></td>
      <td class="<?= h($m['TIPO_MOVIMIENTO']) ?>"><?= h($m['TIPO_MOVIMIENTO']) ?></td>
      <td class="num"><?= h($m['CANTIDAD_AFECTADA']) ?></td>
      <td><?= h($m['NOMBRE_PRODUCTO']) ?></td>
      <td><?= h($ubicaciones[$m['ID_UBICACION']] ?? $m['ID_UBICACION']) ?></td>
      <td><?= h($operarios[$m['RUT_OPERARIO']] ?? $m['RUT_OPERARIO']) ?></td>
      <td><?= $m['NRO_ORDEN'] ? '<a href="ordenes.php?nro=' . urlencode($m['NRO_ORDEN']) . '">' . h($m['NRO_ORDEN']) . '</a>' : '-' ?></td>
    </tr>
    <?php endforeach; ?>
    <?php if (!$movs): ?><tr><td colspan="8">No hay movimientos.</td></tr><?php endif; ?>
  </table>
</body></html>
