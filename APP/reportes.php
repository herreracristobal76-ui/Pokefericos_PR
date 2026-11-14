<?php
// Dashboard con los 3 reportes (cada uno viene de un procedimiento con cursor)
session_start();
require 'conexion.php';
require 'funciones.php';
exigir_roles(['ADMINISTRADOR', 'SUPERVISOR']);
$conn = conectar();

$anio = (int)($_GET['anio'] ?? date('Y'));
$mes  = (int)($_GET['mes'] ?? date('n'));
if ($mes < 1 || $mes > 12) { $mes = (int)date('n'); }
if ($anio < 2000 || $anio > 2100) { $anio = (int)date('Y'); }
$MESES = [1=>'Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];

$salidas = db_listar($conn, 'PR_SP_REP_SALIDAS_MES', [$anio, $mes]);
$stock   = db_listar($conn, 'PR_SP_REP_STOCK_BODEGA');
$compras = db_listar($conn, 'PR_SP_REP_COMPRAS_PROVEEDOR');

// Indicadores generales
$alertas = db_listar($conn, 'PR_SP_ALERTA_LISTAR');
$ordenes = db_listar($conn, 'PR_SP_ORDEN_LISTAR');
$alertasPend = count(array_filter($alertas, fn($a) => $a['ESTADO_ALERTA'] === 'PENDIENTE'));
$ordenesAbiertas = count(array_filter($ordenes, fn($o) => in_array($o['ESTADO_ORDEN'], ['PENDIENTE', 'ENVIADA'])));
$unidadesMes = array_sum(array_map(fn($r) => (int)$r['UNIDADES_SALIDA'], $salidas));

function barra($valor, $max) {
    $pct = $max > 0 ? round($valor / $max * 100) : 0;
    return '<div class="barra"><span style="width:' . $pct . '%"></span></div>';
}
$maxSal = max(array_merge([0], array_map(fn($r) => (int)$r['UNIDADES_SALIDA'], $salidas)));
$maxCom = max(array_merge([0], array_map(fn($r) => (float)$r['MONTO_TOTAL'], $compras)));
$conSalida = array_values(array_filter($salidas, fn($r) => (int)$r['UNIDADES_SALIDA'] > 0));
?>
<!DOCTYPE html>
<html lang="es"><head><meta charset="UTF-8"><title>Reportes</title>
<style><?= CSS_BASE ?>
 .kpis{display:flex;gap:12px;flex-wrap:wrap}
 .kpi{border:1px solid #ccc;border-radius:6px;padding:10px 16px;min-width:150px}
 .kpi b{display:block;font-size:26px}
 .barra{background:#eee;width:220px;height:14px;border-radius:3px}
 .barra span{display:block;height:100%;background:#2b6cb0;border-radius:3px}
 .bajo{background:#fde2e2}
</style></head>
<body>
  <h2>Reportes</h2>
  <p><a href="panel.php">← Volver al panel</a></p>

  <div class="kpis">
    <div class="kpi"><b><?= $unidadesMes ?></b>unidades vendidas en <?= h($MESES[$mes]) ?></div>
    <div class="kpi"><b><?= $alertasPend ?></b>alertas de reposición pendientes</div>
    <div class="kpi"><b><?= $ordenesAbiertas ?></b>órdenes de compra abiertas</div>
  </div>

  <!-- Reporte 1 -->
  <div class="caja">
    <h3>1. Productos con mayor y menor salida del mes</h3>
    <form method="get">
      Mes: <select name="mes"><?php foreach ($MESES as $n => $nom): ?>
        <option value="<?= $n ?>"<?= $n === $mes ? ' selected' : '' ?>><?= $nom ?></option><?php endforeach; ?></select>
      Año: <input name="anio" value="<?= $anio ?>" size="5" inputmode="numeric"
                  oninput="this.value=this.value.replace(/[^0-9]/g,'')">
      <button>Ver</button>
    </form>
    <?php if ($conSalida): ?>
      <p>Mayor salida: <b><?= h($conSalida[0]['NOMBRE_PRODUCTO']) ?></b> (<?= h($conSalida[0]['UNIDADES_SALIDA']) ?> u.)
       &nbsp;|&nbsp; Menor salida: <b><?= h(end($conSalida)['NOMBRE_PRODUCTO']) ?></b> (<?= h(end($conSalida)['UNIDADES_SALIDA']) ?> u.)</p>
    <?php else: ?>
      <p>No hubo salidas en <?= h($MESES[$mes]) ?> de <?= $anio ?>.</p>
    <?php endif; ?>
    <table>
      <tr><th>Ranking</th><th>Producto</th><th>Unidades</th><th></th></tr>
      <?php foreach ($salidas as $r): ?>
      <tr>
        <td><?= h($r['RANKING']) ?></td>
        <td><?= h($r['NOMBRE_PRODUCTO']) ?></td>
        <td class="num"><?= h($r['UNIDADES_SALIDA']) ?></td>
        <td><?= barra((int)$r['UNIDADES_SALIDA'], $maxSal) ?></td>
      </tr>
      <?php endforeach; ?>
    </table>
  </div>

  <!-- Reporte 2 -->
  <div class="caja">
    <h3>2. Stock por bodega</h3>
    <table>
      <tr><th>Bodega</th><th>Producto</th><th>Unidades</th><th>Stock mínimo</th></tr>
      <?php foreach ($stock as $r): ?>
      <tr class="<?= (int)$r['UNIDADES'] <= (int)$r['STOCK_MINIMO'] ? 'bajo' : '' ?>">
        <td><?= h($r['NOMBRE_RECINTO']) ?></td>
        <td><?= h($r['NOMBRE_PRODUCTO']) ?></td>
        <td class="num"><?= h($r['UNIDADES']) ?></td>
        <td class="num"><?= h($r['STOCK_MINIMO']) ?></td>
      </tr>
      <?php endforeach; ?>
      <?php if (!$stock): ?><tr><td colspan="4">Sin stock registrado.</td></tr><?php endif; ?>
    </table>
    <p><small>En rojo: en esa bodega hay igual o menos unidades que el stock mínimo del producto.</small></p>
  </div>

  <!-- Reporte 3 -->
  <div class="caja">
    <h3>3. Compras por proveedor</h3>
    <table>
      <tr><th>Proveedor</th><th>Órdenes</th><th>Pendientes</th><th>Monto (sin canceladas)</th><th></th></tr>
      <?php foreach ($compras as $r): ?>
      <tr>
        <td><?= h($r['NOMBRE_EMPRESA']) ?></td>
        <td class="num"><?= h($r['ORDENES']) ?></td>
        <td class="num"><?= h($r['PENDIENTES']) ?></td>
        <td class="num"><?= dinero($r['MONTO_TOTAL']) ?></td>
        <td><?= barra((float)$r['MONTO_TOTAL'], $maxCom) ?></td>
      </tr>
      <?php endforeach; ?>
      <?php if (!$compras): ?><tr><td colspan="5">No hay proveedores.</td></tr><?php endif; ?>
    </table>
  </div>
</body></html>
