import express from 'express';
import cors from 'cors';

const app = express();
const PORT = process.env.PORT || 3000;

// MobiData BW ParkAPI-Endpoint (Parkplätze)
const MOBIDATA_PARKING_URL =
  'https://api.mobidata-bw.de/park-api/api/public/v3/parking-sites';

// In-Memory-Cache
let parkingSites = []; // { id, name, lat, lon, capacity, state }
let lastFetch = 0;
const REFRESH_MS = 10 * 60 * 1000; // alle 10 Minuten aktualisieren

app.use(cors()); // für Flutter Web / Emulator
app.use(express.json());

function toNumber(value) {
  if (value === null || value === undefined) return null;
  if (typeof value === 'number') return value;
  if (typeof value === 'string') return Number(value.replace(',', '.')) || null;
  return null;
}

// Haversine-Distanz in Metern
function haversine(lat1, lon1, lat2, lon2) {
  const R = 6371000; // Erdradius in m
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) *
      Math.cos(toRad(lat2)) *
      Math.sin(dLon / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

// Ein Eintrag aus dem Roh-JSON in eine flache Struktur übersetzen
function mapParkingItem(raw) {
  try {
    let lat = null;
    let lon = null;

    const geom = raw.geometry;

    // GeoJSON Point
    if (geom && geom.type === 'Point' && Array.isArray(geom.coordinates)) {
      lon = toNumber(geom.coordinates[0]);
      lat = toNumber(geom.coordinates[1]);
    }

    // Fallback: separate lat/lon-Felder
    if (lat === null) lat = toNumber(raw.lat ?? raw.latitude);
    if (lon === null) lon = toNumber(raw.lon ?? raw.lng ?? raw.longitude);

    if (lat === null || lon === null) return null;

    const id =
      String(raw.id ?? raw.uuid ?? raw.identifier ?? raw.ident ?? '');
    const name = String(raw.name ?? raw.title ?? 'Parkplatz');
    const capacity = raw.capacity ?? raw.max_capacity ?? null;
    const capacityNum = toNumber(capacity);
    const state = raw.state ?? raw.status ?? null;

    return {
      id,
      name,
      lat,
      lon,
      capacity: capacityNum,
      state: state ? String(state) : null
    };
  } catch {
    return null;
  }
}

// Rohdaten von MobiData BW laden und in parkingSites ablegen
async function refreshParkingData(force = false) {
  const now = Date.now();
  if (!force && now - lastFetch < REFRESH_MS && parkingSites.length > 0) {
    return;
  }

  console.log('[BFF] Fetching parking data from MobiData BW…');
  const res = await fetch(MOBIDATA_PARKING_URL, {
    headers: { Accept: 'application/json' }
  });

  if (!res.ok) {
    console.error('[BFF] Error fetching parking data:', res.status, res.statusText);
    throw new Error('Failed to fetch parking data');
  }

  let data = await res.json();

  const sites = [];

  if (Array.isArray(data)) {
    console.log('[BFF] top-level list, length:', data.length);
    for (const item of data) {
      if (item && typeof item === 'object') {
        const mapped = mapParkingItem(item);
        if (mapped) sites.push(mapped);
      }
    }
  } else if (data && typeof data === 'object') {
    console.log('[BFF] top-level object, keys:', Object.keys(data));

    // GeoJSON FeatureCollection?
    if (Array.isArray(data.features)) {
      console.log('[BFF] features length:', data.features.length);
      for (const f of data.features) {
        if (!f || typeof f !== 'object') continue;
        const props =
          f.properties && typeof f.properties === 'object'
            ? { ...f.properties }
            : {};
        const merged = { ...props, geometry: f.geometry };
        const mapped = mapParkingItem(merged);
        if (mapped) sites.push(mapped);
      }
    } else {
      // generischer Fallback: erste Liste von Objekten
      for (const [key, value] of Object.entries(data)) {
        if (Array.isArray(value) && value.length > 0 && typeof value[0] === 'object') {
          console.log('[BFF] trying list at key:', key, 'length:', value.length);
          for (const item of value) {
            const mapped = mapParkingItem(item);
            if (mapped) sites.push(mapped);
          }
          break;
        }
      }
    }
  }

  parkingSites = sites;
  lastFetch = now;
  console.log('[BFF] total mapped parking sites:', parkingSites.length);
}

// Endpoint mit Radius in Metern
app.get('/parking', async (req, res) => {
  try {
    const lat = toNumber(req.query.lat);
    const lon = toNumber(req.query.lon);
    const radius = toNumber(req.query.radius) ?? 5000; // Default 5 km

    if (lat === null || lon === null) {
      return res.status(400).json({ error: 'lat and lon are required' });
    }

    await refreshParkingData();

    const result = parkingSites.filter((site) => {
      if (!site.lat || !site.lon) return false;
      const d = haversine(lat, lon, site.lat, site.lon);
      return d <= radius;
    });

    console.log(
      `[BFF] request lat=${lat}, lon=${lon}, radius=${radius} -> ${result.length} sites`
    );

    res.json(result);
  } catch (err) {
    console.error('[BFF] /parking error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.listen(PORT, () => {
  console.log(`MobiData BFF listening on port ${PORT}`);
  // Initiales Laden im Hintergrund
  refreshParkingData().catch((e) => console.error('[BFF] initial fetch failed', e));
});

