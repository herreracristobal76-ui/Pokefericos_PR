<?php
// Gestor de reposicion: ver alertas y generar una orden de compra desde una alerta
session_start();
require 'conexion.php';
require 'funciones.php';
exigir_roles(['ADMINISTRADOR', 'SUPERVISOR']);
$conn = conectar();

const METODOS = ['TRANSFERENCIA', 'TARJETA', 'CREDITO', 'CONTADO'];

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    [$err, $nro] = db_llamar($conn, 'PR_SP_REPONER_DESDE_ALERTA', [
        $_POST['id_alerta'] ?? '',
        $_POST['rut_proveedor'] ?? '',
        $_POST['metodo_pago'] ?? '',
        decimal($_POST['costo'] ?? '')
    ], true);
    if ($err) {
        flash($err, false);
        header('Location: alertas.php');
    } else {
        flash("Se creó la orden N° $nro (PENDIENTE) y la alerta quedó ATENDIDA. Revísela y envíela al proveedor.");
        header('Location: ordenes.php?nro=' . urlencode($nro));
    }
    exit;
}

$alertas = db_listar($conn, 'PR_SP_ALERTA_LISTAR');
$proveedores = mapa(db_listar($conn, 'PR_SP_PROVEEDOR_LISTAR'), 'RUT_PROVEEDOR',
    fn($f) => $f['NOMBRE_EMPRESA'] . ' (' . $f['RUT_PROVEEDOR'] . ')');
?>
<!DOCTYPE html>
<html lang="es"><head><meta charset="UTF-8"><title>Alertas de reposición</title>
<style><?= CSS_BASE ?> .PENDIENTE{color:#b00;font-weight:bold} .ATENDIDA{color:green}</style></head>
<body>
  <h2>Alertas de reposición</h2>
  <p><a href="panel.php">← Volver al panel</a></p>
  <?php mostrar_flash(); ?>
  <p><small>Las alertas las genera el trigger cuando el stock de un producto queda en su mínimo o por debajo.
     Al reponer se crea una orden con cantidad = 2 × stock mínimo − stock actual.</small></p>

  <table>
    <tr><th>N°</th><th>Fecha</th><th>Producto</th><th>Stock actual</th><th>Mínimo</th><th>Estado</th><th>Reponer</th></tr>
    <?php foreach ($alertas as $a): ?>
    <tr>
      <td><?= h($a['ID_ALERTA']) ?></td>
      <td><?= h($a['FECHA']) ?></td>
      <td><?= h($a['NOMBRE_PRODUCTO']) ?></td>
      <td class="num"><?= h($a['STOCK_ACTUAL']) ?></td>
      <td class="num"><?= h($a['STOCK_MINIMO']) ?></td>
      <td class="<?= h($a['ESTADO_ALERTA']) ?>"><?= h($a['ESTADO_ALERTA']) ?></td>
      <td>
        <?php if ($a['ESTADO_ALERTA'] === 'PENDIENTE'): ?>
        <form method="post">
          <input type="hidden" name="id_alerta" value="<?= h($a['ID_ALERTA']) ?>">
          <select name="rut_proveedor" required><option value="">Proveedor</option><?= opciones($proveedores) ?></select>
          <select name="metodo_pago" required>
            <?php foreach (METODOS as $m): ?><option value="<?= $m ?>"><?= $m ?></option><?php endforeach; ?>
          </select>
          Costo unit.: <input name="costo" inputmode="decimal" pattern="[0-9]+([.,][0-9]{1,2})?" size="9" required
                              oninput="this.value=this.value.replace(/[^0-9.,]/g,'')">
          <button>Crear orden</button>
        </form>
        <?php else: ?>-<?php endif; ?>
      </td>
    </tr>
    <?php endforeach; ?>
    <?php if (!$alertas): ?><tr><td colspan="7">No hay alertas.</td></tr><?php endif; ?>
  </table>
</body></html>
