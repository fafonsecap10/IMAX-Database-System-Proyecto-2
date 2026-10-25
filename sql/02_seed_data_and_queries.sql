-- =============================================================================
-- PROYECTO CINES IMAX - DATOS DE PRUEBA Y CONSULTAS ANALÍTICAS
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. POBLADO DE DATOS DE PRUEBA (SEED DATA)
-- -----------------------------------------------------------------------------

-- Cines y Salas
INSERT INTO cines (nombre, direccion, ciudad) VALUES 
('IMAX San José', 'Avenida Escazú', 'San José'),
('IMAX Los Angeles', 'Sunset Blvd 1020', 'Los Angeles');

INSERT INTO salas (cine_id, nombre, capacidad_total) VALUES 
(1, 'Sala 1 IMAX 3D', 100),
(2, 'Sala Grand IMAX', 150);

-- Asientos para Sala 1 (Simulación reducida para pruebas)
INSERT INTO asientos (sala_id, fila, numero, tipo) VALUES 
(1, 'A', 1, 'ESTANDAR'), (1, 'A', 2, 'ESTANDAR'), (1, 'A', 3, 'VIP'),
(1, 'B', 1, 'ESTANDAR'), (1, 'B', 2, 'ESTANDAR'), (1, 'B', 3, 'VIP');

-- Películas
INSERT INTO peliculas (titulo, duracion_minutos, clasificacion) VALUES 
('Interstellar: 10th Anniversary IMAX Re-Release', 169, 'PG-13'),
('Dune: Part Two IMAX Experience', 166, 'PG-13'),
('Oppenheimer', 180, 'R');

-- Funciones
INSERT INTO funciones (sala_id, pelicula_id, fecha_hora, precio_base) VALUES 
(1, 1, CURRENT_TIMESTAMP + INTERVAL '1 day', 12.50),
(1, 2, CURRENT_TIMESTAMP + INTERVAL '2 days', 14.00),
(2, 3, CURRENT_TIMESTAMP + INTERVAL '1 day', 15.00);

-- Reservas y Detalle
INSERT INTO reservas (funcion_id, cliente_email, estado, total) VALUES 
(1, 'cliente1@gmail.com', 'CONFIRMADA', 25.00),
(1, 'cliente2@gmail.com', 'CONFIRMADA', 12.50);

INSERT INTO detalle_reservas (reserva_id, asiento_id, precio_aplicado) VALUES 
(1, 1, 12.50),
(1, 2, 12.50),
(2, 3, 12.50);

COMMIT;

-- -----------------------------------------------------------------------------
-- 2. CONSULTAS ANALÍTICAS REQUERIDAS POR EL NEGOCIO
-- -----------------------------------------------------------------------------

-- Consulta 1: Ocupación y Recaudación por Función
SELECT 
    f.funcion_id,
    p.titulo,
    f.fecha_hora,
    COUNT(dr.asiento_id) AS asientos_vendidos,
    ROUND((COUNT(dr.asiento_id)::NUMERIC / s.capacidad_total) * 100, 2) AS porcentaje_ocupacion,
    COALESCE(SUM(dr.precio_aplicado), 0.00) AS ingresos_totales
FROM funciones f
JOIN peliculas p ON f.pelicula_id = p.pelicula_id
JOIN salas s ON f.sala_id = s.sala_id
LEFT JOIN reservas r ON f.funcion_id = r.funcion_id AND r.estado = 'CONFIRMADA'
LEFT JOIN detalle_reservas dr ON r.reserva_id = dr.reserva_id
GROUP BY f.funcion_id, p.titulo, f.fecha_hora, s.capacidad_total;

-- Consulta 2: Top 5 Películas Más Demandadas
SELECT 
    p.titulo,
    COUNT(dr.asiento_id) AS total_boletos_vendidos
FROM peliculas p
JOIN funciones f ON p.pelicula_id = f.pelicula_id
JOIN reservas r ON f.funcion_id = r.funcion_id
JOIN detalle_reservas dr ON r.reserva_id = dr.reserva_id
WHERE r.estado = 'CONFIRMADA'
GROUP BY p.pelicula_id, p.titulo
ORDER BY total_boletos_vendidos DESC
LIMIT 5;

-- -----------------------------------------------------------------------------
-- 3. DEMOSTRACIÓN DE OPTIMIZACIÓN (EXPLAIN ANALYZE)
-- -----------------------------------------------------------------------------
EXPLAIN ANALYZE 
SELECT * FROM funciones WHERE fecha_hora >= CURRENT_TIMESTAMP;