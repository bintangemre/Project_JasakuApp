/**
 * Seed wilayah (Kalimantan Selatan) ke database.
 * 
 * Cara jalankan:
 *   node prisma/seed-wilayah.cjs
 * 
 * Data diambil dari wilayah.id API (sekali), lalu disimpan ke tabel `wilayah`.
 * Re-run aman (menghapus data lama lalu insert ulang).
 */
const { Pool } = require('pg');
const https = require('https');
require('dotenv').config();

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const KALSEL_CODE = '63';
const API_BASE = 'https://wilayah.id/api';

function fetchJSON(url) {
  return new Promise((resolve, reject) => {
    https.get(url, { headers: { 'User-Agent': 'Jasaku-Seed/1.0' } }, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => {
        try { resolve(JSON.parse(data)); }
        catch (e) { reject(new Error(`JSON parse error from ${url}: ${e.message}`)); }
      });
    }).on('error', reject);
  });
}

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

async function main() {
  const client = await pool.connect();
  let totalInserted = 0;

  try {
    // Clear existing
    await client.query('DELETE FROM wilayah');
    console.log('Cleared existing wilayah data');

    // 1. Provinsi
    console.log('Fetching provinces...');
    const provResp = await fetchJSON(`${API_BASE}/provinces.json`);
    const kalsel = provResp.data.find(p => p.code.toString() === KALSEL_CODE);
    if (!kalsel) throw new Error('Kalimantan Selatan not found');

    await client.query(
      'INSERT INTO wilayah (id, code, name, level, parent_code) VALUES (uuid_generate_v4(), $1, $2, $3, NULL)',
      [KALSEL_CODE, kalsel.name, 'provinsi']
    );
    totalInserted++;
    console.log(`  + ${kalsel.name}`);

    // 2. Kabupaten/Kota
    console.log('Fetching regencies...');
    const regResp = await fetchJSON(`${API_BASE}/regencies/${KALSEL_CODE}.json`);
    const regencies = regResp.data;

    // Batch insert all regencies
    const regValues = regencies.map(r =>
      `(uuid_generate_v4(), '${r.code}', '${r.name.replace(/'/g, "''")}', 'kabupaten', '${KALSEL_CODE}')`
    ).join(',');
    await client.query(`INSERT INTO wilayah (id, code, name, level, parent_code) VALUES ${regValues}`);
    totalInserted += regencies.length;
    console.log(`  + ${regencies.length} kabupaten/kota`);

    // 3. Kecamatan + Kelurahan per regency
    let totalKec = 0;
    let totalKel = 0;

    for (const r of regencies) {
      const regCode = r.code.toString();
      process.stdout.write(`  ${r.name} (${regCode}): `);

      try {
        const kecResp = await fetchJSON(`${API_BASE}/districts/${regCode}.json`);
        const kecamatans = kecResp.data || [];

        // Batch insert all kecamatan
        if (kecamatans.length > 0) {
          const kecValues = kecamatans.map(k =>
            `(uuid_generate_v4(), '${k.code}', '${k.name.replace(/'/g, "''")}', 'kecamatan', '${regCode}')`
          ).join(',');
          await client.query(`INSERT INTO wilayah (id, code, name, level, parent_code) VALUES ${kecValues}`);
          totalKec += kecamatans.length;
          totalInserted += kecamatans.length;
        }

        // Fetch + batch insert kelurahan per kecamatan
        let kelCount = 0;
        for (const k of kecamatans) {
          const kecCode = k.code.toString();
          await sleep(50); // small delay to not hammer the API
          try {
            const kelResp = await fetchJSON(`${API_BASE}/villages/${kecCode}.json`);
            const villages = kelResp.data || [];
            if (villages.length > 0) {
              const kelValues = villages.map(v =>
                `(uuid_generate_v4(), '${v.code}', '${v.name.replace(/'/g, "''")}', 'kelurahan', '${kecCode}')`
              ).join(',');
              await client.query(`INSERT INTO wilayah (id, code, name, level, parent_code) VALUES ${kelValues}`);
              kelCount += villages.length;
              totalInserted++;
            }
          } catch (_) {}
        }
        totalKel += kelCount;
        totalInserted += kelCount;
        console.log(`${kecamatans.length} kec, ${kelCount} kel`);

      } catch (e) {
        console.log(`SKIP (${e.message})`);
      }
    }

    console.log('\n=== WILAYAH SEED COMPLETE ===');
    console.log(`Total inserted: ${totalInserted}`);
    console.log(`  Provinsi:   1`);
    console.log(`  Kab/Kota:   ${regencies.length}`);
    console.log(`  Kecamatan:  ${totalKec}`);
    console.log(`  Kelurahan:  ${totalKel}`);

  } catch (e) {
    console.error('ERROR:', e.message);
    throw e;
  } finally {
    client.release();
  }
  await pool.end();
}

main().catch(e => { console.error(e); process.exit(1); });
