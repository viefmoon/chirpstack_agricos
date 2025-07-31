require("dotenv").config();
const mqtt = require("mqtt");
const { createClient } = require("@supabase/supabase-js");

// --- Configuración y Constantes ---
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const MQTT_HOST = process.env.MQTT_HOST || "localhost";
const MQTT_PORT = process.env.MQTT_PORT || 1883;
const MQTT_TOPIC = process.env.MQTT_TOPIC || "application/#";

const DEVICES_TABLE = "devices";
const VOLTAGE_READINGS_TABLE = "voltage_readings";
const READINGS_TABLE = "readings";
const SENSORS_TABLE = "sensors";
const STATIONS_TABLE = "stations";
const SENSOR_TYPES_TABLE = "sensor_types";

const BATCH_SIZE = 100; // Número máximo de registros a insertar a la vez
const BATCH_INTERVAL = 5000; // Intervalo de tiempo para procesar el lote (ms)

// Mapeo de nombres de variables a sus IDs en la base de datos
const SENSOR_TYPE_IDS = {
  TEMPERATURA: "TEMP",
  HUMEDAD: "HUM",
  PH: "PH",
  COND: "COND",
  SOILH: "SOILH",
  CO2: "CO2",
  LUX: "LUX",
  PRESION: "PRES",
  GAS: "GAS",
};

// Mapeo completo: cada ENUM (valor numérico) mapea a su modelo y tipos de sensores
const SENSOR_CONFIG = {
  // --- Sensores de valor único ---
  0: {
    model: "N100K",
    types: [
      {
        sensor_type_id: SENSOR_TYPE_IDS.TEMPERATURA,
        id_suffix: "",
        index: 0,
      },
    ],
  },
  1: {
    model: "N10K",
    types: [
      {
        sensor_type_id: SENSOR_TYPE_IDS.TEMPERATURA,
        id_suffix: "",
        index: 0,
      },
    ],
  },
  2: {
    model: "HDS10",
    types: [
      {
        sensor_type_id: SENSOR_TYPE_IDS.HUMEDAD,
        id_suffix: "",
        index: 0,
      },
    ],
  },
  3: {
    model: "RTD",
    types: [
      {
        sensor_type_id: SENSOR_TYPE_IDS.TEMPERATURA,
        id_suffix: "",
        index: 0,
      },
    ],
  },
  4: {
    model: "DS18B20",
    types: [
      {
        sensor_type_id: SENSOR_TYPE_IDS.TEMPERATURA,
        id_suffix: "",
        index: 0,
      },
    ],
  },
  5: {
    model: "PH",
    types: [
      {
        sensor_type_id: SENSOR_TYPE_IDS.PH,
        id_suffix: "",
        index: 0,
      },
    ],
  },
  6: {
    model: "COND",
    types: [
      {
        sensor_type_id: SENSOR_TYPE_IDS.COND,
        id_suffix: "",
        index: 0,
      },
    ],
  },
  7: {
    model: "SOILH",
    types: [
      {
        sensor_type_id: SENSOR_TYPE_IDS.SOILH,
        id_suffix: "",
        index: 0,
      },
    ],
  },
  8: {
    model: "VEML7700",
    types: [
      {
        sensor_type_id: SENSOR_TYPE_IDS.LUX,
        id_suffix: "",
        index: 0,
      },
    ],
  },

  // --- Sensores múltiples ---
  100: {
    model: "SHT30",
    types: [
      {
        sensor_type_id: SENSOR_TYPE_IDS.TEMPERATURA,
        id_suffix: "_T",
        index: 0,
      },
      {
        sensor_type_id: SENSOR_TYPE_IDS.HUMEDAD,
        id_suffix: "_H",
        index: 1,
      },
    ],
  },
  101: {
    model: "BME680",
    types: [
      {
        sensor_type_id: SENSOR_TYPE_IDS.TEMPERATURA,
        id_suffix: "_T",
        index: 0,
      },
      {
        sensor_type_id: SENSOR_TYPE_IDS.HUMEDAD,
        id_suffix: "_H",
        index: 1,
      },
      {
        sensor_type_id: SENSOR_TYPE_IDS.PRESION,
        id_suffix: "_P",
        index: 2,
      },
      {
        sensor_type_id: SENSOR_TYPE_IDS.GAS,
        id_suffix: "_G",
        index: 3,
      },
    ],
  },
  102: {
    model: "CO2",
    types: [
      {
        sensor_type_id: SENSOR_TYPE_IDS.CO2,
        id_suffix: "_CO2",
        index: 0,
      },
      {
        sensor_type_id: SENSOR_TYPE_IDS.TEMPERATURA,
        id_suffix: "_T",
        index: 1,
      },
      {
        sensor_type_id: SENSOR_TYPE_IDS.HUMEDAD,
        id_suffix: "_H",
        index: 2,
      },
    ],
  },
  103: {
    model: "BME280",
    types: [
      {
        sensor_type_id: SENSOR_TYPE_IDS.TEMPERATURA,
        id_suffix: "_T",
        index: 0,
      },
      {
        sensor_type_id: SENSOR_TYPE_IDS.HUMEDAD,
        id_suffix: "_H",
        index: 1,
      },
      {
        sensor_type_id: SENSOR_TYPE_IDS.PRESION,
        id_suffix: "_P",
        index: 2,
      },
    ],
  },
  104: {
    model: "SHT40",
    types: [
      {
        sensor_type_id: SENSOR_TYPE_IDS.TEMPERATURA,
        id_suffix: "_T",
        index: 0,
      },
      {
        sensor_type_id: SENSOR_TYPE_IDS.HUMEDAD,
        id_suffix: "_H",
        index: 1,
      },
    ],
  },
  110: {
    model: "ENV4",
    types: [
      {
        sensor_type_id: SENSOR_TYPE_IDS.HUMEDAD,
        id_suffix: "_H",
        index: 0,
      },
      {
        sensor_type_id: SENSOR_TYPE_IDS.TEMPERATURA,
        id_suffix: "_T",
        index: 1,
      },
      {
        sensor_type_id: SENSOR_TYPE_IDS.PRESION,
        id_suffix: "_P",
        index: 2,
      },
      {
        sensor_type_id: SENSOR_TYPE_IDS.LUX,
        id_suffix: "_L",
        index: 3,
      },
    ],
  },
};

// --- Inicialización Supabase ---
if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error("ERROR: Variables de entorno SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY son requeridas");
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

// --- Cachés en Memoria y Batch Processing ---
const knownStations = new Set();
const knownDevices = new Set();
const knownSensorTypes = new Set();
const knownSensors = new Set();

// Colas para procesamiento por lotes
const readingsBatch = [];
const voltageReadingsBatch = [];

// --- PRECARGA de datos existentes ---
async function preloadExistingData() {
  console.log("Iniciando precarga de datos existentes...");

  try {
    // Cargar estaciones
    const { data: stations, error: stationsError } = await supabase
      .from(STATIONS_TABLE)
      .select("id");

    if (stationsError) throw stationsError;
    stations.forEach((station) => knownStations.add(station.id));
    console.log(`Precargadas ${stations.length} estaciones`);

    // Cargar dispositivos
    const { data: devices, error: devicesError } = await supabase
      .from(DEVICES_TABLE)
      .select("id");

    if (devicesError) throw devicesError;
    devices.forEach((device) => knownDevices.add(device.id));
    console.log(`Precargados ${devices.length} dispositivos`);

    // Cargar tipos de sensores
    const { data: sensorTypes, error: sensorTypesError } = await supabase
      .from(SENSOR_TYPES_TABLE)
      .select("id");

    if (sensorTypesError) throw sensorTypesError;
    sensorTypes.forEach((type) => knownSensorTypes.add(type.id));
    console.log(`Precargados ${sensorTypes.length} tipos de sensores`);

    // Cargar sensores
    const { data: sensors, error: sensorsError } = await supabase
      .from(SENSORS_TABLE)
      .select("id");

    if (sensorsError) throw sensorsError;
    sensors.forEach((sensor) => knownSensors.add(sensor.id));
    console.log(`Precargados ${sensors.length} sensores`);

    console.log("Precarga de datos completada con éxito");
  } catch (error) {
    console.error("Error durante la precarga de datos:", error);
  }
}

// Procesamiento por lotes para lecturas
async function processBatches() {
  try {
    // Procesar lecturas de sensores
    if (readingsBatch.length > 0) {
      const batchToProcess = [...readingsBatch];
      readingsBatch.length = 0;

      const { error } = await supabase
        .from(READINGS_TABLE)
        .insert(batchToProcess);

      if (error) {
        console.error("Error al insertar lote de lecturas:", error);
      } else {
        console.log(`Procesado lote de ${batchToProcess.length} lecturas`);
      }
    }

    // Procesar lecturas de voltaje
    if (voltageReadingsBatch.length > 0) {
      const batchToProcess = [...voltageReadingsBatch];
      voltageReadingsBatch.length = 0;

      const { error } = await supabase
        .from(VOLTAGE_READINGS_TABLE)
        .insert(batchToProcess);

      if (error) {
        console.error("Error al insertar lote de lecturas de voltaje:", error);
      } else {
        console.log(`Procesado lote de ${batchToProcess.length} lecturas de voltaje`);
      }
    }
  } catch (err) {
    console.error("Error en procesamiento por lotes:", err);
  }
}

// --- Funciones Auxiliares ---

async function ensureStationExists(stationId) {
  if (knownStations.has(stationId)) {
    return true;
  }

  const { error } = await supabase
    .from(STATIONS_TABLE)
    .upsert(
      { id: stationId, name: `Estación ${stationId}`, is_active: true },
      { onConflict: "id", ignoreDuplicates: true }
    );

  if (error) {
    console.error(`Error al asegurar/insertar la estación ${stationId}:`, error);
    return false;
  }

  console.log(`Estación ${stationId} asegurada o ya existía.`);
  knownStations.add(stationId);
  return true;
}

async function ensureSensorTypeExists(sensorTypeId) {
  if (!sensorTypeId) {
    console.error(`Tipo de sensor no válido: ${sensorTypeId}`);
    return null;
  }

  if (knownSensorTypes.has(sensorTypeId)) {
    return sensorTypeId;
  }

  const { error } = await supabase
    .from(SENSOR_TYPES_TABLE)
    .upsert(
      { id: sensorTypeId, name: sensorTypeId },
      { onConflict: "id", ignoreDuplicates: true }
    );

  if (error) {
    console.error(`Error al asegurar/insertar tipo de sensor ${sensorTypeId}:`, error);
    return null;
  }

  console.log(`Tipo de sensor ${sensorTypeId} asegurado o ya existía.`);
  knownSensorTypes.add(sensorTypeId);
  return sensorTypeId;
}

async function ensureDeviceExists(deviceId, stationId) {
  const stationOk = await ensureStationExists(stationId);
  if (!stationOk) {
    console.error(`No se pudo asegurar la estación ${stationId}, abortando para el dispositivo ${deviceId}`);
    return false;
  }

  if (knownDevices.has(deviceId)) {
    return true;
  }

  const { error } = await supabase
    .from(DEVICES_TABLE)
    .upsert(
      { id: deviceId, station_id: stationId, is_active: true },
      { onConflict: "id", ignoreDuplicates: true }
    );

  if (error) {
    console.error(`Error al asegurar/insertar el dispositivo ${deviceId}:`, error);
    return false;
  }

  console.log(`Dispositivo ${deviceId} asegurado o ya existía.`);
  knownDevices.add(deviceId);
  return true;
}

async function ensureSensorExists(sensorId, sensorTypeId, stationId) {
  if (knownSensors.has(sensorId)) {
    return true;
  }

  const { error } = await supabase.from(SENSORS_TABLE).upsert(
    {
      id: sensorId,
      name: "",
      sensor_type_id: sensorTypeId,
      is_active: true,
      station_id: stationId,
    },
    { onConflict: "id", ignoreDuplicates: true }
  );

  if (error) {
    console.error(`Error al asegurar/insertar el sensor ${sensorId}:`, error);
    return false;
  }

  console.log(`Sensor ${sensorId} asegurado o ya existía.`);
  knownSensors.add(sensorId);
  return true;
}

// Función para manejar lecturas de voltaje
function handleVoltageReading(deviceId, voltage, timestamp) {
  voltageReadingsBatch.push({
    device_id: deviceId,
    voltage_value: voltage,
    timestamp,
  });

  if (voltageReadingsBatch.length >= BATCH_SIZE) {
    processBatches();
  }
}

// Función para manejar una lectura de sensor individual
async function handleSensorReading(sensorId, sensorTypeId, value, stationId, timestamp) {
  if (value === null || value === undefined) {
    return;
  }
  if (!sensorId) {
    console.error("Intento de procesar lectura de sensor sin ID válido.");
    return;
  }

  const confirmedSensorTypeId = await ensureSensorTypeExists(sensorTypeId);
  if (!confirmedSensorTypeId) {
    console.error(`No se pudo asegurar el tipo de sensor ${sensorTypeId} para el sensor ${sensorId}. Abortando lectura.`);
    return;
  }

  const sensorOk = await ensureSensorExists(sensorId, confirmedSensorTypeId, stationId);
  if (!sensorOk) {
    console.error(`No se pudo asegurar el sensor ${sensorId}. Abortando lectura.`);
    return;
  }

  readingsBatch.push({
    sensor_id: sensorId,
    value: value,
    timestamp,
  });

  if (readingsBatch.length >= BATCH_SIZE) {
    processBatches();
  }
}

// --- Función para procesar el mensaje MQTT ---
async function processMQTTMessage(topic, message) {
  try {
    const payloadStr = message.toString();
    const messageJson = JSON.parse(payloadStr);
    const decodedData = Buffer.from(messageJson.data, "base64").toString("utf8");

    const parts = decodedData.split("|");
    if (parts.length < 4) {
      console.error("Formato de mensaje decodificado inválido:", decodedData);
      return;
    }

    const [stationId, deviceId, voltageStr, timestampStr, ...sensorData] = parts;

    const timestampNum = parseInt(timestampStr);
    if (isNaN(timestampNum)) {
      console.error("Error: Timestamp inválido:", timestampStr);
      return;
    }
    const timestampISO = new Date(timestampNum * 1000).toISOString();

    // Asegurar Dispositivo
    const deviceOk = await ensureDeviceExists(deviceId, stationId);
    if (!deviceOk) {
      console.error(`No se pudo asegurar el dispositivo ${deviceId}, omitiendo procesamiento de lecturas para este mensaje.`);
      return;
    }

    // Procesar Lectura de Voltaje
    const voltage = parseFloat(voltageStr);
    if (!isNaN(voltage)) {
      handleVoltageReading(deviceId, voltage, timestampISO);
    }

    // Procesar Sensores
    for (const sensorStr of sensorData) {
      const sensorParts = sensorStr.split(",");
      if (sensorParts.length < 3) {
        console.warn(`Formato de sensor inválido, omitiendo: "${sensorStr}"`);
        continue;
      }

      const sensorId = sensorParts[0];
      const sensorModelEnum = parseInt(sensorParts[1]);

      if (isNaN(sensorModelEnum)) {
        console.warn(`Tipo de sensor inválido para ${sensorId}: "${sensorParts[1]}"`);
        continue;
      }

      if (!SENSOR_CONFIG[sensorModelEnum]) {
        console.warn(`Sensor no configurado: ${sensorId} tipo ${sensorModelEnum}`);
        continue;
      }

      const sensorConfig = SENSOR_CONFIG[sensorModelEnum];
      console.log(`Procesando sensor: ${sensorId} modelo ${sensorConfig.model}`);

      for (const typeConfig of sensorConfig.types) {
        const valueIndex = typeConfig.index + 2;

        if (sensorParts.length <= valueIndex) {
          console.warn(`No hay suficientes valores para el sensor ${sensorId} (índice ${valueIndex})`);
          continue;
        }

        const rawValue = sensorParts[valueIndex];
        const value = rawValue.toLowerCase() === "nan" ? null : parseFloat(rawValue);

        const derivedSensorId = typeConfig.id_suffix
          ? `${sensorId}${typeConfig.id_suffix}`
          : sensorId;

        if (value === null || value === undefined) {
          console.log(`Omitiendo valor nulo para ${derivedSensorId}`);
          continue;
        }

        console.log(`Procesando lectura para ${derivedSensorId} tipo ${typeConfig.sensor_type_id}`);

        await handleSensorReading(
          derivedSensorId,
          typeConfig.sensor_type_id,
          value,
          stationId,
          timestampISO
        );
      }
    }

    console.log(`Mensaje procesado para Estación: ${stationId}, Dispositivo: ${deviceId}`);
  } catch (err) {
    console.error("Error fatal al procesar mensaje MQTT:", {
      errorMessage: err.message,
      errorStack: err.stack,
      topic: topic,
      message: message.toString(),
    });
  }
}

// --- Función Principal ---
async function main() {
  console.log("=== ChirpStack - Supabase Integration Service ===");
  console.log(`Conectando a Supabase: ${SUPABASE_URL}`);
  console.log(`MQTT Broker: ${MQTT_HOST}:${MQTT_PORT}`);
  console.log(`MQTT Topic: ${MQTT_TOPIC}`);
  
  // Precargar datos existentes
  await preloadExistingData();

  // Iniciar procesamiento por lotes periódico
  setInterval(processBatches, BATCH_INTERVAL);

  const brokerUrl = `mqtt://${MQTT_HOST}:${MQTT_PORT}`;
  const client = mqtt.connect(brokerUrl);

  client.on("connect", () => {
    console.log("✅ Conectado al broker MQTT con éxito.");
    client.subscribe(MQTT_TOPIC, (err) => {
      if (!err) {
        console.log(`✅ Suscrito al topic: ${MQTT_TOPIC}`);
        console.log("🔄 Servicio iniciado correctamente. Esperando mensajes...");
      } else {
        console.error("❌ Error al suscribirse al topic MQTT:", err);
      }
    });
  });

  client.on("message", (topic, message) => {
    processMQTTMessage(topic, message);
  });

  client.on("error", (err) => {
    console.error("❌ Error en la conexión MQTT:", err);
  });

  client.on("disconnect", () => {
    console.log("⚠️ Desconectado del broker MQTT. Intentando reconectar...");
  });

  // Manejar cierre limpio
  process.on("SIGINT", async () => {
    console.log("🔄 Cerrando aplicación, procesando lotes pendientes...");
    await processBatches();
    console.log("✅ Procesamiento finalizado. Saliendo.");
    client.end();
    process.exit(0);
  });

  process.on("SIGTERM", async () => {
    console.log("🔄 Recibida señal SIGTERM, cerrando graciosamente...");
    await processBatches();
    client.end();
    process.exit(0);
  });

  console.log(`🔄 Intentando conectar a ${brokerUrl}...`);
}

// --- Llamada a la función principal ---
main().catch(console.error);