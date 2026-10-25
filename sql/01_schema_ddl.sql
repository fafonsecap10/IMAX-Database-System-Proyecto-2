-- =============================================================================
-- PROYECTO CINES IMAX - ESQUEMA DE BASE DE DATOS TRANSACCIONAL Y AUDITORÍA
-- Motor: PostgreSQL
-- Descripción: Creación de tablas, restricciones, índices y tablas de logs (retención 5 años)
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. TABLAS DE CATÁLOGO Y USUARIOS (RBAC)
-- -----------------------------------------------------------------------------

-- Roles del sistema (Cliente, Taquillero, Operador, Contador, Administrador)
CREATE TABLE rol (
    id_rol SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE,
    descripcion TEXT
);

INSERT INTO rol (nombre, descripcion) VALUES 
('Cliente', 'Usuario final para compra en línea'),
('Taquillero', 'Venta presencial en taquilla'),
('Operador', 'Control de acceso y escaneo de QR en puerta'),
('Contador', 'Acceso a reportes de conciliación e ingresos'),
('Administrador', 'Control total del sistema y gestión de cartelera');

-- Usuarios
CREATE TABLE usuario (
    id_usuario SERIAL PRIMARY KEY,
    id_rol INT NOT NULL REFERENCES rol(id_rol),
    nombre VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    fecha_registro TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    activo BOOLEAN DEFAULT TRUE
);

-- Películas / Obras en cartelera
CREATE TABLE pelicula (
    id_pelicula SERIAL PRIMARY KEY,
    titulo VARCHAR(150) NOT NULL,
    sinopsis TEXT,
    clasificacion VARCHAR(10) NOT NULL, -- ej: TP, M12, M18
    duracion_minutos INT NOT NULL,
    poster_url VARCHAR(255),
    activa BOOLEAN DEFAULT TRUE
);

-- Complex / Cines y Salas
CREATE TABLE sala (
    id_sala SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL, -- ej: Sala 1 IMAX
    ubicacion_cine VARCHAR(100) NOT NULL, -- ej: San José, LA, Tokio
    capacidad_total INT NOT NULL,
    activa BOOLEAN DEFAULT TRUE
);

-- Distribución física de Asientos por Sala
CREATE TABLE asiento (
    id_asiento SERIAL PRIMARY KEY,
    id_sala INT NOT NULL REFERENCES sala(id_sala) ON DELETE CASCADE,
    codigo_asiento VARCHAR(10) NOT NULL, -- ej: A-12, F-05
    zona VARCHAR(20) DEFAULT 'General', -- General, VIP, Palco
    UNIQUE(id_sala, codigo_asiento)
);

-- Programación de Funciones
CREATE TABLE funcion (
    id_funcion SERIAL PRIMARY KEY,
    id_pelicula INT NOT NULL REFERENCES pelicula(id_pelicula),
    id_sala INT NOT NULL REFERENCES sala(id_sala),
    fecha_hora_inicio TIMESTAMP WITH TIME ZONE NOT NULL,
    fecha_hora_fin TIMESTAMP WITH TIME ZONE NOT NULL,
    precio_base NUMERIC(10, 2) NOT NULL,
    activa BOOLEAN DEFAULT TRUE,
    CONSTRAINT chk_horarios CHECK (fecha_hora_fin > fecha_hora_inicio)
);

-- -----------------------------------------------------------------------------
-- 2. OPERACIÓN TRANSACCIONAL (INVENTARIO DE ASIENTOS Y CHECKOUT)
-- -----------------------------------------------------------------------------

-- Estado de reserva/bloqueo de Asientos por Función
-- Clave primaria compuesta para impedir doble venta a nivel de BD
CREATE TABLE funcion_asiento (
    id_funcion INT NOT NULL REFERENCES funcion(id_funcion),
    id_asiento INT NOT NULL REFERENCES asiento(id_asiento),
    estado VARCHAR(20) NOT NULL DEFAULT 'DISPONIBLE', -- DISPONIBLE, BLOQUEADO, OCUPADO
    id_usuario_bloqueo INT REFERENCES usuario(id_usuario),
    bloqueado_hasta TIMESTAMP WITH TIME ZONE, -- Para manejo del temporizador de 2 min
    PRIMARY KEY (id_funcion, id_asiento),
    CONSTRAINT chk_estado_asiento CHECK (estado IN ('DISPONIBLE', 'BLOQUEADO', 'OCUPADO'))
);

-- Transacciones y Compras
CREATE TABLE transaccion (
    id_transaccion SERIAL PRIMARY KEY,
    id_usuario INT NOT NULL REFERENCES usuario(id_usuario),
    monto_total NUMERIC(10, 2) NOT NULL,
    metodo_pago VARCHAR(50) NOT NULL, -- Tarjeta, PayPal, Billetera Digital
    estado VARCHAR(20) NOT NULL DEFAULT 'PENDIENTE', -- PENDIENTE, APROBADO, RECHAZADO, CANCELADO
    fecha_transaccion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Boletos Generados (Tickets con QR)
CREATE TABLE boleto (
    id_boleto SERIAL PRIMARY KEY,
    id_transaccion INT NOT NULL REFERENCES transaccion(id_transaccion),
    id_funcion INT NOT NULL,
    id_asiento INT NOT NULL,
    codigo_qr_hash VARCHAR(255) UNIQUE NOT NULL, -- Identificador único para el QR
    tipo_tarifa VARCHAR(30) DEFAULT 'ADULTO', -- Adulto, Niño, Tercera Edad, Promo 2x1
    precio_aplicado NUMERIC(10, 2) NOT NULL,
    usado BOOLEAN DEFAULT FALSE,
    fecha_uso TIMESTAMP WITH TIME ZONE,
    FOREIGN KEY (id_funcion, id_asiento) REFERENCES funcion_asiento(id_funcion, id_asiento)
);

-- -----------------------------------------------------------------------------
-- 3. TABLAS DE AUDITORÍA Y LOGS HISTÓRICOS (RETENCIÓN A 5 AÑOS)
-- -----------------------------------------------------------------------------

-- 1. Logs de Transacciones Financieras
CREATE TABLE transaccion_log (
    id_log BIGSERIAL PRIMARY KEY,
    id_transaccion INT,
    id_usuario INT,
    monto NUMERIC(10, 2),
    pasarela_respuesta VARCHAR(100),
    estado_pago VARCHAR(20),
    fecha_registro TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. Logs de Bloqueos de Asientos y Colisiones de Inventario
CREATE TABLE asiento_auditoria_log (
    id_log BIGSERIAL PRIMARY KEY,
    id_funcion INT,
    id_asiento INT,
    id_usuario INT,
    evento VARCHAR(50), -- BLOQUEO_INICIADO, LIBERADO_EXPIRACION, COMPRA_CONFIRMADA
    fecha_evento TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 3. Logs de Control de Acceso en Puerta (Check-In)
CREATE TABLE acceso_puerta_log (
    id_log BIGSERIAL PRIMARY KEY,
    id_boleto INT,
    codigo_qr VARCHAR(255),
    id_operador INT,
    resultado VARCHAR(50), -- EXITO, RECHAZADO_DUPLICADO, RECHAZADO_HORARIO
    detalle VARCHAR(255),
    fecha_escaneo TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 4. Bitácora de Operaciones Manuales y Administrativas (Override Audit)
CREATE TABLE admin_operacion_audit (
    id_audit BIGSERIAL PRIMARY KEY,
    id_admin INT NOT NULL,
    tipo_operacion VARCHAR(100) NOT NULL, -- REEMBOLSO_FORZADO, CORTESIA, CAMBIO_PRECIO
    descripcion TEXT,
    ip_origen VARCHAR(45),
    fecha_operacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- -----------------------------------------------------------------------------
-- 4. ÍNDICES DE OPTIMIZACIÓN DE RENDIMIENTO
-- -----------------------------------------------------------------------------

-- Búsqueda rápida de disponibilidad por función
CREATE INDEX idx_funcion_asiento_estado ON funcion_asiento(id_funcion, estado);

-- Búsqueda rápida de cartelera por fechas
CREATE INDEX idx_funcion_fecha ON funcion(fecha_hora_inicio) WHERE activa = TRUE;

-- Validación rápida de QR en puerta
CREATE INDEX idx_boleto_qr ON boleto(codigo_qr_hash);

COMMIT;