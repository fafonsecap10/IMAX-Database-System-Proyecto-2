import psycopg2
import concurrent.futures
import time

# Configuración de conexión a PostgreSQL
DB_CONFIG = {
    "dbname": "imax_db",
    "user": "postgres",
    "password": "tu_password",
    "host": "localhost",
    "port": "5432"
}

# Parámetros del experimento
ID_FUNCION = 1
ID_ASIENTO = 10  # Asiento específico en disputa
NUM_PETICIONES = 30  # Entre 20 y 50 solicitudes simultáneas exigidas

def intentar_reservar_asiento(id_usuario):
    """
    Intenta reservar/bloquear el mismo asiento para la misma función.
    Demuestra la prevención de doble venta garantizada por la base de datos (ACID).
    """
    conn = None
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cursor = conn.cursor()
        
        # Iniciar transacción explícita
        cursor.execute("BEGIN;")
        
        # Intentar insertar o actualizar el estado del asiento
        query = """
            INSERT INTO funcion_asiento (id_funcion, id_asiento, estado, id_usuario_bloqueo, bloqueado_hasta)
            VALUES (%s, %s, 'BLOQUEADO', %s, CURRENT_TIMESTAMP + INTERVAL '2 minutes')
            ON CONFLICT (id_funcion, id_asiento) 
            DO UPDATE SET 
                estado = 'BLOQUEADO',
                id_usuario_bloqueo = %s,
                bloqueado_hasta = CURRENT_TIMESTAMP + INTERVAL '2 minutes'
            WHERE funcion_asiento.estado = 'DISPONIBLE';
        """
        cursor.execute(query, (ID_FUNCION, ID_ASIENTO, id_usuario, id_usuario))
        
        # Verificar si la fila fue modificada/insertada con éxito
        if cursor.rowcount > 0:
            conn.commit()
            return (id_usuario, True, "Reserva EXITOSA")
        else:
            conn.rollback()
            return (id_usuario, False, "RECHAZADO: Asiento no disponible (colisión detectada)")

    except Exception as e:
        if conn:
            conn.rollback()
        return (id_usuario, False, f"ERROR / COLISIÓN: {str(e).strip()}")
    finally:
        if conn:
            conn.close()

def ejecutar_prueba_concurrencia():
    print(f"--- INICIANDO PRUEBA DE CONCURRENCIA CON {NUM_PETICIONES} HILOS SIMULTÁNEOS ---")
    resultados = []
    
    # Lanzar peticiones concurrentes
    with concurrent.futures.ThreadPoolExecutor(max_workers=NUM_PETICIONES) as executor:
        futures = [executor.submit(intentar_reservar_asiento, user_id) for user_id in range(1, NUM_PETICIONES + 1)]
        for future in concurrent.futures.as_completed(futures):
            resultados.append(future.result())

    # Analizar resultados
    exitos = [r for r in resultados if r[1]]
    fallos = [r for r in resultados if not r[1]]

    print("\n================ RESUMEN DE PRUEBA ================")
    print(f"Total de solicitudes simultáneas: {NUM_PETICIONES}")
    print(f"Reservas exitosas: {len(exitos)}")
    print(f"Solicitudes rechazadas/bloqueadas: {len(fallos)}")
    print("===================================================\n")

    for id_u, exito, msg in resultados:
        estado_str = "[EXITO]" if exito else "[RECHAZADO]"
        print(f"Usuario ID {id_u:02d}: {estado_str} -> {msg}")

if __name__ == "__main__":
    ejecutar_prueba_concurrencia()