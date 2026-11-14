<?php
session_start();
require 'conexion.php';
$error = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $usuario = trim($_POST['usuario'] ?? '');
    $clave   = $_POST['clave'] ?? '';

    $conn = conectar();
    $st = oci_parse($conn, 'BEGIN PR_SP_OBTENER_USUARIO(:n, :id, :h, :r, :a); END;');
    oci_bind_by_name($st, ':n',  $usuario);
    oci_bind_by_name($st, ':id', $id, 20);
    oci_bind_by_name($st, ':h',  $hash, 255);
    oci_bind_by_name($st, ':r',  $rol, 50);
    oci_bind_by_name($st, ':a',  $activo, 5);
    oci_execute($st);

    if ($hash && $activo === 'S' && password_verify($clave, $hash)) {
        session_regenerate_id(true);
        $_SESSION['id_usuario'] = $id;
        $_SESSION['usuario']    = $usuario;
        $_SESSION['rol']        = $rol;
        header('Location: panel.php');
        exit;
    }
    $error = 'Usuario o contraseña incorrectos';
}
?>
<!DOCTYPE html>
<html lang="es"><head><meta charset="UTF-8"><title>Login</title></head>
<body>
  <h2>Sistema de Inventario</h2>
  <?php if ($error) echo '<p style="color:red">' . htmlspecialchars($error) . '</p>'; ?>
  <form method="post">
    Usuario: <input name="usuario" required><br><br>
    Contraseña: <input type="password" name="clave" required><br><br>
    <button type="submit">Ingresar</button>
  </form>
</body></html>