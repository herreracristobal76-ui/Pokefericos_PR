-- =====================================================================
--  SISTEMA DE CONTROL DE INVENTARIO DE PERIFERICOS (Gold Gaming)
--  SCRIPT COMPLETO - Oracle Database 21c XE
--
--  Contiene: secuencias, tipos objeto, tablas (3FN), vistas, reglas de
--  calidad de datos, procedimientos almacenados (CRUD de 11
--  mantenedores, 5 gestores, 3 reportes), funciones, cursores,
--  triggers y datos de prueba.
--
--  COMO EJECUTARLO:
--    SQL Developer, conectado como el usuario del proyecto (INVENTARIO),
--    abrir este archivo y presionar F5 ("Ejecutar script").
--
--  ATENCION: la seccion 0 BORRA todos los objetos PR_ existentes y sus
--  datos, para crear todo desde cero. Se puede ejecutar las veces que
--  se quiera: siempre deja la base igual.
-- =====================================================================
SET DEFINE OFF
SET SERVEROUTPUT ON


-- ---------------------------------------------------------------------
-- 0. LIMPIEZA: borra los objetos PR_ si existen (no falla si no existen)
-- ---------------------------------------------------------------------
BEGIN
    FOR r IN (SELECT view_name AS n FROM user_views
               WHERE view_name LIKE 'PR\_%' ESCAPE '\') LOOP
        EXECUTE IMMEDIATE 'DROP VIEW "' || r.n || '"';
    END LOOP;
    FOR r IN (SELECT table_name AS n FROM user_tables
               WHERE table_name LIKE 'PR\_%' ESCAPE '\') LOOP
        EXECUTE IMMEDIATE 'DROP TABLE "' || r.n || '" CASCADE CONSTRAINTS PURGE';
    END LOOP;
    FOR r IN (SELECT object_name AS n, object_type AS t FROM user_objects
               WHERE object_name LIKE 'PR\_%' ESCAPE '\'
                 AND object_type IN ('PROCEDURE', 'FUNCTION', 'PACKAGE')) LOOP
        EXECUTE IMMEDIATE 'DROP ' || r.t || ' "' || r.n || '"';
    END LOOP;
    FOR r IN (SELECT type_name AS n FROM user_types
               WHERE type_name LIKE 'PR\_%' ESCAPE '\'
               ORDER BY CASE WHEN typecode = 'COLLECTION' THEN 0 ELSE 1 END) LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP TYPE "' || r.n || '" FORCE';
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
    END LOOP;
    FOR r IN (SELECT sequence_name AS n FROM user_sequences
               WHERE sequence_name LIKE 'PR\_%' ESCAPE '\') LOOP
        EXECUTE IMMEDIATE 'DROP SEQUENCE "' || r.n || '"';
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('Limpieza terminada.');
END;
/

-- =====================================================================
-- 1. SECUENCIAS (generan los ID)
--    NOCACHE: los ID quedan correlativos (sin saltos al reiniciar la BD).
--    PR_Detalle_Compra.ID_Detalle no lleva secuencia: es 1, 2, 3... dentro
--    de cada orden y lo asigna el procedimiento que crea la orden.
-- =====================================================================
CREATE SEQUENCE PR_SEQ_Turno      
    START WITH 1 
    INCREMENT BY 1 
    NOCACHE NOCYCLE;
    
CREATE SEQUENCE PR_SEQ_Pais       
    START WITH 1 
    INCREMENT BY 1 
    NOCACHE NOCYCLE;

CREATE SEQUENCE PR_SEQ_Categoria  
    START WITH 1 
    INCREMENT BY 1 
    NOCACHE NOCYCLE;

CREATE SEQUENCE PR_SEQ_Marca      
    START WITH 1 
    INCREMENT BY 1 
    NOCACHE NOCYCLE;

CREATE SEQUENCE PR_SEQ_Bodega     
    START WITH 1 
    INCREMENT BY 1 
    NOCACHE NOCYCLE;

CREATE SEQUENCE PR_SEQ_Ubicacion  
    START WITH 1 
    INCREMENT BY 1 
    NOCACHE NOCYCLE;

CREATE SEQUENCE PR_SEQ_Producto   
    START WITH 1 
    INCREMENT BY 1 
    NOCACHE NOCYCLE;

CREATE SEQUENCE PR_SEQ_Telefono   
    START WITH 1 
    INCREMENT BY 1 
    NOCACHE NOCYCLE;

CREATE SEQUENCE PR_SEQ_Orden      
    START WITH 1 
    INCREMENT BY 1 
    NOCACHE NOCYCLE;

CREATE SEQUENCE PR_SEQ_Movimiento 
    START WITH 1 
    INCREMENT BY 1 
    NOCACHE NOCYCLE;

CREATE SEQUENCE PR_SEQ_Alerta     
    START WITH 1 
    INCREMENT BY 1 
    NOCACHE NOCYCLE;

CREATE SEQUENCE PR_SEQ_Examen     
    START WITH 1 INCREMENT 
    BY 1 
    NOCACHE NOCYCLE;

CREATE SEQUENCE PR_SEQ_Rol        
    START WITH 1 
    INCREMENT BY 1 
    NOCACHE NOCYCLE;

CREATE SEQUENCE PR_SEQ_Usuario    
    START WITH 1 
    INCREMENT BY 1 
    NOCACHE NOCYCLE;


-- =====================================================================
-- 2. TIPOS OBJETO-RELACIONALES
--    (cada bloque termina con "/" en una linea sola)
-- =====================================================================

-- Direccion como objeto. La tabla PR_Bodega sigue guardando calle, numero y
-- comuna por separado (3FN); el tipo se usa para presentarla como objeto.
CREATE OR REPLACE TYPE PR_T_Direccion AS OBJECT (
    Calle   VARCHAR2(50),
    Numero  NUMBER(10),
    Comuna  VARCHAR2(50),
    MEMBER FUNCTION Texto RETURN VARCHAR2
);
/

CREATE OR REPLACE TYPE BODY PR_T_Direccion AS
    MEMBER FUNCTION Texto RETURN VARCHAR2 IS
    BEGIN
        RETURN Calle || ' ' || Numero || ', ' || Comuna;
    END;
END;
/

-- Una linea de una orden de compra (producto, cantidad, costo).
CREATE OR REPLACE TYPE PR_T_Linea_Compra AS OBJECT (
    ID_Producto     NUMBER(10),
    Cantidad        NUMBER(10),
    Costo_Unitario  NUMBER(10,2),
    MEMBER FUNCTION Subtotal RETURN NUMBER
);
/

CREATE OR REPLACE TYPE BODY PR_T_Linea_Compra AS
    MEMBER FUNCTION Subtotal RETURN NUMBER IS
    BEGIN
        RETURN Cantidad * Costo_Unitario;
    END;
END;
/

-- Coleccion de lineas: permite enviar toda la orden a un procedimiento.
CREATE OR REPLACE TYPE PR_T_Lineas_Compra AS TABLE OF PR_T_Linea_Compra;
/


-- =====================================================================
-- 3. TABLAS SIN DEPENDENCIAS (los "padres")
-- =====================================================================

CREATE TABLE PR_Turno (
    ID_Turno          NUMBER(10) DEFAULT PR_SEQ_Turno.NEXTVAL NOT NULL,
    Nombre_Turno      VARCHAR2(50) NOT NULL,
    Horario_Turno     VARCHAR2(20) NOT NULL,
    Supervisor_Turno  VARCHAR2(50) NOT NULL,
    CONSTRAINT PR_PK_TUR PRIMARY KEY (ID_Turno),
    CONSTRAINT PR_UQ_TUR_NOMBRE UNIQUE (Nombre_Turno)
);

CREATE TABLE PR_Rol (
    ID_Rol      NUMBER(10) DEFAULT PR_SEQ_Rol.NEXTVAL NOT NULL,
    Nombre_Rol  VARCHAR2(30) NOT NULL,
    CONSTRAINT PR_PK_ROL PRIMARY KEY (ID_Rol),
    CONSTRAINT PR_UQ_ROL_NOMBRE UNIQUE (Nombre_Rol)
);

CREATE TABLE PR_Pais (
    ID_Pais      NUMBER(10) DEFAULT PR_SEQ_Pais.NEXTVAL NOT NULL,
    Nombre_Pais  VARCHAR2(80) NOT NULL,
    CONSTRAINT PR_PK_PAI PRIMARY KEY (ID_Pais),
    CONSTRAINT PR_UQ_PAI_NOMBRE UNIQUE (Nombre_Pais)
);

CREATE TABLE PR_Categoria (
    ID_Categoria      NUMBER(10) DEFAULT PR_SEQ_Categoria.NEXTVAL NOT NULL,
    Nombre_Categoria  VARCHAR2(50) NOT NULL,
    CONSTRAINT PR_PK_CAT PRIMARY KEY (ID_Categoria),
    CONSTRAINT PR_UQ_CAT_NOMBRE UNIQUE (Nombre_Categoria)
);

CREATE TABLE PR_Marca (
    ID_Marca      NUMBER(10) DEFAULT PR_SEQ_Marca.NEXTVAL NOT NULL,
    Nombre_Marca  VARCHAR2(50) NOT NULL,
    CONSTRAINT PR_PK_MAR PRIMARY KEY (ID_Marca),
    CONSTRAINT PR_UQ_MAR_NOMBRE UNIQUE (Nombre_Marca)
);

CREATE TABLE PR_Bodega (
    ID_Bodega       NUMBER(10) DEFAULT PR_SEQ_Bodega.NEXTVAL NOT NULL,
    Nombre_Recinto  VARCHAR2(50) NOT NULL,
    Calle           VARCHAR2(50) NOT NULL,
    Numero          NUMBER(10)   NOT NULL,
    Comuna          VARCHAR2(50) NOT NULL,
    CONSTRAINT PR_PK_BOD PRIMARY KEY (ID_Bodega)
);

CREATE TABLE PR_Lector_Codigo (
    Nro_Serie_Lector    VARCHAR2(50) NOT NULL,
    Porcentaje_Bateria  NUMBER(10)   NOT NULL,
    CONSTRAINT PR_PK_LEC PRIMARY KEY (Nro_Serie_Lector),
    CONSTRAINT PR_CK_LEC_BATERIA CHECK (Porcentaje_Bateria BETWEEN 0 AND 100)
);


-- =====================================================================
-- 4. TABLAS QUE DEPENDEN DE UNA SOLA TABLA ANTERIOR
-- =====================================================================

CREATE TABLE PR_Operario (
    RUT_Operario  VARCHAR2(12) NOT NULL,
    Nombres       VARCHAR2(50) NOT NULL,
    Apellidos     VARCHAR2(50) NOT NULL,
    ID_Turno      NUMBER(10)   NOT NULL,
    CONSTRAINT PR_PK_OPE PRIMARY KEY (RUT_Operario),
    CONSTRAINT PR_FK_OPE_TUR FOREIGN KEY (ID_Turno)
        REFERENCES PR_Turno (ID_Turno)
);

-- Usuarios del sistema (login). La contrasena NUNCA se guarda en texto
-- plano: se guarda el hash (PHP: password_hash() entrega ~60 caracteres).
-- RUT_Operario es opcional: un administrador puede no ser operario.
CREATE TABLE PR_Usuario (
    ID_Usuario     NUMBER(10) DEFAULT PR_SEQ_Usuario.NEXTVAL NOT NULL,
    Nombre_Usuario VARCHAR2(30)  NOT NULL,
    Password_Hash  VARCHAR2(255) NOT NULL,
    Activo         CHAR(1) DEFAULT 'S' NOT NULL,
    ID_Rol         NUMBER(10)   NOT NULL,
    RUT_Operario   VARCHAR2(12),
    CONSTRAINT PR_PK_USU PRIMARY KEY (ID_Usuario),
    CONSTRAINT PR_UQ_USU_NOMBRE UNIQUE (Nombre_Usuario),
    CONSTRAINT PR_UQ_USU_OPE UNIQUE (RUT_Operario),
    CONSTRAINT PR_FK_USU_ROL FOREIGN KEY (ID_Rol)
        REFERENCES PR_Rol (ID_Rol),
    CONSTRAINT PR_FK_USU_OPE FOREIGN KEY (RUT_Operario)
        REFERENCES PR_Operario (RUT_Operario),
    CONSTRAINT PR_CK_USU_ACTIVO CHECK (Activo IN ('S', 'N'))
);

CREATE TABLE PR_Ubicacion_Estante (
    ID_Ubicacion  NUMBER(10) DEFAULT PR_SEQ_Ubicacion.NEXTVAL NOT NULL,
    Pasillo       NUMBER(10) NOT NULL,
    Nivel         NUMBER(10) NOT NULL,
    ID_Bodega     NUMBER(10) NOT NULL,
    CONSTRAINT PR_PK_UBI PRIMARY KEY (ID_Ubicacion),
    CONSTRAINT PR_FK_UBI_BOD FOREIGN KEY (ID_Bodega)
        REFERENCES PR_Bodega (ID_Bodega),
    CONSTRAINT PR_UQ_UBI_POSICION UNIQUE (ID_Bodega, Pasillo, Nivel)
);

CREATE TABLE PR_Producto (
    ID_Producto      NUMBER(10) DEFAULT PR_SEQ_Producto.NEXTVAL NOT NULL,
    Nombre_Producto  VARCHAR2(50) NOT NULL,
    Precio_Venta     NUMBER(10,2) NOT NULL,
    Stock_Minimo     NUMBER(10) DEFAULT 0 NOT NULL,
    ID_Categoria     NUMBER(10) NOT NULL,
    ID_Marca         NUMBER(10) NOT NULL,
    CONSTRAINT PR_PK_PRO PRIMARY KEY (ID_Producto),
    CONSTRAINT PR_FK_PRO_CAT FOREIGN KEY (ID_Categoria)
        REFERENCES PR_Categoria (ID_Categoria),
    CONSTRAINT PR_FK_PRO_MAR FOREIGN KEY (ID_Marca)
        REFERENCES PR_Marca (ID_Marca),
    CONSTRAINT PR_CK_PRO_PRECIO CHECK (Precio_Venta >= 0),
    CONSTRAINT PR_CK_PRO_STOCKMIN CHECK (Stock_Minimo >= 0)
);
-- OJO: no existe Stock_Actual. Se calcula con la vista PR_V_Stock_Producto.

CREATE TABLE PR_Proveedor (
    RUT_Proveedor   VARCHAR2(12) NOT NULL,
    Nombre_Empresa  VARCHAR2(50) NOT NULL,
    ID_Pais         NUMBER(10)   NOT NULL,
    CONSTRAINT PR_PK_PRV PRIMARY KEY (RUT_Proveedor),
    CONSTRAINT PR_FK_PRV_PAI FOREIGN KEY (ID_Pais)
        REFERENCES PR_Pais (ID_Pais)
);


-- =====================================================================
-- 5. TABLAS QUE DEPENDEN DE PROVEEDOR / PRODUCTO / OPERARIO / UBICACION
-- =====================================================================

CREATE TABLE PR_Telefono_Proveedor (
    ID_Telefono      NUMBER(10) DEFAULT PR_SEQ_Telefono.NEXTVAL NOT NULL,
    Numero_Contacto  VARCHAR2(20) NOT NULL,
    RUT_Proveedor    VARCHAR2(12) NOT NULL,
    CONSTRAINT PR_PK_TEL PRIMARY KEY (ID_Telefono),
    CONSTRAINT PR_FK_TEL_PRV FOREIGN KEY (RUT_Proveedor)
        REFERENCES PR_Proveedor (RUT_Proveedor),
    CONSTRAINT PR_UQ_TEL_NUMERO UNIQUE (RUT_Proveedor, Numero_Contacto)
);

CREATE TABLE PR_Orden_Compra (
    Nro_Orden      NUMBER(10) DEFAULT PR_SEQ_Orden.NEXTVAL NOT NULL,
    Fecha_Emision  DATE DEFAULT SYSDATE NOT NULL,
    Estado_Orden   VARCHAR2(20) DEFAULT 'PENDIENTE' NOT NULL,
    Metodo_Pago    VARCHAR2(20) NOT NULL,
    RUT_Proveedor  VARCHAR2(12) NOT NULL,
    CONSTRAINT PR_PK_ORD PRIMARY KEY (Nro_Orden),
    CONSTRAINT PR_FK_ORD_PRV FOREIGN KEY (RUT_Proveedor)
        REFERENCES PR_Proveedor (RUT_Proveedor),
    CONSTRAINT PR_CK_ORD_ESTADO CHECK (Estado_Orden IN
        ('PENDIENTE', 'ENVIADA', 'RECIBIDA', 'CANCELADA')),
    CONSTRAINT PR_CK_ORD_PAGO CHECK (Metodo_Pago IN
        ('TRANSFERENCIA', 'TARJETA', 'CREDITO', 'CONTADO'))
);
-- OJO: no existe Monto_Total. Se calcula con la vista PR_V_Orden_Total.

-- Cada movimiento ocurre en un estante (ID_Ubicacion). Nro_Orden solo se
-- llena cuando la ENTRADA viene de recepcionar una orden de compra.
CREATE TABLE PR_Movimiento_Stock (
    ID_Movimiento      NUMBER(10) DEFAULT PR_SEQ_Movimiento.NEXTVAL NOT NULL,
    Tipo_Movimiento    VARCHAR2(20) NOT NULL,
    Cantidad_Afectada  NUMBER(10)   NOT NULL,
    Fecha_Movimiento   DATE DEFAULT SYSDATE NOT NULL,
    ID_Producto        NUMBER(10)   NOT NULL,
    ID_Ubicacion       NUMBER(10)   NOT NULL,
    RUT_Operario       VARCHAR2(12) NOT NULL,
    Nro_Orden          NUMBER(10),
    CONSTRAINT PR_PK_MOV PRIMARY KEY (ID_Movimiento),
    CONSTRAINT PR_FK_MOV_PRO FOREIGN KEY (ID_Producto)
        REFERENCES PR_Producto (ID_Producto),
    CONSTRAINT PR_FK_MOV_UBI FOREIGN KEY (ID_Ubicacion)
        REFERENCES PR_Ubicacion_Estante (ID_Ubicacion),
    CONSTRAINT PR_FK_MOV_OPE FOREIGN KEY (RUT_Operario)
        REFERENCES PR_Operario (RUT_Operario),
    CONSTRAINT PR_FK_MOV_ORD FOREIGN KEY (Nro_Orden)
        REFERENCES PR_Orden_Compra (Nro_Orden),
    CONSTRAINT PR_CK_MOV_TIPO CHECK (Tipo_Movimiento IN ('ENTRADA', 'SALIDA')),
    CONSTRAINT PR_CK_MOV_CANT CHECK (Cantidad_Afectada > 0)
);
-- La cantidad siempre es positiva; el signo lo da Tipo_Movimiento.

CREATE TABLE PR_Alerta_Reposicion (
    ID_Alerta         NUMBER(10) DEFAULT PR_SEQ_Alerta.NEXTVAL NOT NULL,
    Fecha_Generacion  DATE DEFAULT SYSDATE NOT NULL,
    Estado_Alerta     VARCHAR2(20) DEFAULT 'PENDIENTE' NOT NULL,
    ID_Producto       NUMBER(10) NOT NULL,
    CONSTRAINT PR_PK_ALE PRIMARY KEY (ID_Alerta),
    CONSTRAINT PR_FK_ALE_PRO FOREIGN KEY (ID_Producto)
        REFERENCES PR_Producto (ID_Producto),
    CONSTRAINT PR_CK_ALE_ESTADO CHECK (Estado_Alerta IN ('PENDIENTE', 'ATENDIDA'))
);


-- =====================================================================
-- 6. TABLAS INTERMEDIAS Y ENTIDAD DEBIL
-- =====================================================================

-- Entidad debil: si se borra la orden, se borran sus detalles.
-- ID_Detalle lo asigna el procedimiento: 1, 2, 3... dentro de cada orden.
CREATE TABLE PR_Detalle_Compra (
    Nro_Orden            NUMBER(10)   NOT NULL,
    ID_Detalle           NUMBER(10)   NOT NULL,
    Costo_Unitario       NUMBER(10,2) NOT NULL,
    Cantidad_Solicitada  NUMBER(10)   NOT NULL,
    ID_Producto          NUMBER(10)   NOT NULL,
    CONSTRAINT PR_PK_DET PRIMARY KEY (Nro_Orden, ID_Detalle),
    CONSTRAINT PR_FK_DET_ORD FOREIGN KEY (Nro_Orden)
        REFERENCES PR_Orden_Compra (Nro_Orden) ON DELETE CASCADE,
    CONSTRAINT PR_FK_DET_PRO FOREIGN KEY (ID_Producto)
        REFERENCES PR_Producto (ID_Producto),
    CONSTRAINT PR_UQ_DET_PRODUCTO UNIQUE (Nro_Orden, ID_Producto),
    CONSTRAINT PR_CK_DET_COSTO CHECK (Costo_Unitario >= 0),
    CONSTRAINT PR_CK_DET_CANT CHECK (Cantidad_Solicitada > 0)
);

CREATE TABLE PR_Proveedor_Producto (
    RUT_Proveedor  VARCHAR2(12) NOT NULL,
    ID_Producto    NUMBER(10)   NOT NULL,
    CONSTRAINT PR_PK_PPR PRIMARY KEY (RUT_Proveedor, ID_Producto),
    CONSTRAINT PR_FK_PPR_PRV FOREIGN KEY (RUT_Proveedor)
        REFERENCES PR_Proveedor (RUT_Proveedor),
    CONSTRAINT PR_FK_PPR_PRO FOREIGN KEY (ID_Producto)
        REFERENCES PR_Producto (ID_Producto)
);

CREATE TABLE PR_Utiliza (
    RUT_Operario      VARCHAR2(12) NOT NULL,
    Nro_Serie_Lector  VARCHAR2(50) NOT NULL,
    CONSTRAINT PR_PK_UTI PRIMARY KEY (RUT_Operario, Nro_Serie_Lector),
    CONSTRAINT PR_FK_UTI_OPE FOREIGN KEY (RUT_Operario)
        REFERENCES PR_Operario (RUT_Operario),
    CONSTRAINT PR_FK_UTI_LEC FOREIGN KEY (Nro_Serie_Lector)
        REFERENCES PR_Lector_Codigo (Nro_Serie_Lector)
);

-- Auditoria fisica (relacion ternaria Operario - Producto - Ubicacion).
-- Una fila por revision; Cantidad_Contada es lo que el operario conto.
CREATE TABLE PR_Examina (
    ID_Examen         NUMBER(10) DEFAULT PR_SEQ_Examen.NEXTVAL NOT NULL,
    RUT_Operario      VARCHAR2(12) NOT NULL,
    ID_Producto       NUMBER(10)   NOT NULL,
    ID_Ubicacion      NUMBER(10)   NOT NULL,
    Fecha_Examen      DATE DEFAULT SYSDATE NOT NULL,
    Cantidad_Contada  NUMBER(10)   NOT NULL,
    CONSTRAINT PR_PK_EXA PRIMARY KEY (ID_Examen),
    CONSTRAINT PR_FK_EXA_OPE FOREIGN KEY (RUT_Operario)
        REFERENCES PR_Operario (RUT_Operario),
    CONSTRAINT PR_FK_EXA_PRO FOREIGN KEY (ID_Producto)
        REFERENCES PR_Producto (ID_Producto),
    CONSTRAINT PR_FK_EXA_UBI FOREIGN KEY (ID_Ubicacion)
        REFERENCES PR_Ubicacion_Estante (ID_Ubicacion),
    CONSTRAINT PR_CK_EXA_CANT CHECK (Cantidad_Contada >= 0)
);

-- Cuanto hay de cada producto en cada estante.
CREATE TABLE PR_Producto_Ubicacion (
    ID_Producto   NUMBER(10) NOT NULL,
    ID_Ubicacion  NUMBER(10) NOT NULL,
    Cantidad      NUMBER(10) DEFAULT 0 NOT NULL,
    CONSTRAINT PR_PK_PUB PRIMARY KEY (ID_Producto, ID_Ubicacion),
    CONSTRAINT PR_FK_PUB_PRO FOREIGN KEY (ID_Producto)
        REFERENCES PR_Producto (ID_Producto),
    CONSTRAINT PR_FK_PUB_UBI FOREIGN KEY (ID_Ubicacion)
        REFERENCES PR_Ubicacion_Estante (ID_Ubicacion),
    CONSTRAINT PR_CK_PUB_CANT CHECK (Cantidad >= 0)
);


-- =====================================================================
-- 7. VISTAS (reemplazan a los datos derivados que no se guardan)
-- =====================================================================

-- Stock de cada producto = entradas - salidas (Stock_Actual).
-- Stock_En_Estantes = suma de PR_Producto_Ubicacion. Si ambos no coinciden
-- (columna Descuadre = 'SI') hay un error de registro que revisar.
CREATE OR REPLACE VIEW PR_V_Stock_Producto AS
SELECT s.ID_Producto,
       s.Nombre_Producto,
       s.Stock_Minimo,
       s.Stock_Actual,
       NVL((SELECT SUM(pu.Cantidad)
              FROM PR_Producto_Ubicacion pu
             WHERE pu.ID_Producto = s.ID_Producto), 0) AS Stock_En_Estantes,
       CASE WHEN s.Stock_Actual <= s.Stock_Minimo THEN 'SI' ELSE 'NO' END
           AS Requiere_Reposicion,
       CASE WHEN s.Stock_Actual <>
                 NVL((SELECT SUM(pu.Cantidad)
                        FROM PR_Producto_Ubicacion pu
                       WHERE pu.ID_Producto = s.ID_Producto), 0)
            THEN 'SI' ELSE 'NO' END AS Descuadre
FROM (
    SELECT p.ID_Producto,
           p.Nombre_Producto,
           p.Stock_Minimo,
           NVL(SUM(CASE m.Tipo_Movimiento
                       WHEN 'ENTRADA' THEN  m.Cantidad_Afectada
                       WHEN 'SALIDA'  THEN -m.Cantidad_Afectada
                   END), 0) AS Stock_Actual
    FROM   PR_Producto p
    LEFT JOIN PR_Movimiento_Stock m
           ON m.ID_Producto = p.ID_Producto
    GROUP BY p.ID_Producto, p.Nombre_Producto, p.Stock_Minimo
) s;

-- Monto total de cada orden de compra = suma de (costo x cantidad).
CREATE OR REPLACE VIEW PR_V_Orden_Total AS
SELECT o.Nro_Orden,
       o.Fecha_Emision,
       o.Estado_Orden,
       o.Metodo_Pago,
       o.RUT_Proveedor,
       NVL(SUM(d.Costo_Unitario * d.Cantidad_Solicitada), 0) AS Monto_Total
FROM   PR_Orden_Compra o
LEFT JOIN PR_Detalle_Compra d
       ON d.Nro_Orden = o.Nro_Orden
GROUP BY o.Nro_Orden, o.Fecha_Emision, o.Estado_Orden,
         o.Metodo_Pago, o.RUT_Proveedor;

-- Bodega con su direccion como objeto (usa el tipo PR_T_Direccion).
CREATE OR REPLACE VIEW PR_V_Bodega_Direccion AS
SELECT b.ID_Bodega,
       b.Nombre_Recinto,
       PR_T_Direccion(b.Calle, b.Numero, b.Comuna)         AS Direccion,
       PR_T_Direccion(b.Calle, b.Numero, b.Comuna).Texto() AS Direccion_Texto
FROM   PR_Bodega b;


-- =====================================================================
-- 8. REGLAS ADICIONALES DE CALIDAD DE DATOS
-- =====================================================================
-- Nombres unicos sin distinguir mayusculas (Razer = RAZER = razer)
CREATE UNIQUE INDEX PR_UX_MAR_NOMBRE  ON PR_Marca     (UPPER(Nombre_Marca));
CREATE UNIQUE INDEX PR_UX_CAT_NOMBRE  ON PR_Categoria (UPPER(Nombre_Categoria));
CREATE UNIQUE INDEX PR_UX_PAI_NOMBRE  ON PR_Pais      (UPPER(Nombre_Pais));
CREATE UNIQUE INDEX PR_UX_TUR_NOMBRE  ON PR_Turno     (UPPER(Nombre_Turno));
CREATE UNIQUE INDEX PR_UX_ROL_NOMBRE  ON PR_Rol       (UPPER(Nombre_Rol));
CREATE UNIQUE INDEX PR_UX_USU_NOMBRE  ON PR_Usuario   (UPPER(Nombre_Usuario));
CREATE UNIQUE INDEX PR_UX_PRO_NOM_MAR ON PR_Producto  (UPPER(Nombre_Producto), ID_Marca);

-- Horario del turno: formato HH:MM-HH:MM con horas validas (00:00 a 23:59)
ALTER TABLE PR_Turno ADD CONSTRAINT PR_CK_TUR_HORARIO
  CHECK (REGEXP_LIKE(Horario_Turno,
         '^([01][0-9]|2[0-3]):[0-5][0-9]-([01][0-9]|2[0-3]):[0-5][0-9]$'));

-- Nombres sin numeros en Marca, Categoria, Pais y Rol
ALTER TABLE PR_Marca     ADD CONSTRAINT PR_CK_MAR_LETRAS
  CHECK (REGEXP_LIKE(Nombre_Marca,     '^[[:alpha:]][[:alpha:] .&-]*$'));
ALTER TABLE PR_Categoria ADD CONSTRAINT PR_CK_CAT_LETRAS
  CHECK (REGEXP_LIKE(Nombre_Categoria, '^[[:alpha:]][[:alpha:] .&-]*$'));
ALTER TABLE PR_Pais      ADD CONSTRAINT PR_CK_PAI_LETRAS
  CHECK (REGEXP_LIKE(Nombre_Pais,      '^[[:alpha:]][[:alpha:] .&-]*$'));
ALTER TABLE PR_Rol       ADD CONSTRAINT PR_CK_ROL_LETRAS
  CHECK (REGEXP_LIKE(Nombre_Rol,       '^[[:alpha:]][[:alpha:] .&-]*$'));


-- =====================================================================
-- 9. TRIGGERS DE FORMATO (REDRAGON -> Redragon, sin espacios de mas)
-- =====================================================================
CREATE OR REPLACE TRIGGER PR_TRG_MARCA_NOMBRE
BEFORE INSERT OR UPDATE OF Nombre_Marca ON PR_Marca
FOR EACH ROW
BEGIN
    :NEW.Nombre_Marca := INITCAP(REGEXP_REPLACE(TRIM(:NEW.Nombre_Marca), ' +', ' '));
END;
/

CREATE OR REPLACE TRIGGER PR_TRG_CATEGORIA_NOMBRE
BEFORE INSERT OR UPDATE OF Nombre_Categoria ON PR_Categoria
FOR EACH ROW
BEGIN
    :NEW.Nombre_Categoria := INITCAP(REGEXP_REPLACE(TRIM(:NEW.Nombre_Categoria), ' +', ' '));
END;
/

CREATE OR REPLACE TRIGGER PR_TRG_PAIS_NOMBRE
BEFORE INSERT OR UPDATE OF Nombre_Pais ON PR_Pais
FOR EACH ROW
BEGIN
    :NEW.Nombre_Pais := INITCAP(REGEXP_REPLACE(TRIM(:NEW.Nombre_Pais), ' +', ' '));
END;
/

CREATE OR REPLACE TRIGGER PR_TRG_PRODUCTO_NOMBRE
BEFORE INSERT OR UPDATE OF Nombre_Producto ON PR_Producto
FOR EACH ROW
BEGIN
    :NEW.Nombre_Producto := INITCAP(REGEXP_REPLACE(TRIM(:NEW.Nombre_Producto), ' +', ' '));
END;
/

-- Horario: acepta "08001600", "08:00 - 16:00", "08.00-16.00"... y lo deja "08:00-16:00"
CREATE OR REPLACE TRIGGER PR_TRG_TURNO_FORMATO
BEFORE INSERT OR UPDATE OF Nombre_Turno, Horario_Turno, Supervisor_Turno ON PR_Turno
FOR EACH ROW
DECLARE
    v_dig VARCHAR2(40);
BEGIN
    :NEW.Nombre_Turno     := INITCAP(REGEXP_REPLACE(TRIM(:NEW.Nombre_Turno),     ' +', ' '));
    :NEW.Supervisor_Turno := INITCAP(REGEXP_REPLACE(TRIM(:NEW.Supervisor_Turno), ' +', ' '));
    v_dig := REGEXP_REPLACE(:NEW.Horario_Turno, '[^0-9]', '');
    IF LENGTH(v_dig) = 8 THEN
        :NEW.Horario_Turno := SUBSTR(v_dig, 1, 2) || ':' || SUBSTR(v_dig, 3, 2) || '-' ||
                              SUBSTR(v_dig, 5, 2) || ':' || SUBSTR(v_dig, 7, 2);
    END IF;
END;
/

CREATE OR REPLACE TRIGGER PR_TRG_OPERARIO_NOMBRE
BEFORE INSERT OR UPDATE OF Nombres, Apellidos ON PR_Operario
FOR EACH ROW
BEGIN
    :NEW.Nombres   := INITCAP(REGEXP_REPLACE(TRIM(:NEW.Nombres),   ' +', ' '));
    :NEW.Apellidos := INITCAP(REGEXP_REPLACE(TRIM(:NEW.Apellidos), ' +', ' '));
END;
/


-- =====================================================================
-- 10. LOGIN (la contrasena la verifica PHP con password_verify)
-- =====================================================================
CREATE OR REPLACE PROCEDURE PR_SP_OBTENER_USUARIO (
    p_nombre  IN  VARCHAR2,
    p_id      OUT NUMBER,
    p_hash    OUT VARCHAR2,
    p_rol     OUT VARCHAR2,
    p_activo  OUT VARCHAR2
) AS
BEGIN
    SELECT u.ID_Usuario, u.Password_Hash, r.Nombre_Rol, u.Activo
      INTO p_id, p_hash, p_rol, p_activo
      FROM PR_Usuario u
      JOIN PR_Rol r ON r.ID_Rol = u.ID_Rol
     WHERE u.Nombre_Usuario = p_nombre;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        p_id := NULL; p_hash := NULL; p_rol := NULL; p_activo := NULL;
END;
/

-- =====================================================================
-- 11. MANTENEDORES (CRUD) - 11 tablas, cada uno con INSERTAR / LISTAR (cursor) /
--     ACTUALIZAR / ELIMINAR
-- =====================================================================
-- ---------- PR_Marca ----------
CREATE OR REPLACE PROCEDURE PR_SP_MARCA_INSERTAR (
    p_nombre_marca IN VARCHAR2,
    p_id OUT NUMBER
) AS
BEGIN
    INSERT INTO PR_Marca (Nombre_Marca)
    VALUES (TRIM(p_nombre_marca))
    RETURNING ID_Marca INTO p_id;
    COMMIT;
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20010, 'Ya existe un registro con esos datos (valor duplicado)');
    WHEN OTHERS THEN
        ROLLBACK;
        IF SQLCODE = -2291 THEN
            RAISE_APPLICATION_ERROR(-20013, 'Referencia inexistente: revise los datos relacionados');
        ELSIF SQLCODE = -2290 THEN
            RAISE_APPLICATION_ERROR(-20014, 'Valor fuera del rango permitido');
        ELSIF SQLCODE = -2292 THEN
            RAISE_APPLICATION_ERROR(-20012, 'No se puede eliminar: tiene registros relacionados');
        ELSE
            RAISE;
        END IF;
END;
/

CREATE OR REPLACE PROCEDURE PR_SP_MARCA_LISTAR (
    p_cursor OUT SYS_REFCURSOR
) AS
BEGIN
    OPEN p_cursor FOR
        SELECT ID_Marca, Nombre_Marca
          FROM PR_Marca
         ORDER BY ID_Marca;
END;
/

CREATE OR REPLACE PROCEDURE PR_SP_MARCA_ACTUALIZAR (
    p_id_marca IN NUMBER,
    p_nombre_marca IN VARCHAR2
) AS
BEGIN
    UPDATE PR_Marca
       SET Nombre_Marca = TRIM(p_nombre_marca)
     WHERE ID_Marca = p_id_marca;
    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20011, 'El registro no existe');
    END IF;
    COMMIT;
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20010, 'Ya existe un registro con esos datos (valor duplicado)');
    WHEN OTHERS THEN
        ROLLBACK;
        IF SQLCODE = -2291 THEN
            RAISE_APPLICATION_ERROR(-20013, 'Referencia inexistente: revise los datos relacionados');
        ELSIF SQLCODE = -2290 THEN
            RAISE_APPLICATION_ERROR(-20014, 'Valor fuera del rango permitido');
        ELSIF SQLCODE = -2292 THEN
            RAISE_APPLICATION_ERROR(-20012, 'No se puede eliminar: tiene registros relacionados');
        ELSE
            RAISE;
        END IF;
END;
/

CREATE OR REPLACE PROCEDURE PR_SP_MARCA_ELIMINAR (
    p_id_marca IN NUMBER
) AS
BEGIN
    DELETE FROM PR_Marca WHERE ID_Marca = p_id_marca;
    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20011, 'El registro no existe');
    END IF;
    COMMIT;
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20010, 'Ya existe un registro con esos datos (valor duplicado)');
    WHEN OTHERS THEN
        ROLLBACK;
        IF SQLCODE = -2291 THEN
            RAISE_APPLICATION_ERROR(-20013, 'Referencia inexistente: revise los datos relacionados');
        ELSIF SQLCODE = -2290 THEN
            RAISE_APPLICATION_ERROR(-20014, 'Valor fuera del rango permitido');
        ELSIF SQLCODE = -2292 THEN
            RAISE_APPLICATION_ERROR(-20012, 'No se puede eliminar: tiene registros relacionados');
        ELSE
            RAISE;
        END IF;
END;
/

-- ---------- PR_Categoria ----------
CREATE OR REPLACE PROCEDURE PR_SP_CATEGORIA_INSERTAR (
    p_nombre_categoria IN VARCHAR2,
    p_id OUT NUMBER
) AS
BEGIN
    INSERT INTO PR_Categoria (Nombre_Categoria)
    VALUES (TRIM(p_nombre_categoria))
    RETURNING ID_Categoria INTO p_id;
    COMMIT;
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20010, 'Ya existe un registro con esos datos (valor duplicado)');
    WHEN OTHERS THEN
        ROLLBACK;
        IF SQLCODE = -2291 THEN
            RAISE_APPLICATION_ERROR(-20013, 'Referencia inexistente: revise los datos relacionados');
        ELSIF SQLCODE = -2290 THEN
            RAISE_APPLICATION_ERROR(-20014, 'Valor fuera del rango permitido');
        ELSIF SQLCODE = -2292 THEN
            RAISE_APPLICATION_ERROR(-20012, 'No se puede eliminar: tiene registros relacionados');
        ELSE
            RAISE;
        END IF;
END;
/

CREATE OR REPLACE PROCEDURE PR_SP_CATEGORIA_LISTAR (
    p_cursor OUT SYS_REFCURSOR
) AS
BEGIN
    OPEN p_cursor FOR
        SELECT ID_Categoria, Nombre_Categoria
          FROM PR_Categoria
         ORDER BY ID_Categoria;
END;
/

CREATE OR REPLACE PROCEDURE PR_SP_CATEGORIA_ACTUALIZAR (
    p_id_categoria IN NUMBER,
    p_nombre_categoria IN VARCHAR2
) AS
BEGIN
    UPDATE PR_Categoria
       SET Nombre_Categoria = TRIM(p_nombre_categoria)
     WHERE ID_Categoria = p_id_categoria;
    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20011, 'El registro no existe');
    END IF;
    COMMIT;
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20010, 'Ya existe un registro con esos datos (valor duplicado)');
    WHEN OTHERS THEN
        ROLLBACK;
        IF SQLCODE = -2291 THEN
            RAISE_APPLICATION_ERROR(-20013, 'Referencia inexistente: revise los datos relacionados');
        ELSIF SQLCODE = -2290 THEN
            RAISE_APPLICATION_ERROR(-20014, 'Valor fuera del rango permitido');
        ELSIF SQLCODE = -2292 THEN
            RAISE_APPLICATION_ERROR(-20012, 'No se puede eliminar: tiene registros relacionados');
        ELSE
            RAISE;
        END IF;
END;
/

CREATE OR REPLACE PROCEDURE PR_SP_CATEGORIA_ELIMINAR (
    p_id_categoria IN NUMBER
) AS
BEGIN
    DELETE FROM PR_Categoria WHERE ID_Categoria = p_id_categoria;
    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20011, 'El registro no existe');
    END IF;
    COMMIT;
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20010, 'Ya existe un registro con esos datos (valor duplicado)');
    WHEN OTHERS THEN
        ROLLBACK;
        IF SQLCODE = -2291 THEN
            RAISE_APPLICATION_ERROR(-20013, 'Referencia inexistente: revise los datos relacionados');
        ELSIF SQLCODE = -2290 THEN
            RAISE_APPLICATION_ERROR(-20014, 'Valor fuera del rango permitido');
        ELSIF SQLCODE = -2292 THEN
            RAISE_APPLICATION_ERROR(-20012, 'No se puede eliminar: tiene registros relacionados');
        ELSE
            RAISE;
        END IF;
END;
/

-- ---------- PR_Pais ----------
CREATE OR REPLACE PROCEDURE PR_SP_PAIS_INSERTAR (
    p_nombre_pais IN VARCHAR2,
    p_id OUT NUMBER
) AS
BEGIN
    INSERT INTO PR_Pais (Nombre_Pais)
    VALUES (TRIM(p_nombre_pais))
    RETURNING ID_Pais INTO p_id;
    COMMIT;
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20010, 'Ya existe un registro con esos datos (valor duplicado)');
    WHEN OTHERS THEN
        ROLLBACK;
        IF SQLCODE = -2291 THEN
            RAISE_APPLICATION_ERROR(-20013, 'Referencia inexistente: revise los datos relacionados');
        ELSIF SQLCODE = -2290 THEN
            RAISE_APPLICATION_ERROR(-20014, 'Valor fuera del rango permitido');
        ELSIF SQLCODE = -2292 THEN
            RAISE_APPLICATION_ERROR(-20012, 'No se puede eliminar: tiene registros relacionados');
        ELSE
            RAISE;
        END IF;
END;
/

CREATE OR REPLACE PROCEDURE PR_SP_PAIS_LISTAR (
    p_cursor OUT SYS_REFCURSOR
) AS
BEGIN
    OPEN p_cursor FOR
        SELECT ID_Pais, Nombre_Pais
          FROM PR_Pais
         ORDER BY ID_Pais;
END;
/

CREATE OR REPLACE PROCEDURE PR_SP_PAIS_ACTUALIZAR (
    p_id_pais IN NUMBER,
    p_nombre_pais IN VARCHAR2
) AS
BEGIN
    UPDATE PR_Pais
       SET Nombre_Pais = TRIM(p_nombre_pais)
     WHERE ID_Pais = p_id_pais;
    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20011, 'El registro no existe');
    END IF;
    COMMIT;
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20010, 'Ya existe un registro con esos datos (valor duplicado)');
    WHEN OTHERS THEN
        ROLLBACK;
        IF SQLCODE = -2291 THEN
            RAISE_APPLICATION_ERROR(-20013, 'Referencia inexistente: revise los datos relacionados');
        ELSIF SQLCODE = -2290 THEN
            RAISE_APPLICATION_ERROR(-20014, 'Valor fuera del rango permitido');
        ELSIF SQLCODE = -2292 THEN
            RAISE_APPLICATION_ERROR(-20012, 'No se puede eliminar: tiene registros relacionados');
        ELSE
            RAISE;
        END IF;
END;
/

CREATE OR REPLACE PROCEDURE PR_SP_PAIS_ELIMINAR (
    p_id_pais IN NUMBER
) AS
BEGIN
    DELETE FROM PR_Pais WHERE ID_Pais = p_id_pais;
    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20011, 'El registro no existe');
    END IF;
    COMMIT;
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20010, 'Ya existe un registro con esos datos (valor duplicado)');
    WHEN OTHERS THEN
        ROLLBACK;
        IF SQLCODE = -2291 THEN
            RAISE_APPLICATION_ERROR(-20013, 'Referencia inexistente: revise los datos relacionados');
        ELSIF SQLCODE = -2290 THEN
            RAISE_APPLICATION_ERROR(-20014, 'Valor fuera del rango permitido');
        ELSIF SQLCODE = -2292 THEN
            RAISE_APPLICATION_ERROR(-20012, 'No se puede eliminar: tiene registros relacionados');
        ELSE
            RAISE;
        END IF;
END;
/

-- ---------- PR_Turno ----------
CREATE OR REPLACE PROCEDURE PR_SP_TURNO_INSERTAR (
    p_nombre_turno IN VARCHAR2,
    p_horario_turno IN VARCHAR2,
    p_supervisor_turno IN VARCHAR2,
    p_id OUT NUMBER
) AS
BEGIN
    INSERT INTO PR_Turno (Nombre_Turno, Horario_Turno, Supervisor_Turno)
    VALUES (TRIM(p_nombre_turno), p_horario_turno, TRIM(p_supervisor_turno))
    RETURNING ID_Turno INTO p_id;
    COMMIT;
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20010, 'Ya existe un registro con esos datos (valor duplicado)');
    WHEN OTHERS THEN
        ROLLBACK;
        IF SQLCODE = -2291 THEN
            RAISE_APPLICATION_ERROR(-20013, 'Referencia inexistente: revise los datos relacionados');
        ELSIF SQLCODE = -2290 THEN
            RAISE_APPLICATION_ERROR(-20014, 'Valor fuera del rango permitido');
        ELSIF SQLCODE = -2292 THEN
            RAISE_APPLICATION_ERROR(-20012, 'No se puede eliminar: tiene registros relacionados');
        ELSE
            RAISE;
        END IF;
END;
/

CREATE OR REPLACE PROCEDURE PR_SP_TURNO_LISTAR (
    p_cursor OUT SYS_REFCURSOR
) AS
BEGIN
    OPEN p_cursor FOR
        SELECT ID_Turno, Nombre_Turno, Horario_Turno, Supervisor_Turno
          FROM PR_Turno
         ORDER BY ID_Turno;
END;
/

CREATE OR REPLACE PROCEDURE PR_SP_TURNO_ACTUALIZAR (
    p_id_turno IN NUMBER,
    p_nombre_turno IN VARCHAR2,
    p_horario_turno IN VARCHAR2,
    p_supervisor_turno IN VARCHAR2
) AS
BEGIN
    UPDATE PR_Turno
       SET Nombre_Turno = TRIM(p_nombre_turno),
           Horario_Turno = p_horario_turno,
           Supervisor_Turno = TRIM(p_supervisor_turno)
     WHERE ID_Turno = p_id_turno;
    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20011, 'El registro no existe');
    END IF;
    COMMIT;
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20010, 'Ya existe un registro con esos datos (valor duplicado)');
    WHEN OTHERS THEN
        ROLLBACK;
        IF SQLCODE = -2291 THEN
            RAISE_APPLICATION_ERROR(-20013, 'Referencia inexistente: revise los datos relacionados');
        ELSIF SQLCODE = -2290 THEN
            RAISE_APPLICATION_ERROR(-20014, 'Valor fuera del rango permitido');
        ELSIF SQLCODE = -2292 THEN
            RAISE_APPLICATION_ERROR(-20012, 'No se puede eliminar: tiene registros relacionados');
        ELSE
            RAISE;
        END IF;
END;
/

CREATE OR REPLACE PROCEDURE PR_SP_TURNO_ELIMINAR (
    p_id_turno IN NUMBER
) AS
BEGIN
    DELETE FROM PR_Turno WHERE ID_Turno = p_id_turno;
    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20011, 'El registro no existe');
    END IF;
    COMMIT;
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20010, 'Ya existe un registro con esos datos (valor duplicado)');
    WHEN OTHERS THEN
        ROLLBACK;
        IF SQLCODE = -2291 THEN
            RAISE_APPLICATION_ERROR(-20013, 'Referencia inexistente: revise los datos relacionados');
        ELSIF SQLCODE = -2290 THEN
            RAISE_APPLICATION_ERROR(-20014, 'Valor fuera del rango permitido');
        ELSIF SQLCODE = -2292 THEN
            RAISE_APPLICATION_ERROR(-20012, 'No se puede eliminar: tiene registros relacionados');
        ELSE
            RAISE;
        END IF;
END;
/

-- ---------- PR_Rol ----------
CREATE OR REPLACE PROCEDURE PR_SP_ROL_INSERTAR (
    p_nombre_rol IN VARCHAR2,
    p_id OUT NUMBER
) AS
BEGIN
    INSERT INTO PR_Rol (Nombre_Rol)
    VALUES (TRIM(p_nombre_rol))
    RETURNING ID_Rol INTO p_id;
    COMMIT;
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20010, 'Ya existe un registro con esos datos (valor duplicado)');
    WHEN OTHERS THEN
        ROLLBACK;
        IF SQLCODE = -2291 THEN
            RAISE_APPLICATION_ERROR(-20013, 'Referencia inexistente: revise los datos relacionados');
        ELSIF SQLCODE = -2290 THEN
            RAISE_APPLICATION_ERROR(-20014, 'Valor fuera del rango permitido');
        ELSIF SQLCODE = -2292 THEN
            RAISE_APPLICATION_ERROR(-20012, 'No se puede eliminar: tiene registros relacionados');
        ELSE
            RAISE;
        END IF;
END;
/

CREATE OR REPLACE PROCEDURE PR_SP_ROL_LISTAR (
    p_cursor OUT SYS_REFCURSOR
) AS
BEGIN
    OPEN p_cursor FOR
        SELECT ID_Rol, Nombre_Rol
          FROM PR_Rol
         ORDER BY ID_Rol;
END;
/

CREATE OR REPLACE PROCEDURE PR_SP_ROL_ACTUALIZAR (
    p_id_rol IN NUMBER,
    p_nombre_rol IN VARCHAR2
) AS
BEGIN
    UPDATE PR_Rol
       SET Nombre_Rol = TRIM(p_nombre_rol)
     WHERE ID_Rol = p_id_rol;
    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20011, 'El registro no existe');
    END IF;
    COMMIT;
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20010, 'Ya existe un registro con esos datos (valor duplicado)');
    WHEN OTHERS THEN
        ROLLBACK;
        IF SQLCODE = -2291 THEN
            RAISE_APPLICATION_ERROR(-20013, 'Referencia inexistente: revise los datos relacionados');
        ELSIF SQLCODE = -2290 THEN
            RAISE_APPLICATION_ERROR(-20014, 'Valor fuera del rango permitido');
        ELSIF SQLCODE = -2292 THEN
            RAISE_APPLICATION_ERROR(-20012, 'No se puede eliminar: tiene registros relacionados');
        ELSE
            RAISE;
        END IF;
END;
/

CREATE OR REPLACE PROCEDURE PR_SP_ROL_ELIMINAR (
    p_id_rol IN NUMBER
) AS
BEGIN
    DELETE FROM PR_Rol WHERE ID_Rol = p_id_rol;
    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20011, 'El registro no existe');
    END IF;
    COMMIT;
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20010, 'Ya existe un registro con esos datos (valor duplicado)');
    WHEN OTHERS THEN
        ROLLBACK;
        IF SQLCODE = -2291 THEN
            RAISE_APPLICATION_ERROR(-20013, 'Referencia inexistente: revise los datos relacionados');
        ELSIF SQLCODE = -2290 THEN
            RAISE_APPLICATION_ERROR(-20014, 'Valor fuera del rango permitido');
        ELSIF SQLCODE = -2292 THEN
            RAISE_APPLICATION_ERROR(-20012, 'No se puede eliminar: tiene registros relacionados');
        ELSE
            RAISE;
        END IF;
END;
/

-- ---------- PR_Bodega ----------
CREATE OR REPLACE PROCEDURE PR_SP_BODEGA_INSERTAR (
    p_nombre_recinto IN VARCHAR2,
    p_calle IN VARCHAR2,
    p_numero IN NUMBER,
    p_comuna IN VARCHAR2,
    p_id OUT NUMBER
) AS
BEGIN
    INSERT INTO PR_Bodega (Nombre_Recinto, Calle, Numero, Comuna)
    VALUES (TRIM(p_nombre_recinto), TRIM(p_calle), p_numero, TRIM(p_comuna))
    RETURNING ID_Bodega INTO p_id;
    COMMIT;
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20010, 'Ya existe un registro con esos datos (valor duplicado)');
    WHEN OTHERS THEN
        ROLLBACK;
        IF SQLCODE = -2291 THEN
            RAISE_APPLICATION_ERROR(-20013, 'Referencia inexistente: revise los datos relacionados');
        ELSIF SQLCODE = -2290 THEN
            RAISE_APPLICATION_ERROR(-20014, 'Valor fuera del rango permitido');
        ELSIF SQLCODE = -2292 THEN
            RAISE_APPLICATION_ERROR(-20012, 'No se puede eliminar: tiene registros relacionados');
        ELSE
            RAISE;
        END IF;
END;
/

CREATE OR REPLACE PROCEDURE PR_SP_BODEGA_LISTAR (
    p_cursor OUT SYS_REFCURSOR
) AS
BEGIN
    OPEN p_cursor FOR
        SELECT ID_Bodega, Nombre_Recinto, Calle, Numero, Comuna
          FROM PR_Bodega
         ORDER BY ID_Bodega;
END;
/

CREATE OR REPLACE PROCEDURE PR_SP_BODEGA_ACTUALIZAR (
    p_id_bodega IN NUMBER,
    p_nombre_recinto IN VARCHAR2,
    p_calle IN VARCHAR2,
    p_numero IN NUMBER,
    p_comuna IN VARCHAR2
) AS
BEGIN
    UPDATE PR_Bodega
       SET Nombre_Recinto = TRIM(p_nombre_recinto),
           Calle = TRIM(p_calle),
           Numero = p_numero,
           Comuna = TRIM(p_comuna)
     WHERE ID_Bodega = p_id_bodega;
    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20011, 'El registro no existe');
    END IF;
    COMMIT;
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20010, 'Ya existe un registro con esos datos (valor duplicado)');
    WHEN OTHERS THEN
        ROLLBACK;
        IF SQLCODE = -2291 THEN
            RAISE_APPLICATION_ERROR(-20013, 'Referencia inexistente: revise los datos relacionados');
        ELSIF SQLCODE = -2290 THEN
            RAISE_APPLICATION_ERROR(-20014, 'Valor fuera del rango permitido');
        ELSIF SQLCODE = -2292 THEN
            RAISE_APPLICATION_ERROR(-20012, 'No se puede eliminar: tiene registros relacionados');
        ELSE
            RAISE;
        END IF;
END;
/

CREATE OR REPLACE PROCEDURE PR_SP_BODEGA_ELIMINAR (
    p_id_bodega IN NUMBER
) AS
BEGIN
    DELETE FROM PR_Bodega WHERE ID_Bodega = p_id_bodega;
    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20011, 'El registro no existe');
    END IF;
    COMMIT;
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20010, 'Ya existe un registro con esos datos (valor duplicado)');
    WHEN OTHERS THEN
        ROLLBACK;
        IF SQLCODE = -2291 THEN
            RAISE_APPLICATION_ERROR(-20013, 'Referencia inexistente: revise los datos relacionados');
        ELSIF SQLCODE = -2290 THEN
            RAISE_APPLICATION_ERROR(-20014, 'Valor fuera del rango permitido');
        ELSIF SQLCODE = -2292 THEN
            RAISE_APPLICATION_ERROR(-20012, 'No se puede eliminar: tiene registros relacionados');
        ELSE
            RAISE;
        END IF;
END;
/

-- ---------- PR_Ubicacion_Estante ----------
CREATE OR REPLACE PROCEDURE PR_SP_UBICACION_INSERTAR (
    p_pasillo IN NUMBER,
    p_nivel IN NUMBER,
    p_id_bodega IN NUMBER,
    p_id OUT NUMBER
) AS
BEGIN
    INSERT INTO PR_Ubicacion_Estante (Pasillo, Nivel, ID_Bodega)
    VALUES (p_pasillo, p_nivel, p_id_bodega)
    RETURNING ID_Ubicacion INTO p_id;
    COMMIT;
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20010, 'Ya existe un registro con esos datos (valor duplicado)');
    WHEN OTHERS THEN
        ROLLBACK;
        IF SQLCODE = -2291 THEN
            RAISE_APPLICATION_ERROR(-20013, 'Referencia inexistente: revise los datos relacionados');
        ELSIF SQLCODE = -2290 THEN
            RAISE_APPLICATION_ERROR(-20014, 'Valor fuera del rango permitido');
        ELSIF SQLCODE = -2292 THEN
            RAISE_APPLICATION_ERROR(-20012, 'No se puede eliminar: tiene registros relacionados');
        ELSE
            RAISE;
        END IF;
END;
/

CREATE OR REPLACE PROCEDURE PR_SP_UBICACION_LISTAR (
    p_cursor OUT SYS_REFCURSOR
) AS
BEGIN
    OPEN p_cursor FOR
        SELECT ID_Ubicacion, Pasillo, Nivel, ID_Bodega
          FROM PR_Ubicacion_Estante
         ORDER BY ID_Ubicacion;
END;
/

CREATE OR REPLACE PROCEDURE PR_SP_UBICACION_ACTUALIZAR (
    p_id_ubicacion IN NUMBER,
    p_pasillo IN NUMBER,
    p_nivel IN NUMBER,
    p_id_bodega IN NUMBER
) AS
BEGIN
    UPDATE PR_Ubicacion_Estante
       SET Pasillo = p_pasillo,
           Nivel = p_nivel,
           ID_Bodega = p_id_bodega
     WHERE ID_Ubicacion = p_id_ubicacion;
    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20011, 'El registro no existe');
    END IF;
    COMMIT;
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20010, 'Ya existe un registro con esos datos (valor duplicado)');
    WHEN OTHERS THEN
        ROLLBACK;
        IF SQLCODE = -2291 THEN
            RAISE_APPLICATION_ERROR(-20013, 'Referencia inexistente: revise los datos relacionados');
        ELSIF SQLCODE = -2290 THEN
            RAISE_APPLICATION_ERROR(-20014, 'Valor fuera del rango permitido');
        ELSIF SQLCODE = -2292 THEN
            RAISE_APPLICATION_ERROR(-20012, 'No se puede eliminar: tiene registros relacionados');
        ELSE
            RAISE;
        END IF;
END;
/

CREATE OR REPLACE PROCEDURE PR_SP_UBICACION_ELIMINAR (
    p_id_ubicacion IN NUMBER
) AS
BEGIN
    DELETE FROM PR_Ubicacion_Estante WHERE ID_Ubicacion = p_id_ubicacion;
    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20011, 'El registro no existe');
    END IF;
    COMMIT;
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20010, 'Ya existe un registro con esos datos (valor duplicado)');
    WHEN OTHERS THEN
        ROLLBACK;
        IF SQLCODE = -2291 THEN
            RAISE_APPLICATION_ERROR(-20013, 'Referencia inexistente: revise los datos relacionados');
        ELSIF SQLCODE = -2290 THEN
            RAISE_APPLICATION_ERROR(-20014, 'Valor fuera del rango permitido');
        ELSIF SQLCODE = -2292 THEN
            RAISE_APPLICATION_ERROR(-20012, 'No se puede eliminar: tiene registros relacionados');
        ELSE
            RAISE;
        END IF;
END;
/

-- ---------- PR_Producto ----------
CREATE OR REPLACE PROCEDURE PR_SP_PRODUCTO_INSERTAR (
    p_nombre_producto IN VARCHAR2,
    p_precio_venta IN NUMBER,
    p_stock_minimo IN NUMBER,
    p_id_categoria IN NUMBER,
    p_id_marca IN NUMBER,
    p_id OUT NUMBER
) AS
BEGIN
    INSERT INTO PR_Producto (Nombre_Producto, Precio_Venta, Stock_Minimo, ID_Categoria, ID_Marca)
    VALUES (TRIM(p_nombre_producto), p_precio_venta, p_stock_minimo, p_id_categoria, p_id_marca)
    RETURNING ID_Producto INTO p_id;
    COMMIT;
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20010, 'Ya existe un registro con esos datos (valor duplicado)');
    WHEN OTHERS THEN
        ROLLBACK;
        IF SQLCODE = -2291 THEN
            RAISE_APPLICATION_ERROR(-20013, 'Referencia inexistente: revise los datos relacionados');
        ELSIF SQLCODE = -2290 THEN
            RAISE_APPLICATION_ERROR(-20014, 'Valor fuera del rango permitido');
        ELSIF SQLCODE = -2292 THEN
            RAISE_APPLICATION_ERROR(-20012, 'No se puede eliminar: tiene registros relacionados');
        ELSE
            RAISE;
        END IF;
END;
/

CREATE OR REPLACE PROCEDURE PR_SP_PRODUCTO_LISTAR (
    p_cursor OUT SYS_REFCURSOR
) AS
BEGIN
    OPEN p_cursor FOR
        SELECT ID_Producto, Nombre_Producto, Precio_Venta, Stock_Minimo, ID_Categoria, ID_Marca
          FROM PR_Producto
         ORDER BY ID_Producto;
END;
/

CREATE OR REPLACE PROCEDURE PR_SP_PRODUCTO_ACTUALIZAR (
    p_id_producto IN NUMBER,
    p_nombre_producto IN VARCHAR2,
    p_precio_venta IN NUMBER,
    p_stock_minimo IN NUMBER,
    p_id_categoria IN NUMBER,
    p_id_marca IN NUMBER
) AS
BEGIN
    UPDATE PR_Producto
       SET Nombre_Producto = TRIM(p_nombre_producto),
           Precio_Venta = p_precio_venta,
           Stock_Minimo = p_stock_minimo,
           ID_Categoria = p_id_categoria,
           ID_Marca = p_id_marca
     WHERE ID_Producto = p_id_producto;
    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20011, 'El registro no existe');
    END IF;
    COMMIT;
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20010, 'Ya existe un registro con esos datos (valor duplicado)');
    WHEN OTHERS THEN
        ROLLBACK;
        IF SQLCODE = -2291 THEN
            RAISE_APPLICATION_ERROR(-20013, 'Referencia inexistente: revise los datos relacionados');
        ELSIF SQLCODE = -2290 THEN
            RAISE_APPLICATION_ERROR(-20014, 'Valor fuera del rango permitido');
        ELSIF SQLCODE = -2292 THEN
            RAISE_APPLICATION_ERROR(-20012, 'No se puede eliminar: tiene registros relacionados');
        ELSE
            RAISE;
        END IF;
END;
/

CREATE OR REPLACE PROCEDURE PR_SP_PRODUCTO_ELIMINAR (
    p_id_producto IN NUMBER
) AS
BEGIN
    DELETE FROM PR_Producto WHERE ID_Producto = p_id_producto;
    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20011, 'El registro no existe');
    END IF;
    COMMIT;
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20010, 'Ya existe un registro con esos datos (valor duplicado)');
    WHEN OTHERS THEN
        ROLLBACK;
        IF SQLCODE = -2291 THEN
            RAISE_APPLICATION_ERROR(-20013, 'Referencia inexistente: revise los datos relacionados');
        ELSIF SQLCODE = -2290 THEN
            RAISE_APPLICATION_ERROR(-20014, 'Valor fuera del rango permitido');
        ELSIF SQLCODE = -2292 THEN
            RAISE_APPLICATION_ERROR(-20012, 'No se puede eliminar: tiene registros relacionados');
        ELSE
            RAISE;
        END IF;
END;
/

-- ---------- PR_Proveedor ----------
CREATE OR REPLACE PROCEDURE PR_SP_PROVEEDOR_INSERTAR (
    p_rut_proveedor IN VARCHAR2,
    p_nombre_empresa IN VARCHAR2,
    p_id_pais IN NUMBER
) AS
BEGIN
    INSERT INTO PR_Proveedor (RUT_Proveedor, Nombre_Empresa, ID_Pais)
    VALUES (p_rut_proveedor, TRIM(p_nombre_empresa), p_id_pais);
    COMMIT;
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20010, 'Ya existe un registro con esos datos (valor duplicado)');
    WHEN OTHERS THEN
        ROLLBACK;
        IF SQLCODE = -2291 THEN
            RAISE_APPLICATION_ERROR(-20013, 'Referencia inexistente: revise los datos relacionados');
        ELSIF SQLCODE = -2290 THEN
            RAISE_APPLICATION_ERROR(-20014, 'Valor fuera del rango permitido');
        ELSIF SQLCODE = -2292 THEN
            RAISE_APPLICATION_ERROR(-20012, 'No se puede eliminar: tiene registros relacionados');
        ELSE
            RAISE;
        END IF;
END;
/

CREATE OR REPLACE PROCEDURE PR_SP_PROVEEDOR_LISTAR (
    p_cursor OUT SYS_REFCURSOR
) AS
BEGIN
    OPEN p_cursor FOR
        SELECT RUT_Proveedor, Nombre_Empresa, ID_Pais
          FROM PR_Proveedor
         ORDER BY RUT_Proveedor;
END;
/

CREATE OR REPLACE PROCEDURE PR_SP_PROVEEDOR_ACTUALIZAR (
    p_rut_proveedor IN VARCHAR2,
    p_nombre_empresa IN VARCHAR2,
    p_id_pais IN NUMBER
) AS
BEGIN
    UPDATE PR_Proveedor
       SET Nombre_Empresa = TRIM(p_nombre_empresa),
           ID_Pais = p_id_pais
     WHERE RUT_Proveedor = p_rut_proveedor;
    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20011, 'El registro no existe');
    END IF;
    COMMIT;
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20010, 'Ya existe un registro con esos datos (valor duplicado)');
    WHEN OTHERS THEN
        ROLLBACK;
        IF SQLCODE = -2291 THEN
            RAISE_APPLICATION_ERROR(-20013, 'Referencia inexistente: revise los datos relacionados');
        ELSIF SQLCODE = -2290 THEN
            RAISE_APPLICATION_ERROR(-20014, 'Valor fuera del rango permitido');
        ELSIF SQLCODE = -2292 THEN
            RAISE_APPLICATION_ERROR(-20012, 'No se puede eliminar: tiene registros relacionados');
        ELSE
            RAISE;
        END IF;
END;
/

CREATE OR REPLACE PROCEDURE PR_SP_PROVEEDOR_ELIMINAR (
    p_rut_proveedor IN VARCHAR2
) AS
BEGIN
    DELETE FROM PR_Proveedor WHERE RUT_Proveedor = p_rut_proveedor;
    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20011, 'El registro no existe');
    END IF;
    COMMIT;
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20010, 'Ya existe un registro con esos datos (valor duplicado)');
    WHEN OTHERS THEN
        ROLLBACK;
        IF SQLCODE = -2291 THEN
            RAISE_APPLICATION_ERROR(-20013, 'Referencia inexistente: revise los datos relacionados');
        ELSIF SQLCODE = -2290 THEN
            RAISE_APPLICATION_ERROR(-20014, 'Valor fuera del rango permitido');
        ELSIF SQLCODE = -2292 THEN
            RAISE_APPLICATION_ERROR(-20012, 'No se puede eliminar: tiene registros relacionados');
        ELSE
            RAISE;
        END IF;
END;
/

-- ---------- PR_Operario ----------
CREATE OR REPLACE PROCEDURE PR_SP_OPERARIO_INSERTAR (
    p_rut_operario IN VARCHAR2,
    p_nombres IN VARCHAR2,
    p_apellidos IN VARCHAR2,
    p_id_turno IN NUMBER
) AS
BEGIN
    INSERT INTO PR_Operario (RUT_Operario, Nombres, Apellidos, ID_Turno)
    VALUES (p_rut_operario, TRIM(p_nombres), TRIM(p_apellidos), p_id_turno);
    COMMIT;
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20010, 'Ya existe un registro con esos datos (valor duplicado)');
    WHEN OTHERS THEN
        ROLLBACK;
        IF SQLCODE = -2291 THEN
            RAISE_APPLICATION_ERROR(-20013, 'Referencia inexistente: revise los datos relacionados');
        ELSIF SQLCODE = -2290 THEN
            RAISE_APPLICATION_ERROR(-20014, 'Valor fuera del rango permitido');
        ELSIF SQLCODE = -2292 THEN
            RAISE_APPLICATION_ERROR(-20012, 'No se puede eliminar: tiene registros relacionados');
        ELSE
            RAISE;
        END IF;
END;
/

CREATE OR REPLACE PROCEDURE PR_SP_OPERARIO_LISTAR (
    p_cursor OUT SYS_REFCURSOR
) AS
BEGIN
    OPEN p_cursor FOR
        SELECT RUT_Operario, Nombres, Apellidos, ID_Turno
          FROM PR_Operario
         ORDER BY RUT_Operario;
END;
/

CREATE OR REPLACE PROCEDURE PR_SP_OPERARIO_ACTUALIZAR (
    p_rut_operario IN VARCHAR2,
    p_nombres IN VARCHAR2,
    p_apellidos IN VARCHAR2,
    p_id_turno IN NUMBER
) AS
BEGIN
    UPDATE PR_Operario
       SET Nombres = TRIM(p_nombres),
           Apellidos = TRIM(p_apellidos),
           ID_Turno = p_id_turno
     WHERE RUT_Operario = p_rut_operario;
    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20011, 'El registro no existe');
    END IF;
    COMMIT;
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20010, 'Ya existe un registro con esos datos (valor duplicado)');
    WHEN OTHERS THEN
        ROLLBACK;
        IF SQLCODE = -2291 THEN
            RAISE_APPLICATION_ERROR(-20013, 'Referencia inexistente: revise los datos relacionados');
        ELSIF SQLCODE = -2290 THEN
            RAISE_APPLICATION_ERROR(-20014, 'Valor fuera del rango permitido');
        ELSIF SQLCODE = -2292 THEN
            RAISE_APPLICATION_ERROR(-20012, 'No se puede eliminar: tiene registros relacionados');
        ELSE
            RAISE;
        END IF;
END;
/

CREATE OR REPLACE PROCEDURE PR_SP_OPERARIO_ELIMINAR (
    p_rut_operario IN VARCHAR2
) AS
BEGIN
    DELETE FROM PR_Operario WHERE RUT_Operario = p_rut_operario;
    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20011, 'El registro no existe');
    END IF;
    COMMIT;
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20010, 'Ya existe un registro con esos datos (valor duplicado)');
    WHEN OTHERS THEN
        ROLLBACK;
        IF SQLCODE = -2291 THEN
            RAISE_APPLICATION_ERROR(-20013, 'Referencia inexistente: revise los datos relacionados');
        ELSIF SQLCODE = -2290 THEN
            RAISE_APPLICATION_ERROR(-20014, 'Valor fuera del rango permitido');
        ELSIF SQLCODE = -2292 THEN
            RAISE_APPLICATION_ERROR(-20012, 'No se puede eliminar: tiene registros relacionados');
        ELSE
            RAISE;
        END IF;
END;
/

-- ---------- PR_Usuario ----------
CREATE OR REPLACE PROCEDURE PR_SP_USUARIO_INSERTAR (
    p_nombre_usuario IN VARCHAR2,
    p_password_hash IN VARCHAR2,
    p_id_rol IN NUMBER,
    p_rut_operario IN VARCHAR2,
    p_activo IN VARCHAR2,
    p_id OUT NUMBER
) AS
BEGIN
    INSERT INTO PR_Usuario (Nombre_Usuario, Password_Hash, ID_Rol, RUT_Operario, Activo)
    VALUES (TRIM(p_nombre_usuario), p_password_hash, p_id_rol, p_rut_operario, p_activo)
    RETURNING ID_Usuario INTO p_id;
    COMMIT;
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20010, 'Ya existe un registro con esos datos (valor duplicado)');
    WHEN OTHERS THEN
        ROLLBACK;
        IF SQLCODE = -2291 THEN
            RAISE_APPLICATION_ERROR(-20013, 'Referencia inexistente: revise los datos relacionados');
        ELSIF SQLCODE = -2290 THEN
            RAISE_APPLICATION_ERROR(-20014, 'Valor fuera del rango permitido');
        ELSIF SQLCODE = -2292 THEN
            RAISE_APPLICATION_ERROR(-20012, 'No se puede eliminar: tiene registros relacionados');
        ELSE
            RAISE;
        END IF;
END;
/

CREATE OR REPLACE PROCEDURE PR_SP_USUARIO_LISTAR (
    p_cursor OUT SYS_REFCURSOR
) AS
BEGIN
    OPEN p_cursor FOR
        SELECT ID_Usuario, Nombre_Usuario, ID_Rol, RUT_Operario, Activo
          FROM PR_Usuario
         ORDER BY ID_Usuario;
END;
/

CREATE OR REPLACE PROCEDURE PR_SP_USUARIO_ACTUALIZAR (
    p_id_usuario IN NUMBER,
    p_nombre_usuario IN VARCHAR2,
    p_id_rol IN NUMBER,
    p_rut_operario IN VARCHAR2,
    p_activo IN VARCHAR2
) AS
BEGIN
    UPDATE PR_Usuario
       SET Nombre_Usuario = TRIM(p_nombre_usuario),
           ID_Rol = p_id_rol,
           RUT_Operario = p_rut_operario,
           Activo = p_activo
     WHERE ID_Usuario = p_id_usuario;
    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20011, 'El registro no existe');
    END IF;
    COMMIT;
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20010, 'Ya existe un registro con esos datos (valor duplicado)');
    WHEN OTHERS THEN
        ROLLBACK;
        IF SQLCODE = -2291 THEN
            RAISE_APPLICATION_ERROR(-20013, 'Referencia inexistente: revise los datos relacionados');
        ELSIF SQLCODE = -2290 THEN
            RAISE_APPLICATION_ERROR(-20014, 'Valor fuera del rango permitido');
        ELSIF SQLCODE = -2292 THEN
            RAISE_APPLICATION_ERROR(-20012, 'No se puede eliminar: tiene registros relacionados');
        ELSE
            RAISE;
        END IF;
END;
/

CREATE OR REPLACE PROCEDURE PR_SP_USUARIO_ELIMINAR (
    p_id_usuario IN NUMBER
) AS
BEGIN
    DELETE FROM PR_Usuario WHERE ID_Usuario = p_id_usuario;
    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20011, 'El registro no existe');
    END IF;
    COMMIT;
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20010, 'Ya existe un registro con esos datos (valor duplicado)');
    WHEN OTHERS THEN
        ROLLBACK;
        IF SQLCODE = -2291 THEN
            RAISE_APPLICATION_ERROR(-20013, 'Referencia inexistente: revise los datos relacionados');
        ELSIF SQLCODE = -2290 THEN
            RAISE_APPLICATION_ERROR(-20014, 'Valor fuera del rango permitido');
        ELSIF SQLCODE = -2292 THEN
            RAISE_APPLICATION_ERROR(-20012, 'No se puede eliminar: tiene registros relacionados');
        ELSE
            RAISE;
        END IF;
END;
/

-- ---------- Usuario: cambiar contrasena ----------
CREATE OR REPLACE PROCEDURE PR_SP_USUARIO_CAMBIAR_CLAVE (
    p_id_usuario    IN NUMBER,
    p_password_hash IN VARCHAR2
) AS
BEGIN
    UPDATE PR_Usuario SET Password_Hash = p_password_hash
     WHERE ID_Usuario = p_id_usuario;
    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20011, 'El registro no existe');
    END IF;
    COMMIT;
END;
/


-- =====================================================================
-- 12. FUNCION DE STOCK, TRIGGER DE MOVIMIENTOS Y GESTOR DE MOVIMIENTOS
-- =====================================================================
-- ---------------------------------------------------------------------
-- 2. FUNCION: stock actual de un producto (usa la vista)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION PR_FN_STOCK_PRODUCTO (
    p_id_producto IN NUMBER
) RETURN NUMBER AS
    v_stock NUMBER;
BEGIN
    SELECT Stock_Actual INTO v_stock
      FROM PR_V_Stock_Producto
     WHERE ID_Producto = p_id_producto;
    RETURN v_stock;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN NULL;
END;
/

-- ---------------------------------------------------------------------
-- 3. TRIGGER: al registrar un movimiento actualiza el estante y genera
--    la alerta de reposicion cuando el stock baja del minimo.
--    (Lee solo PR_Producto_Ubicacion para evitar el error de tabla
--     mutante sobre PR_Movimiento_Stock.)
-- ---------------------------------------------------------------------
CREATE OR REPLACE TRIGGER PR_TRG_MOV_STOCK
AFTER INSERT ON PR_Movimiento_Stock
FOR EACH ROW
DECLARE
    v_actual   NUMBER;
    v_total    NUMBER;
    v_minimo   NUMBER;
    v_pend     NUMBER;
BEGIN
    IF :NEW.Tipo_Movimiento = 'ENTRADA' THEN
        MERGE INTO PR_Producto_Ubicacion pu
        USING (SELECT :NEW.ID_Producto AS idp, :NEW.ID_Ubicacion AS idu FROM dual) s
           ON (pu.ID_Producto = s.idp AND pu.ID_Ubicacion = s.idu)
         WHEN MATCHED THEN
              UPDATE SET pu.Cantidad = pu.Cantidad + :NEW.Cantidad_Afectada
         WHEN NOT MATCHED THEN
              INSERT (ID_Producto, ID_Ubicacion, Cantidad)
              VALUES (s.idp, s.idu, :NEW.Cantidad_Afectada);
    ELSE
        BEGIN
            SELECT Cantidad INTO v_actual
              FROM PR_Producto_Ubicacion
             WHERE ID_Producto = :NEW.ID_Producto
               AND ID_Ubicacion = :NEW.ID_Ubicacion;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN v_actual := 0;
        END;
        IF v_actual < :NEW.Cantidad_Afectada THEN
            RAISE_APPLICATION_ERROR(-20020,
                'Stock insuficiente en el estante: hay ' || v_actual);
        END IF;
        UPDATE PR_Producto_Ubicacion
           SET Cantidad = Cantidad - :NEW.Cantidad_Afectada
         WHERE ID_Producto = :NEW.ID_Producto
           AND ID_Ubicacion = :NEW.ID_Ubicacion;
    END IF;

    SELECT NVL(SUM(Cantidad), 0) INTO v_total
      FROM PR_Producto_Ubicacion WHERE ID_Producto = :NEW.ID_Producto;
    SELECT Stock_Minimo INTO v_minimo
      FROM PR_Producto WHERE ID_Producto = :NEW.ID_Producto;

    IF v_total <= v_minimo THEN
        SELECT COUNT(*) INTO v_pend
          FROM PR_Alerta_Reposicion
         WHERE ID_Producto = :NEW.ID_Producto AND Estado_Alerta = 'PENDIENTE';
        IF v_pend = 0 THEN
            INSERT INTO PR_Alerta_Reposicion (ID_Producto) VALUES (:NEW.ID_Producto);
        END IF;
    END IF;
END;
/

-- ---------------------------------------------------------------------
-- 4. GESTOR: registrar un movimiento de stock
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE PR_SP_REGISTRAR_MOVIMIENTO (
    p_tipo        IN  VARCHAR2,
    p_cantidad    IN  NUMBER,
    p_id_producto IN  NUMBER,
    p_id_ubicacion IN NUMBER,
    p_rut         IN  VARCHAR2,
    p_nro_orden   IN  NUMBER DEFAULT NULL,
    p_id_mov      OUT NUMBER
) AS
BEGIN
    INSERT INTO PR_Movimiento_Stock
        (Tipo_Movimiento, Cantidad_Afectada, ID_Producto, ID_Ubicacion,
         RUT_Operario, Nro_Orden)
    VALUES
        (UPPER(p_tipo), p_cantidad, p_id_producto, p_id_ubicacion,
         p_rut, p_nro_orden)
    RETURNING ID_Movimiento INTO p_id_mov;
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        IF SQLCODE = -2291 THEN
            RAISE_APPLICATION_ERROR(-20013, 'Producto, estante, operario u orden inexistente');
        ELSIF SQLCODE = -2290 THEN
            RAISE_APPLICATION_ERROR(-20014, 'Tipo de movimiento o cantidad no valida');
        ELSE
            RAISE;
        END IF;
END;
/


-- =====================================================================
-- 13-14. GESTORES, REPORTES Y TRIGGERS DE ORDENES
-- =====================================================================
-- ---------------------------------------------------------------------
-- TRIGGERS DE CONTROL SOBRE ORDENES DE COMPRA
-- ---------------------------------------------------------------------
-- Estados permitidos: PENDIENTE -> ENVIADA | CANCELADA
--                     ENVIADA   -> RECIBIDA | CANCELADA
CREATE OR REPLACE TRIGGER PR_TRG_ORDEN_ESTADO
BEFORE UPDATE OF Estado_Orden ON PR_Orden_Compra
FOR EACH ROW
BEGIN
    IF :OLD.Estado_Orden = :NEW.Estado_Orden THEN
        RETURN;
    END IF;
    IF NOT ( (:OLD.Estado_Orden = 'PENDIENTE' AND :NEW.Estado_Orden IN ('ENVIADA', 'CANCELADA'))
          OR (:OLD.Estado_Orden = 'ENVIADA'   AND :NEW.Estado_Orden IN ('RECIBIDA', 'CANCELADA')) ) THEN
        RAISE_APPLICATION_ERROR(-20030,
            'Cambio de estado no permitido: ' || :OLD.Estado_Orden || ' -> ' || :NEW.Estado_Orden);
    END IF;
END;
/

-- Solo se pueden agregar o modificar lineas mientras la orden esta PENDIENTE
CREATE OR REPLACE TRIGGER PR_TRG_DETALLE_PENDIENTE
BEFORE INSERT OR UPDATE ON PR_Detalle_Compra
FOR EACH ROW
DECLARE
    v_estado PR_Orden_Compra.Estado_Orden%TYPE;
BEGIN
    BEGIN
        SELECT Estado_Orden INTO v_estado
          FROM PR_Orden_Compra WHERE Nro_Orden = :NEW.Nro_Orden;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN;   -- la FK informara que la orden no existe
    END;
    IF v_estado <> 'PENDIENTE' THEN
        RAISE_APPLICATION_ERROR(-20031,
            'La orden esta ' || v_estado || ': ya no se pueden modificar sus lineas');
    END IF;
END;
/

-- ---------------------------------------------------------------------
-- GESTOR 1: ORDEN DE COMPRA (crear, agregar lineas, cambiar estado)
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE PR_SP_ORDEN_CREAR (
    p_rut_proveedor IN  VARCHAR2,
    p_metodo_pago   IN  VARCHAR2,
    p_nro           OUT NUMBER
) AS
BEGIN
    INSERT INTO PR_Orden_Compra (Metodo_Pago, RUT_Proveedor)
    VALUES (UPPER(p_metodo_pago), p_rut_proveedor)
    RETURNING Nro_Orden INTO p_nro;
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        IF SQLCODE = -2291 THEN
            RAISE_APPLICATION_ERROR(-20013, 'El proveedor no existe');
        ELSIF SQLCODE = -2290 THEN
            RAISE_APPLICATION_ERROR(-20014, 'Metodo de pago no valido');
        ELSE
            RAISE;
        END IF;
END;
/

CREATE OR REPLACE PROCEDURE PR_SP_ORDEN_AGREGAR_LINEA (
    p_nro         IN NUMBER,
    p_id_producto IN NUMBER,
    p_cantidad    IN NUMBER,
    p_costo       IN NUMBER
) AS
    v_det NUMBER;
BEGIN
    SELECT NVL(MAX(ID_Detalle), 0) + 1 INTO v_det
      FROM PR_Detalle_Compra WHERE Nro_Orden = p_nro;
    INSERT INTO PR_Detalle_Compra
        (Nro_Orden, ID_Detalle, Costo_Unitario, Cantidad_Solicitada, ID_Producto)
    VALUES (p_nro, v_det, p_costo, p_cantidad, p_id_producto);
    COMMIT;
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20010, 'Ese producto ya esta en la orden');
    WHEN OTHERS THEN
        ROLLBACK;
        IF SQLCODE = -2291 THEN
            RAISE_APPLICATION_ERROR(-20013, 'La orden o el producto no existe');
        ELSIF SQLCODE = -2290 THEN
            RAISE_APPLICATION_ERROR(-20014, 'Cantidad o costo fuera de rango');
        ELSE
            RAISE;
        END IF;
END;
/

CREATE OR REPLACE PROCEDURE PR_SP_ORDEN_CAMBIAR_ESTADO (
    p_nro    IN NUMBER,
    p_estado IN VARCHAR2
) AS
    v_lineas NUMBER;
BEGIN
    IF UPPER(p_estado) = 'ENVIADA' THEN
        SELECT COUNT(*) INTO v_lineas FROM PR_Detalle_Compra WHERE Nro_Orden = p_nro;
        IF v_lineas = 0 THEN
            RAISE_APPLICATION_ERROR(-20032, 'No se puede enviar una orden sin lineas');
        END IF;
    END IF;
    UPDATE PR_Orden_Compra SET Estado_Orden = UPPER(p_estado) WHERE Nro_Orden = p_nro;
    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20011, 'La orden no existe');
    END IF;
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/

CREATE OR REPLACE PROCEDURE PR_SP_ORDEN_LISTAR (
    p_cursor OUT SYS_REFCURSOR
) AS
BEGIN
    OPEN p_cursor FOR
        SELECT v.Nro_Orden,
               TO_CHAR(v.Fecha_Emision, 'YYYY-MM-DD') AS Fecha,
               v.Estado_Orden,
               v.Metodo_Pago,
               v.RUT_Proveedor,
               p.Nombre_Empresa,
               v.Monto_Total
          FROM PR_V_Orden_Total v
          JOIN PR_Proveedor p ON p.RUT_Proveedor = v.RUT_Proveedor
         ORDER BY v.Nro_Orden DESC;
END;
/

CREATE OR REPLACE PROCEDURE PR_SP_ORDEN_DETALLE (
    p_nro    IN  NUMBER,
    p_cursor OUT SYS_REFCURSOR
) AS
BEGIN
    OPEN p_cursor FOR
        SELECT d.ID_Detalle,
               d.ID_Producto,
               pr.Nombre_Producto,
               d.Cantidad_Solicitada,
               d.Costo_Unitario,
               d.Cantidad_Solicitada * d.Costo_Unitario AS Subtotal
          FROM PR_Detalle_Compra d
          JOIN PR_Producto pr ON pr.ID_Producto = d.ID_Producto
         WHERE d.Nro_Orden = p_nro
         ORDER BY d.ID_Detalle;
END;
/

-- ---------------------------------------------------------------------
-- GESTOR 2: RECEPCIONAR UNA ORDEN (usa un cursor)
--   Por cada linea crea una ENTRADA de stock en el estante indicado;
--   el trigger PR_TRG_MOV_STOCK actualiza el estante.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE PR_SP_ORDEN_RECEPCIONAR (
    p_nro          IN NUMBER,
    p_id_ubicacion IN NUMBER,
    p_rut_operario IN VARCHAR2
) AS
    v_estado PR_Orden_Compra.Estado_Orden%TYPE;
    CURSOR c_lineas IS
        SELECT ID_Producto, Cantidad_Solicitada
          FROM PR_Detalle_Compra
         WHERE Nro_Orden = p_nro
         ORDER BY ID_Detalle;
BEGIN
    BEGIN
        SELECT Estado_Orden INTO v_estado
          FROM PR_Orden_Compra WHERE Nro_Orden = p_nro FOR UPDATE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20011, 'La orden no existe');
    END;
    IF v_estado <> 'ENVIADA' THEN
        RAISE_APPLICATION_ERROR(-20033, 'Solo se pueden recepcionar ordenes ENVIADAS (estado actual: ' || v_estado || ')');
    END IF;

    FOR l IN c_lineas LOOP
        INSERT INTO PR_Movimiento_Stock
            (Tipo_Movimiento, Cantidad_Afectada, ID_Producto, ID_Ubicacion,
             RUT_Operario, Nro_Orden)
        VALUES
            ('ENTRADA', l.Cantidad_Solicitada, l.ID_Producto, p_id_ubicacion,
             p_rut_operario, p_nro);
    END LOOP;

    UPDATE PR_Orden_Compra SET Estado_Orden = 'RECIBIDA' WHERE Nro_Orden = p_nro;
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        IF SQLCODE = -2291 THEN
            RAISE_APPLICATION_ERROR(-20013, 'El estante u operario indicado no existe');
        ELSE
            RAISE;
        END IF;
END;
/

-- ---------------------------------------------------------------------
-- GESTOR 3: MOVIMIENTOS DE STOCK (el registro esta en la parte 1:
--           PR_SP_REGISTRAR_MOVIMIENTO). Aqui el listado.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE PR_SP_MOVIMIENTO_LISTAR (
    p_cursor OUT SYS_REFCURSOR
) AS
BEGIN
    OPEN p_cursor FOR
        SELECT m.ID_Movimiento,
               TO_CHAR(m.Fecha_Movimiento, 'YYYY-MM-DD HH24:MI') AS Fecha,
               m.Tipo_Movimiento,
               m.Cantidad_Afectada,
               p.Nombre_Producto,
               m.ID_Ubicacion,
               m.RUT_Operario,
               m.Nro_Orden
          FROM PR_Movimiento_Stock m
          JOIN PR_Producto p ON p.ID_Producto = m.ID_Producto
         ORDER BY m.ID_Movimiento DESC
         FETCH FIRST 100 ROWS ONLY;
END;
/

-- ---------------------------------------------------------------------
-- GESTOR 4: AUDITORIA FISICA (PR_Examina)
--   Registra lo contado y devuelve la diferencia contra lo esperado.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE PR_SP_REGISTRAR_EXAMEN (
    p_rut_operario  IN  VARCHAR2,
    p_id_producto   IN  NUMBER,
    p_id_ubicacion  IN  NUMBER,
    p_cantidad      IN  NUMBER,
    p_id_examen     OUT NUMBER,
    p_diferencia    OUT NUMBER
) AS
    v_esperado NUMBER;
BEGIN
    BEGIN
        SELECT Cantidad INTO v_esperado
          FROM PR_Producto_Ubicacion
         WHERE ID_Producto = p_id_producto AND ID_Ubicacion = p_id_ubicacion;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN v_esperado := 0;
    END;

    INSERT INTO PR_Examina
        (RUT_Operario, ID_Producto, ID_Ubicacion, Cantidad_Contada)
    VALUES (p_rut_operario, p_id_producto, p_id_ubicacion, p_cantidad)
    RETURNING ID_Examen INTO p_id_examen;

    p_diferencia := p_cantidad - v_esperado;
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        IF SQLCODE = -2291 THEN
            RAISE_APPLICATION_ERROR(-20013, 'Operario, producto o estante inexistente');
        ELSIF SQLCODE = -2290 THEN
            RAISE_APPLICATION_ERROR(-20014, 'La cantidad contada no puede ser negativa');
        ELSE
            RAISE;
        END IF;
END;
/

CREATE OR REPLACE PROCEDURE PR_SP_EXAMEN_LISTAR (
    p_cursor OUT SYS_REFCURSOR
) AS
BEGIN
    OPEN p_cursor FOR
        SELECT e.ID_Examen,
               TO_CHAR(e.Fecha_Examen, 'YYYY-MM-DD HH24:MI') AS Fecha,
               e.RUT_Operario,
               p.Nombre_Producto,
               e.ID_Ubicacion,
               e.Cantidad_Contada,
               NVL(pu.Cantidad, 0) AS Cantidad_Actual_Sistema
          FROM PR_Examina e
          JOIN PR_Producto p ON p.ID_Producto = e.ID_Producto
          LEFT JOIN PR_Producto_Ubicacion pu
                 ON pu.ID_Producto = e.ID_Producto
                AND pu.ID_Ubicacion = e.ID_Ubicacion
         ORDER BY e.ID_Examen DESC
         FETCH FIRST 100 ROWS ONLY;
END;
/

-- ---------------------------------------------------------------------
-- GESTOR 5: REPOSICION A PARTIR DE UNA ALERTA
--   Crea una orden PENDIENTE con el producto de la alerta
--   (cantidad = 2 x stock minimo - stock actual, minimo 1) y marca
--   la alerta como ATENDIDA.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE PR_SP_REPONER_DESDE_ALERTA (
    p_id_alerta     IN  NUMBER,
    p_rut_proveedor IN  VARCHAR2,
    p_metodo_pago   IN  VARCHAR2,
    p_costo         IN  NUMBER,
    p_nro           OUT NUMBER
) AS
    v_estado   PR_Alerta_Reposicion.Estado_Alerta%TYPE;
    v_producto NUMBER;
    v_minimo   NUMBER;
    v_stock    NUMBER;
    v_cant     NUMBER;
BEGIN
    BEGIN
        SELECT Estado_Alerta, ID_Producto INTO v_estado, v_producto
          FROM PR_Alerta_Reposicion WHERE ID_Alerta = p_id_alerta FOR UPDATE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20011, 'La alerta no existe');
    END;
    IF v_estado <> 'PENDIENTE' THEN
        RAISE_APPLICATION_ERROR(-20034, 'La alerta ya fue atendida');
    END IF;

    SELECT Stock_Minimo, Stock_Actual INTO v_minimo, v_stock
      FROM PR_V_Stock_Producto WHERE ID_Producto = v_producto;
    v_cant := GREATEST(v_minimo * 2 - v_stock, 1);

    INSERT INTO PR_Orden_Compra (Metodo_Pago, RUT_Proveedor)
    VALUES (UPPER(p_metodo_pago), p_rut_proveedor)
    RETURNING Nro_Orden INTO p_nro;

    INSERT INTO PR_Detalle_Compra
        (Nro_Orden, ID_Detalle, Costo_Unitario, Cantidad_Solicitada, ID_Producto)
    VALUES (p_nro, 1, p_costo, v_cant, v_producto);

    UPDATE PR_Alerta_Reposicion SET Estado_Alerta = 'ATENDIDA'
     WHERE ID_Alerta = p_id_alerta;
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        IF SQLCODE = -2291 THEN
            RAISE_APPLICATION_ERROR(-20013, 'El proveedor no existe');
        ELSIF SQLCODE = -2290 THEN
            RAISE_APPLICATION_ERROR(-20014, 'Metodo de pago o costo no valido');
        ELSE
            RAISE;
        END IF;
END;
/

CREATE OR REPLACE PROCEDURE PR_SP_ALERTA_LISTAR (
    p_cursor OUT SYS_REFCURSOR
) AS
BEGIN
    OPEN p_cursor FOR
        SELECT a.ID_Alerta,
               TO_CHAR(a.Fecha_Generacion, 'YYYY-MM-DD HH24:MI') AS Fecha,
               a.Estado_Alerta,
               a.ID_Producto,
               s.Nombre_Producto,
               s.Stock_Minimo,
               s.Stock_Actual
          FROM PR_Alerta_Reposicion a
          JOIN PR_V_Stock_Producto s ON s.ID_Producto = a.ID_Producto
         ORDER BY CASE a.Estado_Alerta WHEN 'PENDIENTE' THEN 0 ELSE 1 END,
                  a.ID_Alerta DESC;
END;
/

-- ---------------------------------------------------------------------
-- REPORTES (3) - cada uno devuelve un cursor
-- ---------------------------------------------------------------------
-- Reporte 1: productos con mayor y menor salida en un mes
CREATE OR REPLACE PROCEDURE PR_SP_REP_SALIDAS_MES (
    p_anio   IN  NUMBER,
    p_mes    IN  NUMBER,
    p_cursor OUT SYS_REFCURSOR
) AS
    v_ini DATE;
BEGIN
    v_ini := TO_DATE(TO_CHAR(p_anio) || '-' || LPAD(TO_CHAR(p_mes), 2, '0') || '-01',
                     'YYYY-MM-DD');
    OPEN p_cursor FOR
        SELECT p.Nombre_Producto,
               NVL(SUM(m.Cantidad_Afectada), 0) AS Unidades_Salida,
               RANK() OVER (ORDER BY NVL(SUM(m.Cantidad_Afectada), 0) DESC) AS Ranking
          FROM PR_Producto p
          LEFT JOIN PR_Movimiento_Stock m
                 ON m.ID_Producto = p.ID_Producto
                AND m.Tipo_Movimiento = 'SALIDA'
                AND m.Fecha_Movimiento >= v_ini
                AND m.Fecha_Movimiento <  ADD_MONTHS(v_ini, 1)
         GROUP BY p.ID_Producto, p.Nombre_Producto
         ORDER BY Unidades_Salida DESC, p.Nombre_Producto;
END;
/

-- Reporte 2: stock por bodega y producto
CREATE OR REPLACE PROCEDURE PR_SP_REP_STOCK_BODEGA (
    p_cursor OUT SYS_REFCURSOR
) AS
BEGIN
    OPEN p_cursor FOR
        SELECT b.Nombre_Recinto,
               p.Nombre_Producto,
               SUM(pu.Cantidad) AS Unidades,
               p.Stock_Minimo
          FROM PR_Producto_Ubicacion pu
          JOIN PR_Ubicacion_Estante u ON u.ID_Ubicacion = pu.ID_Ubicacion
          JOIN PR_Bodega b            ON b.ID_Bodega = u.ID_Bodega
          JOIN PR_Producto p          ON p.ID_Producto = pu.ID_Producto
         GROUP BY b.Nombre_Recinto, p.Nombre_Producto, p.Stock_Minimo
         ORDER BY b.Nombre_Recinto, p.Nombre_Producto;
END;
/

-- Reporte 3: compras por proveedor (cantidad de ordenes y monto)
CREATE OR REPLACE PROCEDURE PR_SP_REP_COMPRAS_PROVEEDOR (
    p_cursor OUT SYS_REFCURSOR
) AS
BEGIN
    OPEN p_cursor FOR
        SELECT pr.Nombre_Empresa,
               COUNT(v.Nro_Orden) AS Ordenes,
               SUM(CASE WHEN v.Estado_Orden = 'PENDIENTE' THEN 1 ELSE 0 END) AS Pendientes,
               NVL(SUM(CASE WHEN v.Estado_Orden <> 'CANCELADA' THEN v.Monto_Total END), 0) AS Monto_Total
          FROM PR_Proveedor pr
          LEFT JOIN PR_V_Orden_Total v ON v.RUT_Proveedor = pr.RUT_Proveedor
         GROUP BY pr.Nombre_Empresa
         ORDER BY 4 DESC, 1;
END;
/


-- =====================================================================
-- 15. OBJETO-RELACIONAL: orden completa en una sola llamada
--     Recibe la coleccion PR_T_Lineas_Compra (tabla de PR_T_Linea_Compra)
--     y usa el metodo Subtotal() del tipo.
-- =====================================================================
CREATE OR REPLACE FUNCTION PR_FN_TOTAL_LINEAS (
    p_lineas IN PR_T_Lineas_Compra
) RETURN NUMBER AS
    v_total NUMBER := 0;
BEGIN
    IF p_lineas IS NULL THEN
        RETURN 0;
    END IF;
    FOR i IN 1 .. p_lineas.COUNT LOOP
        v_total := v_total + p_lineas(i).Subtotal();
    END LOOP;
    RETURN v_total;
END;
/

CREATE OR REPLACE PROCEDURE PR_SP_ORDEN_CREAR_COMPLETA (
    p_rut_proveedor IN  VARCHAR2,
    p_metodo_pago   IN  VARCHAR2,
    p_lineas        IN  PR_T_Lineas_Compra,
    p_nro           OUT NUMBER
) AS
BEGIN
    IF p_lineas IS NULL OR p_lineas.COUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20032, 'La orden debe tener al menos una linea');
    END IF;

    INSERT INTO PR_Orden_Compra (Metodo_Pago, RUT_Proveedor)
    VALUES (UPPER(p_metodo_pago), p_rut_proveedor)
    RETURNING Nro_Orden INTO p_nro;

    FOR i IN 1 .. p_lineas.COUNT LOOP
        INSERT INTO PR_Detalle_Compra
            (Nro_Orden, ID_Detalle, Costo_Unitario, Cantidad_Solicitada, ID_Producto)
        VALUES
            (p_nro, i, p_lineas(i).Costo_Unitario, p_lineas(i).Cantidad, p_lineas(i).ID_Producto);
    END LOOP;
    COMMIT;
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20010, 'Un producto esta repetido en la orden');
    WHEN OTHERS THEN
        ROLLBACK;
        IF SQLCODE = -2291 THEN
            RAISE_APPLICATION_ERROR(-20013, 'El proveedor o algun producto no existe');
        ELSIF SQLCODE = -2290 THEN
            RAISE_APPLICATION_ERROR(-20014, 'Metodo de pago, cantidad o costo no valido');
        ELSE
            RAISE;
        END IF;
END;
/


-- =====================================================================
-- 16. DATOS DE PRUEBA
--     Se cargan usando los mismos procedimientos de la aplicacion, asi
--     los triggers mantienen el stock por estante y generan las alertas.
--     Usuarios:  admin / admin123      (ADMINISTRADOR)
--                supervisor / super123 (SUPERVISOR)
--                operario / oper123    (OPERARIO)
-- =====================================================================
DECLARE
    t1 NUMBER; t2 NUMBER; t3 NUMBER;
    r_adm NUMBER; r_sup NUMBER; r_ope NUMBER;
    pa_cl NUMBER; pa_cn NUMBER;
    c_tec NUMBER; c_mou NUMBER; c_aud NUMBER; c_mon NUMBER; c_mic NUMBER;
    m_log NUMBER; m_raz NUMBER; m_red NUMBER; m_cor NUMBER; m_asu NUMBER;
    b_cen NUMBER; b_nor NUMBER;
    u1 NUMBER; u2 NUMBER; u3 NUMBER; u4 NUMBER;
    p1 NUMBER; p2 NUMBER; p3 NUMBER; p4 NUMBER; p5 NUMBER; p6 NUMBER; p7 NUMBER;
    n_ord NUMBER; v_id NUMBER; v_alerta NUMBER; v_dif NUMBER;

    -- Movimiento con fecha en el pasado (para que los reportes tengan historia)
    PROCEDURE mov (p_tipo VARCHAR2, p_cant NUMBER, p_prod NUMBER, p_ubi NUMBER,
                   p_rut VARCHAR2, p_meses_atras NUMBER) IS
    BEGIN
        INSERT INTO PR_Movimiento_Stock
            (Tipo_Movimiento, Cantidad_Afectada, Fecha_Movimiento,
             ID_Producto, ID_Ubicacion, RUT_Operario)
        VALUES
            (p_tipo, p_cant, ADD_MONTHS(SYSDATE, -p_meses_atras),
             p_prod, p_ubi, p_rut);
    END;
BEGIN
    -- Turnos, roles, paises
    PR_SP_TURNO_INSERTAR('Manana', '08:00-16:00', 'Ana Soto', t1);
    PR_SP_TURNO_INSERTAR('Tarde',  '16:00-00:00', 'Luis Rojas', t2);
    PR_SP_TURNO_INSERTAR('Noche',  '00:00-08:00', 'Carla Munoz', t3);
    PR_SP_ROL_INSERTAR('ADMINISTRADOR', r_adm);
    PR_SP_ROL_INSERTAR('SUPERVISOR', r_sup);
    PR_SP_ROL_INSERTAR('OPERARIO', r_ope);
    PR_SP_PAIS_INSERTAR('Chile', pa_cl);
    PR_SP_PAIS_INSERTAR('China', pa_cn);

    -- Categorias y marcas
    PR_SP_CATEGORIA_INSERTAR('Teclados', c_tec);
    PR_SP_CATEGORIA_INSERTAR('Mouse', c_mou);
    PR_SP_CATEGORIA_INSERTAR('Audifonos', c_aud);
    PR_SP_CATEGORIA_INSERTAR('Monitores', c_mon);
    PR_SP_CATEGORIA_INSERTAR('Microfonos', c_mic);
    PR_SP_MARCA_INSERTAR('Logitech', m_log);
    PR_SP_MARCA_INSERTAR('Razer', m_raz);
    PR_SP_MARCA_INSERTAR('Redragon', m_red);
    PR_SP_MARCA_INSERTAR('Corsair', m_cor);
    PR_SP_MARCA_INSERTAR('Asus', m_asu);

    -- Bodegas y estantes
    PR_SP_BODEGA_INSERTAR('Bodega Central', 'Av. Lircay', 1234, 'Talca', b_cen);
    PR_SP_BODEGA_INSERTAR('Bodega Norte', '1 Norte', 950, 'Talca', b_nor);
    PR_SP_UBICACION_INSERTAR(1, 1, b_cen, u1);
    PR_SP_UBICACION_INSERTAR(1, 2, b_cen, u2);
    PR_SP_UBICACION_INSERTAR(2, 1, b_cen, u3);
    PR_SP_UBICACION_INSERTAR(1, 1, b_nor, u4);

    -- Operarios y usuarios (hash bcrypt generado con password_hash de PHP)
    PR_SP_OPERARIO_INSERTAR('11.111.111-1', 'Pedro', 'Perez', t1);
    PR_SP_OPERARIO_INSERTAR('22.222.222-2', 'Camila', 'Torres', t2);
    PR_SP_OPERARIO_INSERTAR('33.333.333-3', 'Diego', 'Fuentes', t3);
    PR_SP_USUARIO_INSERTAR('admin',
        '$2y$10$3bJJti1bYT7n0HBS1msrY.ZfLX2/d1mEub2csgJ/ZYEHq.tz3dVC.', r_adm, NULL, 'S', v_id);
    PR_SP_USUARIO_INSERTAR('supervisor',
        '$2y$10$Bx.Gf2sBXwcDNPZJqY3dBukuh371jVW8GhJy3zysHNPLUZcDDV2ke', r_sup, '22.222.222-2', 'S', v_id);
    PR_SP_USUARIO_INSERTAR('operario',
        '$2y$10$IoWoeqdN2Mfi5Yys079xS.cbUlUccPoLn1Jh6.Dy.LrNBLcllruWS', r_ope, '11.111.111-1', 'S', v_id);

    -- Productos (nombre, precio, stock minimo, categoria, marca)
    PR_SP_PRODUCTO_INSERTAR('Teclado Mecanico G915', 199990, 5, c_tec, m_log, p1);
    PR_SP_PRODUCTO_INSERTAR('Mouse Deathadder V3',    69990, 8, c_mou, m_raz, p2);
    PR_SP_PRODUCTO_INSERTAR('Teclado Kumara K552',    39990, 6, c_tec, m_red, p3);
    PR_SP_PRODUCTO_INSERTAR('Audifonos Void Elite',   89990, 4, c_aud, m_cor, p4);
    PR_SP_PRODUCTO_INSERTAR('Monitor Gamer 24',      179990, 3, c_mon, m_asu, p5);
    PR_SP_PRODUCTO_INSERTAR('Mouse G502 Hero',        49990, 10, c_mou, m_log, p6);
    PR_SP_PRODUCTO_INSERTAR('Microfono Seiren Mini',  59990, 3, c_mic, m_raz, p7);

    -- Proveedores, telefonos y que productos ofrece cada uno
    PR_SP_PROVEEDOR_INSERTAR('12.345.678-9', 'Distribuidora Tech', pa_cl);
    PR_SP_PROVEEDOR_INSERTAR('76.543.210-K', 'Shenzhen Gaming Ltd', pa_cn);
    INSERT INTO PR_Telefono_Proveedor (Numero_Contacto, RUT_Proveedor) VALUES ('+56 71 2345678', '12.345.678-9');
    INSERT INTO PR_Telefono_Proveedor (Numero_Contacto, RUT_Proveedor) VALUES ('+56 9 87654321', '12.345.678-9');
    INSERT INTO PR_Telefono_Proveedor (Numero_Contacto, RUT_Proveedor) VALUES ('+86 755 12345678', '76.543.210-K');
    INSERT INTO PR_Proveedor_Producto VALUES ('12.345.678-9', p1);
    INSERT INTO PR_Proveedor_Producto VALUES ('12.345.678-9', p2);
    INSERT INTO PR_Proveedor_Producto VALUES ('12.345.678-9', p3);
    INSERT INTO PR_Proveedor_Producto VALUES ('12.345.678-9', p4);
    INSERT INTO PR_Proveedor_Producto VALUES ('12.345.678-9', p7);
    INSERT INTO PR_Proveedor_Producto VALUES ('76.543.210-K', p3);
    INSERT INTO PR_Proveedor_Producto VALUES ('76.543.210-K', p5);
    INSERT INTO PR_Proveedor_Producto VALUES ('76.543.210-K', p6);

    -- Lectores de codigo y quien los usa
    INSERT INTO PR_Lector_Codigo VALUES ('LX-1001', 85);
    INSERT INTO PR_Lector_Codigo VALUES ('LX-1002', 40);
    INSERT INTO PR_Utiliza VALUES ('11.111.111-1', 'LX-1001');
    INSERT INTO PR_Utiliza VALUES ('22.222.222-2', 'LX-1002');

    -- Stock inicial (hace 2 meses)
    mov('ENTRADA', 30, p1, u1, '11.111.111-1', 2);
    mov('ENTRADA', 25, p2, u2, '11.111.111-1', 2);
    mov('ENTRADA', 20, p3, u2, '11.111.111-1', 2);
    mov('ENTRADA', 12, p4, u3, '22.222.222-2', 2);
    mov('ENTRADA',  8, p5, u4, '22.222.222-2', 2);
    mov('ENTRADA', 40, p6, u1, '11.111.111-1', 2);
    mov('ENTRADA', 10, p6, u4, '22.222.222-2', 2);

    -- Ventas del mes pasado
    mov('SALIDA', 12, p1, u1, '11.111.111-1', 1);
    mov('SALIDA',  9, p2, u2, '11.111.111-1', 1);
    mov('SALIDA',  4, p3, u2, '22.222.222-2', 1);
    mov('SALIDA',  2, p5, u4, '22.222.222-2', 1);

    -- Ventas de este mes (Mouse Deathadder y Audifonos quedan bajo el minimo -> alertas)
    mov('SALIDA',  8, p1, u1, '11.111.111-1', 0);
    mov('SALIDA', 10, p2, u2, '11.111.111-1', 0);
    mov('SALIDA',  3, p3, u2, '22.222.222-2', 0);
    mov('SALIDA',  9, p4, u3, '22.222.222-2', 0);
    mov('SALIDA', 15, p6, u1, '33.333.333-3', 0);
    COMMIT;

    -- Orden 1: creada en una sola llamada con la coleccion de lineas (objeto-relacional),
    -- enviada y recepcionada en Bodega Central pasillo 1 nivel 1
    PR_SP_ORDEN_CREAR_COMPLETA('12.345.678-9', 'TRANSFERENCIA',
        PR_T_Lineas_Compra(PR_T_Linea_Compra(p1, 10, 150000),
                           PR_T_Linea_Compra(p7,  6,  45000)), n_ord);
    PR_SP_ORDEN_CAMBIAR_ESTADO(n_ord, 'ENVIADA');
    PR_SP_ORDEN_RECEPCIONAR(n_ord, u1, '11.111.111-1');

    -- Orden 2: enviada y recepcionada en Bodega Norte
    PR_SP_ORDEN_CREAR('76.543.210-K', 'CREDITO', n_ord);
    PR_SP_ORDEN_AGREGAR_LINEA(n_ord, p5, 5, 120000);
    PR_SP_ORDEN_CAMBIAR_ESTADO(n_ord, 'ENVIADA');
    PR_SP_ORDEN_RECEPCIONAR(n_ord, u4, '22.222.222-2');

    -- Orden 3: queda PENDIENTE
    PR_SP_ORDEN_CREAR('12.345.678-9', 'TARJETA', n_ord);
    PR_SP_ORDEN_AGREGAR_LINEA(n_ord, p3, 10, 25000);

    -- Orden 4: enviada y luego cancelada
    PR_SP_ORDEN_CREAR('76.543.210-K', 'CONTADO', n_ord);
    PR_SP_ORDEN_AGREGAR_LINEA(n_ord, p6, 20, 30000);
    PR_SP_ORDEN_CAMBIAR_ESTADO(n_ord, 'ENVIADA');
    PR_SP_ORDEN_CAMBIAR_ESTADO(n_ord, 'CANCELADA');

    -- Orden 5: generada desde la alerta de los audifonos (la alerta queda ATENDIDA)
    SELECT ID_Alerta INTO v_alerta
      FROM PR_Alerta_Reposicion
     WHERE ID_Producto = p4 AND Estado_Alerta = 'PENDIENTE';
    PR_SP_REPONER_DESDE_ALERTA(v_alerta, '12.345.678-9', 'TRANSFERENCIA', 55000, n_ord);

    -- Auditorias fisicas (una coincide, otra con diferencia de -1)
    PR_SP_REGISTRAR_EXAMEN('11.111.111-1', p1, u1, 20, v_id, v_dif);
    PR_SP_REGISTRAR_EXAMEN('22.222.222-2', p2, u2, 5, v_id, v_dif);

    DBMS_OUTPUT.PUT_LINE('Datos de prueba cargados correctamente.');
END;
/


-- =====================================================================
-- 17. VERIFICACION FINAL
-- =====================================================================
-- a) Errores de compilacion (debe salir VACIO)
SELECT name, type, line, text FROM user_errors ORDER BY name, sequence;

-- b) Objetos invalidos (debe salir VACIO)
SELECT object_name, object_type FROM user_objects
 WHERE status <> 'VALID' AND object_name LIKE 'PR\_%' ESCAPE '\';

-- c) Resumen de objetos creados
SELECT object_type, COUNT(*) AS cantidad FROM user_objects
 WHERE object_name LIKE 'PR\_%' ESCAPE '\'
 GROUP BY object_type ORDER BY object_type;

-- d) Stock (Descuadre debe ser NO en todos)
SELECT * FROM PR_V_Stock_Producto ORDER BY ID_Producto;
SELECT * FROM PR_V_Orden_Total ORDER BY Nro_Orden;
SELECT * FROM PR_V_Bodega_Direccion;