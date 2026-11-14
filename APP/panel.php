<?php
session_start();
if (!isset($_SESSION['usuario'])) { header('Location: login.php'); exit; }
$rol = $_SESSION['rol'];
?>
<!DOCTYPE html>
<html lang="es"><head><meta charset="UTF-8"><title>Panel</title></head>
<body>
  <h2>Bienvenido, <?= htmlspecialchars($_SESSION['usuario']) ?> (<?= htmlspecialchars($rol) ?>)</h2>
  <ul>
    <li><a href="mantenedor.php?e=categoria">Categorías</a></li>
    <li><a href="mantenedor.php?e=marca">Marcas</a></li>
    <li><a href="mantenedor.php?e=producto">Productos</a></li>
    <li><a href="mantenedor.php?e=proveedor">Proveedores</a></li>
    <li><a href="mantenedor.php?e=pais">Países</a></li>
    <li><a href="mantenedor.php?e=bodega">Bodegas</a></li>
    <li><a href="mantenedor.php?e=ubicacion">Ubicaciones</a></li>
    <li><a href="mantenedor.php?e=turno">Turnos</a></li>
    <li><a href="mantenedor.php?e=operario">Operarios</a></li>
    <?php if ($rol === 'ADMINISTRADOR' || $rol === 'SUPERVISOR'): ?>
      <li>Órdenes de compra</li>
    <?php endif; ?>
    <?php if ($rol === 'ADMINISTRADOR'): ?>
      <li><a href="mantenedor.php?e=rol">Roles</a></li>
      <li><a href="mantenedor.php?e=usuario">Usuarios</a></li>
    <?php endif; ?>
  </ul>
  <a href="logout.php">Cerrar sesión</a>
</body></html>