-- ==========================================================================
-- PulseRig — esquema de base de datos y datos de ejemplo
-- MySQL 8 · utf8mb4_unicode_ci
--
-- Regla central del modelo: en la tabla `componentes`, equipo_id = NULL
-- significa que el componente está en el almacén (no montado en ningún
-- equipo). Un componente está en un sitio o en el otro, nunca en los dos.
-- `procedencia_equipo_id` recuerda de qué equipo se retiró un componente
-- que ahora está en el almacén (NULL si se compró suelto).
-- Un componente puede estar publicado en el Outlet esté montado en un
-- equipo o guardado en el almacén: publicarlo no lo saca de donde esté.
-- ==========================================================================

CREATE DATABASE IF NOT EXISTS pulserig
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE pulserig;

SET NAMES utf8mb4;

-- ==========================================================================
-- Tabla: usuarios
-- Cuenta de acceso a la aplicación. PulseRig es una app personal: no hay
-- roles de administrador ni colaborador, solo "con sesión" o "sin sesión".
-- ==========================================================================
CREATE TABLE usuarios (
  id            INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nombre        VARCHAR(100) NOT NULL,
  email         VARCHAR(150) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  fecha_alta    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_usuarios_email (email)
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
  COMMENT='Usuarios de PulseRig';

-- ==========================================================================
-- Tabla: equipos
-- Cada "build" del usuario: una torre, un portátil, un servidor u otro
-- tipo de equipo descrito libremente en tipo_otro.
-- ==========================================================================
CREATE TABLE equipos (
  id             INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  usuario_id     INT UNSIGNED NOT NULL,
  nombre         VARCHAR(100) NOT NULL,
  tipo           ENUM('torre', 'portatil', 'servidor', 'otro') NOT NULL,
  tipo_otro      VARCHAR(100) NULL,
  fecha_montaje  DATE NOT NULL,
  notas          TEXT NULL,
  CONSTRAINT fk_equipos_usuario
    FOREIGN KEY (usuario_id) REFERENCES usuarios (id) ON DELETE CASCADE,
  CONSTRAINT chk_equipos_tipo_otro
    CHECK (tipo <> 'otro' OR tipo_otro IS NOT NULL)
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
  COMMENT='Equipos (builds) registrados por el usuario';

-- ==========================================================================
-- Tabla: componentes
-- Piezas de hardware. Si equipo_id es NULL, la pieza está en el almacén
-- (ver regla central al principio del archivo).
-- ==========================================================================
CREATE TABLE componentes (
  id                     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  usuario_id             INT UNSIGNED NOT NULL,
  equipo_id              INT UNSIGNED NULL,
  categoria              ENUM('cpu', 'gpu', 'ram', 'almacenamiento', 'placa_base', 'fuente', 'refrigeracion', 'otro') NOT NULL,
  nombre                 VARCHAR(150) NOT NULL,
  marca                  VARCHAR(80) NULL,
  modelo                 VARCHAR(80) NULL,
  fecha_compra           DATE NULL,
  fin_garantia           DATE NULL,
  procedencia_equipo_id  INT UNSIGNED NULL,
  fecha_entrada_almacen  DATE NULL,
  foto                   VARCHAR(255) NULL,
  notas                  TEXT NULL,
  CONSTRAINT fk_componentes_usuario
    FOREIGN KEY (usuario_id) REFERENCES usuarios (id) ON DELETE CASCADE,
  CONSTRAINT fk_componentes_equipo
    FOREIGN KEY (equipo_id) REFERENCES equipos (id) ON DELETE SET NULL,
  CONSTRAINT fk_componentes_procedencia
    FOREIGN KEY (procedencia_equipo_id) REFERENCES equipos (id) ON DELETE SET NULL
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
  COMMENT='Componentes de hardware, montados en un equipo o guardados en el almacén';

-- ==========================================================================
-- Tabla: mantenimientos
-- Historial de tareas realizadas sobre un equipo (o sobre un componente
-- concreto de ese equipo).
-- ==========================================================================
CREATE TABLE mantenimientos (
  id            INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  equipo_id     INT UNSIGNED NOT NULL,
  componente_id INT UNSIGNED NULL,
  tipo          ENUM('limpieza', 'pasta_termica', 'bios', 'drivers', 'otro') NOT NULL,
  fecha         DATE NOT NULL,
  notas         TEXT NULL,
  CONSTRAINT fk_mantenimientos_equipo
    FOREIGN KEY (equipo_id) REFERENCES equipos (id) ON DELETE CASCADE,
  CONSTRAINT fk_mantenimientos_componente
    FOREIGN KEY (componente_id) REFERENCES componentes (id) ON DELETE SET NULL
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
  COMMENT='Historial de mantenimiento por equipo';

-- ==========================================================================
-- Tabla: temperaturas
-- Lecturas periódicas de CPU/GPU de un equipo, en reposo o en carga.
-- ==========================================================================
CREATE TABLE temperaturas (
  id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  equipo_id  INT UNSIGNED NOT NULL,
  fecha_hora DATETIME NOT NULL,
  cpu_c      DECIMAL(4,1) NOT NULL,
  gpu_c      DECIMAL(4,1) NOT NULL,
  en_carga   BOOLEAN NOT NULL DEFAULT FALSE,
  CONSTRAINT fk_temperaturas_equipo
    FOREIGN KEY (equipo_id) REFERENCES equipos (id) ON DELETE CASCADE
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
  COMMENT='Lecturas de temperatura de CPU/GPU por equipo';

-- ==========================================================================
-- Tabla: health_scores
-- Histórico de la puntuación de salud (0-100) de cada equipo: una fila
-- por medición, no un campo fijo en `equipos`, para poder ver su evolución.
--
-- Umbrales y color asociado (el cálculo real llega en la fase 2; por ahora
-- la puntuación es un dato guardado):
--   70 - 100 -> Sano     -> var(--sano)     #4FD1A5
--   40 - 69  -> Atención -> var(--atencion) #E8A33D
--    0 - 39  -> Crítico  -> var(--critico)  #E8594F
-- ==========================================================================
CREATE TABLE health_scores (
  id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  equipo_id   INT UNSIGNED NOT NULL,
  fecha       DATE NOT NULL,
  puntuacion  TINYINT UNSIGNED NOT NULL,
  CONSTRAINT fk_health_scores_equipo
    FOREIGN KEY (equipo_id) REFERENCES equipos (id) ON DELETE CASCADE,
  CONSTRAINT chk_health_scores_puntuacion
    CHECK (puntuacion BETWEEN 0 AND 100)
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
  COMMENT='Histórico del Health Score (0-100) por equipo';

-- ==========================================================================
-- Tabla: catalogo_componentes
-- Componentes de referencia, navegables sin sesión, para planificar compras.
-- No están ligados a ningún usuario.
-- ==========================================================================
CREATE TABLE catalogo_componentes (
  id                  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  categoria           ENUM('cpu', 'gpu', 'ram', 'almacenamiento', 'placa_base', 'fuente', 'refrigeracion', 'otro') NOT NULL,
  nombre              VARCHAR(150) NOT NULL,
  marca               VARCHAR(80) NULL,
  especificaciones    VARCHAR(255) NULL,
  precio_orientativo  DECIMAL(8,2) NULL
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
  COMMENT='Catálogo de componentes de referencia';

-- ==========================================================================
-- Tabla: outlet_anuncios
-- Anuncios de componentes propios puestos en venta por los usuarios.
-- ==========================================================================
CREATE TABLE outlet_anuncios (
  id                 INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  componente_id      INT UNSIGNED NOT NULL,
  usuario_id         INT UNSIGNED NOT NULL,
  precio             DECIMAL(8,2) NOT NULL,
  observaciones      TEXT NULL,
  foto               VARCHAR(255) NULL,
  fecha_publicacion  DATE NOT NULL,
  estado             ENUM('publicado', 'vendido', 'retirado') NOT NULL DEFAULT 'publicado',
  CONSTRAINT fk_outlet_componente
    FOREIGN KEY (componente_id) REFERENCES componentes (id) ON DELETE CASCADE,
  CONSTRAINT fk_outlet_usuario
    FOREIGN KEY (usuario_id) REFERENCES usuarios (id) ON DELETE CASCADE
) ENGINE=InnoDB CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
  COMMENT='Anuncios del Outlet de componentes propios';


-- ==========================================================================
-- DATOS DE EJEMPLO
-- Coherentes con la maquetación HTML (mismos nombres, fechas y puntuaciones).
-- ==========================================================================

-- --- usuarios ---------------------------------------------------------
INSERT INTO usuarios (id, nombre, email, password_hash, fecha_alta) VALUES
  (1, 'Daniel Álvarez Alfonso', 'daniel@example.com', '$2y$10$examplehashexamplehashexamplehashexampleha', '2021-06-01 10:00:00');

-- --- equipos ------------------------------------------------------------
INSERT INTO equipos (id, usuario_id, nombre, tipo, tipo_otro, fecha_montaje, notas) VALUES
  (1, 1, 'Torre principal', 'torre', NULL, '2024-03-15', 'Equipo principal de escritorio y gaming.'),
  (2, 1, 'Portátil de trabajo', 'portatil', NULL, '2022-01-20', 'Portátil para trabajo diario.'),
  (3, 1, 'Servidor casero', 'servidor', NULL, '2021-07-10', 'Servidor doméstico de almacenamiento y contenedores.');

-- --- componentes ----------------------------------------------------------
-- Torre principal (equipo_id = 1): 6 componentes, 2 garantías activas.
INSERT INTO componentes (id, usuario_id, equipo_id, categoria, nombre, marca, modelo, fecha_compra, fin_garantia, procedencia_equipo_id, fecha_entrada_almacen, foto, notas) VALUES
  (1, 1, 1, 'cpu',           'AMD Ryzen 7 7800X3D',   'AMD',      '7800X3D',        '2024-03-01', '2029-03-01', NULL, NULL, NULL, NULL),
  (2, 1, 1, 'gpu',           'NVIDIA RTX 4070',        'NVIDIA',   'RTX 4070',       '2024-03-01', '2026-03-01', NULL, NULL, NULL, NULL),
  (3, 1, 1, 'ram',           '32 GB DDR5 6000MHz',     'Corsair',  'Vengeance',      '2024-03-01', '2026-03-01', NULL, NULL, NULL, NULL),
  (4, 1, 1, 'placa_base',    'ASUS ROG Strix B650-A',  'ASUS',     'ROG Strix B650-A','2024-03-01', NULL,        NULL, NULL, NULL, 'Comprada de segunda mano, sin garantía del fabricante.'),
  (5, 1, 1, 'fuente',        'Corsair RM750x',         'Corsair',  'RM750x',         '2024-03-01', '2029-03-01', NULL, NULL, NULL, NULL),
  (6, 1, 1, 'refrigeracion', 'NZXT Kraken 280mm',       'NZXT',     'Kraken 280',     '2024-03-01', '2026-11-01', NULL, NULL, NULL, NULL);

-- Portátil de trabajo (equipo_id = 2): 5 componentes, 0 garantías activas.
INSERT INTO componentes (id, usuario_id, equipo_id, categoria, nombre, marca, modelo, fecha_compra, fin_garantia, procedencia_equipo_id, fecha_entrada_almacen, foto, notas) VALUES
  (7,  1, 2, 'cpu',            'Intel Core i7-1260P',       'Intel',   'i7-1260P', '2022-01-20', '2024-01-20', NULL, NULL, NULL, NULL),
  (8,  1, 2, 'ram',            '16 GB DDR4',                 'Kingston','Fury',     '2022-01-20', '2024-01-20', NULL, NULL, NULL, NULL),
  (9,  1, 2, 'almacenamiento', 'SSD 512GB NVMe',              'Samsung', '970 Evo',  '2022-01-20', '2024-01-20', NULL, NULL, NULL, NULL),
  (10, 1, 2, 'otro',           'Batería',                    NULL,      NULL,       '2022-01-20', NULL,         NULL, NULL, NULL, NULL),
  (11, 1, 2, 'otro',           'Pantalla',                   NULL,      NULL,       '2022-01-20', NULL,         NULL, NULL, NULL, NULL);

-- Servidor casero (equipo_id = 3): 4 componentes, 0 garantías activas.
INSERT INTO componentes (id, usuario_id, equipo_id, categoria, nombre, marca, modelo, fecha_compra, fin_garantia, procedencia_equipo_id, fecha_entrada_almacen, foto, notas) VALUES
  (12, 1, 3, 'cpu',            'Intel Xeon E-2288G',       'Intel',      'E-2288G',       '2021-07-10', '2023-07-10', NULL, NULL, NULL, NULL),
  (13, 1, 3, 'ram',            '64 GB DDR4 ECC',            'Kingston',   'Server Premier','2021-07-10', '2023-07-10', NULL, NULL, NULL, NULL),
  (14, 1, 3, 'almacenamiento', '4x4TB HDD en RAID',          'Seagate',    'IronWolf',      '2021-07-10', '2023-07-10', NULL, NULL, NULL, NULL),
  (15, 1, 3, 'placa_base',     'Supermicro X11SCA',          'Supermicro', 'X11SCA',        '2021-07-10', NULL,         NULL, NULL, NULL, NULL);

-- En el almacén (equipo_id = NULL): componentes que no están montados en ningún equipo.
INSERT INTO componentes (id, usuario_id, equipo_id, categoria, nombre, marca, modelo, fecha_compra, fin_garantia, procedencia_equipo_id, fecha_entrada_almacen, foto, notas) VALUES
  (16, 1, NULL, 'gpu',    'RTX 3060',      'NVIDIA', 'RTX 3060', '2022-05-01', '2024-05-01', 1,    '2026-06-21', NULL, 'Retirada de la Torre principal al actualizar a la RTX 4070.'),
  (17, 1, NULL, 'ram',    '16 GB DDR4',    'Corsair','Vengeance LPX', '2025-09-21', '2027-09-21', NULL, '2026-08-21', NULL, 'Comprada suelta como repuesto.'),
  (18, 1, NULL, 'fuente', 'Fuente 650W',   'EVGA',   '650 BQ',   '2022-01-20', NULL,         2,    '2026-04-21', NULL, 'Retirada del portátil de trabajo.'),
  (19, 1, NULL, 'gpu',    'RTX 4070 Super','NVIDIA', 'RTX 4070 Super', '2025-01-15', '2026-09-29', NULL, '2025-06-01', NULL, 'Apenas usada; se vende por actualización a gama superior.');

-- --- mantenimientos -------------------------------------------------------
INSERT INTO mantenimientos (equipo_id, componente_id, tipo, fecha, notas) VALUES
  (1, NULL, 'limpieza',      '2026-09-09', 'Limpieza general de polvo y repaso de cableado.'),
  (1, 2,    'drivers',       '2026-07-21', 'Actualización de drivers de la GPU.'),
  (1, NULL, 'pasta_termica', '2026-01-21', 'Cambio de pasta térmica de la CPU.'),
  (1, 4,    'bios',          '2025-01-15', 'Actualización de BIOS de la placa base.'),
  (2, NULL, 'limpieza',      '2026-06-19', 'Limpieza de ventiladores y repaso térmico.'),
  (3, NULL, 'limpieza',      '2026-02-23', 'Limpieza general y revisión de discos.');

-- --- temperaturas -----------------------------------------------------
INSERT INTO temperaturas (equipo_id, fecha_hora, cpu_c, gpu_c, en_carga) VALUES
  (1, '2026-09-20 21:00:00', 58.0, 61.0, FALSE),
  (1, '2026-09-18 22:15:00', 79.0, 74.0, TRUE),
  (1, '2026-09-10 20:00:00', 56.0, 59.0, FALSE),
  (2, '2026-09-19 10:00:00', 68.0, 70.0, TRUE),
  (2, '2026-06-19 09:30:00', 62.0, 64.0, FALSE),
  (3, '2026-09-15 03:00:00', 71.0, 55.0, FALSE),
  (3, '2026-02-23 03:00:00', 74.0, 57.0, FALSE);

-- --- health_scores ---------------------------------------------------
-- Fila más reciente por equipo = la puntuación mostrada en la maquetación.
INSERT INTO health_scores (equipo_id, fecha, puntuacion) VALUES
  (1, '2026-03-20', 90),
  (1, '2026-06-20', 88),
  (1, '2026-09-21', 85),
  (2, '2026-03-20', 66),
  (2, '2026-06-20', 60),
  (2, '2026-09-21', 54),
  (3, '2026-03-20', 45),
  (3, '2026-06-20', 38),
  (3, '2026-09-21', 32);

-- --- catalogo_componentes -----------------------------------------------
INSERT INTO catalogo_componentes (categoria, nombre, marca, especificaciones, precio_orientativo) VALUES
  ('cpu',           'AMD Ryzen 7 7800X3D',      'AMD',     '8 núcleos / 16 hilos · 5.0 GHz', 399.00),
  ('gpu',           'NVIDIA RTX 4070 Super',    'NVIDIA',  '12 GB GDDR6X',                    599.00),
  ('ram',           'Corsair Vengeance 32GB DDR5', 'Corsair', '2×16 GB · 6000 MHz',           129.00),
  ('almacenamiento','Samsung 990 Pro 2TB',       'Samsung', 'NVMe PCIe 4.0',                   149.00),
  ('placa_base',    'ASUS ROG Strix B650-A',     'ASUS',    'AM5 · DDR5',                      219.00),
  ('fuente',        'Corsair RM750x',            'Corsair', '750 W · 80+ Gold',                109.00);

-- --- outlet_anuncios ---------------------------------------------------
-- RTX 4070 Super (componente_id = 19) publicada por el propio usuario.
INSERT INTO outlet_anuncios (componente_id, usuario_id, precio, observaciones, foto, fecha_publicacion, estado) VALUES
  (19, 1, 310.00, 'Apenas usada, siempre en un equipo con buena ventilación. Se vende por actualización a una gama superior. Incluye caja original.', NULL, '2026-09-18', 'publicado');
