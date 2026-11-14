<?php
session_start();
if (!isset($_SESSION['usuario'])) { header('Location: login.php'); exit; }
$rol = $_SESSION['rol'];
$editor = in_array($rol, ['ADMINISTRADOR', 'SUPERVISOR']);
?>
<!DOCTYPE html>
<html lang="es"><head><meta charset="UTF-8"><title>Panel</title>
<style>body{font-family:Arial,sans-serif;margin:20px} h3{margin-bottom:4px}</style></head>
<body>
  <h2>Bienvenido, <?= htmlspecialchars($_SESSION['usuario']) ?> (<?= htmlspecialchars($rol) ?>)</h2>

  <h3>Operación</h3>
  <ul>
    <li><a href="movimientos.php">Movimientos de stock</a></li>
    <li><a href="auditoria.php">Auditoría física</a></li>
    <?php if ($editor): ?>
      <li><a href="ordenes.php">Órdenes de compra</a></li>
      <li><a href="alertas.php">Alertas de reposición</a></li>
      <li><a href="reportes.php">Reportes</a></li>
    <?php endif; ?>
  </ul>

  <h3>Mantenedores<?= $editor ? '' : ' (solo consulta)' ?></h3>
  <ul>
    <li><a href="mantenedor.php?e=producto">Productos</a></li>
    <li><a href="mantenedor.php?e=categoria">Categorías</a></li>
    <li><a href="mantenedor.php?e=marca">Marcas</a></li>
    <li><a href="mantenedor.php?e=proveedor">Proveedores</a></li>
    <li><a href="mantenedor.php?e=pais">Países</a></li>
    <li><a href="mantenedor.php?e=bodega">Bodegas</a></li>
    <li><a href="mantenedor.php?e=ubicacion">Ubicaciones</a></li>
    <li><a href="mantenedor.php?e=turno">Turnos</a></li>
    <li><a href="mantenedor.php?e=operario">Operarios</a></li>
    <?php if ($rol === 'ADMINISTRADOR'): ?>
      <li><a href="mantenedor.php?e=rol">Roles</a></li>
      <li><a href="mantenedor.php?e=usuario">Usuarios</a></li>
    <?php endif; ?>
  </ul>
  <a href="logout.php">Cerrar sesión</a>
</body></html>