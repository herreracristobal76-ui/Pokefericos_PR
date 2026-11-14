<?php
// Gestor de ordenes de compra: crear, agregar productos, enviar/cancelar y recepcionar
session_start();
require 'conexion.php';
require 'funciones.php';
exigir_roles(['ADMINISTRADOR', 'SUPERVISOR']);
$conn = conectar();

const METODOS = ['TRANSFERENCIA', 'TARJETA', 'CREDITO', 'CONTADO'];

// ---------- Acciones (POST) ----------
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $accion = $_POST['accion'] ?? '';
    $nro = $_POST['nro'] ?? '';

    if ($accion === 'crear') {
        [$err, $nuevo] = db_llamar($conn, 'PR_SP_ORDEN_CREAR',
            [$_POST['rut_proveedor'] ?? '', $_POST['metodo_pago'] ?? ''], true);
        if ($err) { flash($err, false); }
        else { flash("Orden N° $nuevo creada. Ahora agregue sus productos."); $nro = $nuevo; }

    } elseif ($accion === 'linea') {
        [$err] = db_llamar($conn, 'PR_SP_ORDEN_AGREGAR_LINEA',
            [$nro, $_POST['id_producto'] ?? '', solo_digitos($_POST['cantidad'] ?? ''), decimal($_POST['costo'] ?? '')]);
        flash($err ?? 'Producto agregado a la orden', $err === null);

    } elseif ($accion === 'estado') {
        [$err] = db_llamar($conn, 'PR_SP_ORDEN_CAMBIAR_ESTADO', [$nro, $_POST['estado'] ?? '']);
        flash($err ?? 'Estado actualizado a ' . ($_POST['estado'] ?? ''), $err === null);

    } elseif ($accion === 'recepcionar') {
        [$err] = db_llamar($conn, 'PR_SP_ORDEN_RECEPCIONAR',
            [$nro, $_POST['id_ubicacion'] ?? '', $_POST['rut_operario'] ?? '']);
        flash($err ?? 'Orden recibida: el stock fue actualizado', $err === null);
    }
    header('Location: ordenes.php' . ($nro !== '' && $nro !== null ? '?nro=' . urlencode($nro) : ''));
    exit;
}

// ---------- Datos ----------
$ordenes = db_listar($conn, 'PR_SP_ORDEN_LISTAR');

$proveedores = mapa(db_listar($conn, 'PR_SP_PROVEEDOR_LISTAR'), 'RUT_PROVEEDOR',
    fn($f) => $f['NOMBRE_EMPRESA'] . ' (' . $f['RUT_PROVEEDOR'] . ')');
$productos = mapa(db_listar($conn, 'PR_SP_PRODUCTO_LISTAR'), 'ID_PRODUCTO',
    fn($f) => $f['NOMBRE_PRODUCTO']);
$bodegas = mapa(db_listar($conn, 'PR_SP_BODEGA_LISTAR'), 'ID_BODEGA',
    fn($f) => $f['NOMBRE_RECINTO']);
$ubicaciones = mapa(db_listar($conn, 'PR_SP_UBICACION_LISTAR'), 'ID_UBICACION',
    fn($f) => ($bodegas[$f['ID_BODEGA']] ?? 'Bodega ' . $f['ID_BODEGA']) .
              ' - Pasillo ' . $f['PASILLO'] . ', Nivel ' . $f['NIVEL']);
$operarios = mapa(db_listar($conn, 'PR_SP_OPERARIO_LISTAR'), 'RUT_OPERARIO',
    fn($f) => $f['NOMBRES'] . ' ' . $f['APELLIDOS'] . ' (' . $f['RUT_OPERARIO'] . ')');

// Orden seleccionada
$nroVer = $_GET['nro'] ?? null;
$orden = null;
$lineas = [];
if ($nroVer !== null) {
    foreach ($ordenes as $o) {
        if ((string)$o['NRO_ORDEN'] === (string)$nroVer) { $orden = $o; break; }
    }
    if ($orden) { $lineas = db_listar($conn, 'PR_SP_ORDEN_DETALLE', [$nroVer]); }
}
?>
<!DOCTYPE html>
<html lang="es"><head><meta charset="UTF-8"><title>Órdenes de compra</title>
<style><?= CSS_BASE ?></style></head>
<body>
  <h2>Órdenes de compra</h2>
  <p><a href="panel.php">← Volver al panel</a><?php if ($orden): ?> | <a href="ordenes.php">Ver todas las órdenes</a><?php endif; ?></p>
  <?php mostrar_flash(); ?>

<?php if ($orden): ?>
  <!-- ================= DETALLE DE UNA ORDEN ================= -->
  <div class="caja">
    <h3>Orden N° <?= h($orden['NRO_ORDEN']) ?> — <?= h($orden['ESTADO_ORDEN']) ?></h3>
    <p>Proveedor: <b><?= h($orden['NOMBRE_EMPRESA']) ?></b> (<?= h($orden['RUT_PROVEEDOR']) ?>)<br>
       Fecha: <?= h($orden['FECHA']) ?> | Pago: <?= h($orden['METODO_PAGO']) ?><br>
       Total: <b><?= dinero($orden['MONTO_TOTAL']) ?></b></p>

    <table>
      <tr><th>#</th><th>Producto</th><th>Cantidad</th><th>Costo unitario</th><th>Subtotal</th></tr>
      <?php foreach ($lineas as $l): ?>
      <tr>
        <td><?= h($l['ID_DETALLE']) ?></td>
        <td><?= h($l['NOMBRE_PRODUCTO']) ?></td>
        <td class="num"><?= h($l['CANTIDAD_SOLICITADA']) ?></td>
        <td class="num"><?= dinero($l['COSTO_UNITARIO']) ?></td>
        <td class="num"><?= dinero($l['SUBTOTAL']) ?></td>
      </tr>
      <?php endforeach; ?>
      <?php if (!$lineas): ?><tr><td colspan="5">Sin productos todavía.</td></tr><?php endif; ?>
    </table>

    <?php if ($orden['ESTADO_ORDEN'] === 'PENDIENTE'): ?>
      <h4>Agregar producto</h4>
      <form method="post">
        <input type="hidden" name="accion" value="linea">
        <input type="hidden" name="nro" value="<?= h($orden['NRO_ORDEN']) ?>">
        Producto: <select name="id_producto" required><option value="">Seleccione</option><?= opciones($productos) ?></select>
        Cantidad: <input name="cantidad" inputmode="numeric" pattern="[0-9]+" size="6" required
                         oninput="this.value=this.value.replace(/[^0-9]/g,'')">
        Costo unitario: <input name="costo" inputmode="decimal" pattern="[0-9]+([.,][0-9]{1,2})?" size="10" required
                         oninput="this.value=this.value.replace(/[^0-9.,]/g,'')">
        <button>Agregar</button>
      </form>
      <br>
      <form method="post" style="display:inline">
        <input type="hidden" name="accion" value="estado">
        <input type="hidden" name="nro" value="<?= h($orden['NRO_ORDEN']) ?>">
        <input type="hidden" name="estado" value="ENVIADA">
        <button>Enviar orden al proveedor</button>
      </form>
    <?php endif; ?>

    <?php if ($orden['ESTADO_ORDEN'] === 'ENVIADA'): ?>
      <h4>Recepcionar mercadería</h4>
      <form method="post">
        <input type="hidden" name="accion" value="recepcionar">
        <input type="hidden" name="nro" value="<?= h($orden['NRO_ORDEN']) ?>">
        Guardar en: <select name="id_ubicacion" required><option value="">Seleccione</option><?= opciones($ubicaciones) ?></select>
        Recibe: <select name="rut_operario" required><option value="">Seleccione</option><?= opciones($operarios) ?></select>
        <button>Recepcionar</button>
      </form>
    <?php endif; ?>

    <?php if (in_array($orden['ESTADO_ORDEN'], ['PENDIENTE', 'ENVIADA'])): ?>
      <form method="post" style="display:inline" onsubmit="return confirm('¿Cancelar esta orden?')">
        <input type="hidden" name="accion" value="estado">
        <input type="hidden" name="nro" value="<?= h($orden['NRO_ORDEN']) ?>">
        <input type="hidden" name="estado" value="CANCELADA">
        <button>Cancelar orden</button>
      </form>
    <?php endif; ?>
  </div>

<?php else: ?>
  <?php if ($nroVer !== null): ?><p class="err">La orden N° <?= h($nroVer) ?> no existe.</p><?php endif; ?>

  <!-- ================= NUEVA ORDEN ================= -->
  <div class="caja">
    <h3>Nueva orden</h3>
    <form method="post">
      <input type="hidden" name="accion" value="crear">
      Proveedor: <select name="rut_proveedor" required><option value="">Seleccione</option><?= opciones($proveedores) ?></select>
      Método de pago: <select name="metodo_pago" required>
        <?php foreach (METODOS as $m): ?><option value="<?= $m ?>"><?= $m ?></option><?php endforeach; ?>
      </select>
      <button>Crear orden</button>
    </form>
  </div>

  <!-- ================= LISTADO ================= -->
  <table>
    <tr><th>N°</th><th>Fecha</th><th>Proveedor</th><th>Pago</th><th>Estado</th><th>Total</th><th></th></tr>
    <?php foreach ($ordenes as $o): ?>
    <tr>
      <td><?= h($o['NRO_ORDEN']) ?></td>
      <td><?= h($o['FECHA']) ?></td>
      <td><?= h($o['NOMBRE_EMPRESA']) ?></td>
      <td><?= h($o['METODO_PAGO']) ?></td>
      <td><?= h($o['ESTADO_ORDEN']) ?></td>
      <td class="num"><?= dinero($o['MONTO_TOTAL']) ?></td>
      <td><a href="ordenes.php?nro=<?= urlencode($o['NRO_ORDEN']) ?>">Ver</a></td>
    </tr>
    <?php endforeach; ?>
    <?php if (!$ordenes): ?><tr><td colspan="7">No hay órdenes registradas.</td></tr><?php endif; ?>
  </table>
<?php endif; ?>
</body></html>
