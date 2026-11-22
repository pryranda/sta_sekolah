'use strict';

const { query, withTransaction } = require('../db');
const { uuid, toNum } = require('./helpers');

const HARI_URUT = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];

const DEFAULT_CONFIG = {
  startTime: '07:00',
  lessonDuration: 30,
  breaks: [
    { start: '09:30', end: '09:45' },
    { start: '11:45', end: '12:30' },
  ],
  endTimeLower: '13:30',   // tingkat 1-3
  endTimeUpper: '14:30',   // tingkat 4+
  upacaraDay: 'Senin',
  upacaraDuration: 60,
};

// ---------------------------------------------------------------- utils waktu
const toMin = (hhmm) => {
  const [h, m] = String(hhmm).split(':').map((x) => parseInt(x, 10));
  return (h || 0) * 60 + (m || 0);
};

const toHHMMSS = (min) => {
  const h = Math.floor(min / 60) % 24;
  const m = min % 60;
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}:00`;
};

/** Apakah [a1,a2) bertumpuk dengan [b1,b2)? */
const overlap = (a1, a2, b1, b2) => a1 < b2 && b1 < a2;

/**
 * Bangun daftar slot waktu untuk satu hari.
 * Mengembalikan [{ mulai, selesai, upacara }] dalam menit.
 */
function buildSlots(config, hari, tingkat) {
  const lesson = Math.max(10, toNum(config.lessonDuration, 30));
  const start = toMin(config.startTime || '07:00');
  const endLimit = toMin(
    toNum(tingkat, 1) >= 4
      ? (config.endTimeUpper || '14:30')
      : (config.endTimeLower || '13:30')
  );

  const breaks = (Array.isArray(config.breaks) ? config.breaks : [])
    .map((b) => ({ start: toMin(b.start), end: toMin(b.end) }))
    .sort((a, b) => a.start - b.start);

  const slots = [];
  let cursor = start;

  // Upacara di hari tertentu
  if (config.upacaraDay && hari === config.upacaraDay && toNum(config.upacaraDuration) > 0) {
    const dur = toNum(config.upacaraDuration, 60);
    slots.push({ mulai: cursor, selesai: cursor + dur, upacara: true });
    cursor += dur;
  }

  let guard = 0;
  while (cursor + lesson <= endLimit && guard < 64) {
    guard += 1;

    // lompati istirahat
    const br = breaks.find((b) => overlap(cursor, cursor + lesson, b.start, b.end));
    if (br) { cursor = br.end; continue; }

    slots.push({ mulai: cursor, selesai: cursor + lesson, upacara: false });
    cursor += lesson;
  }

  return slots;
}

/**
 * Generate jadwal untuk sekumpulan kelas.
 * Slot yang sudah diubah manual (is_manual = 1) tidak ditimpa.
 */
async function generateJadwal({ sekolahId, kelasIds, hariList, tahunAjaran, semester, config }) {
  const cfg = { ...DEFAULT_CONFIG, ...(config || {}) };

  const hari = (hariList || [])
    .filter((h) => HARI_URUT.includes(h))
    .sort((a, b) => HARI_URUT.indexOf(a) - HARI_URUT.indexOf(b));
  if (!hari.length) return { ok: false, message: 'Pilih minimal satu hari' };

  const ph = kelasIds.map(() => '?').join(',');
  const kelasList = await query(
    `SELECT id, nama_kelas, tingkat, ruangan FROM kelas
      WHERE sekolah_id = ? AND id IN (${ph})
      ORDER BY tingkat, nama_kelas`,
    [sekolahId, ...kelasIds]
  );
  if (!kelasList.length) return { ok: false, message: 'Kelas tidak ditemukan' };

  // mapel + guru pengampu
  const mapelRows = await query(
    `SELECT m.id, m.nama_mapel, m.kode_mapel, m.tingkat, m.jam_per_pekan
       FROM mapel m WHERE m.sekolah_id = ? ORDER BY m.nama_mapel`,
    [sekolahId]
  );
  if (!mapelRows.length) {
    return { ok: false, message: 'Belum ada mata pelajaran. Tambahkan mapel terlebih dahulu.' };
  }

  const pengampuRows = await query(
    `SELECT gm.mapel_id, gm.guru_id, g.nama AS guru_nama
       FROM guru_mapel gm JOIN guru g ON g.id = gm.guru_id
      WHERE g.sekolah_id = ? AND g.status = 'aktif'`,
    [sekolahId]
  );

  const pengampu = new Map(); // mapel_id -> [guru_id]
  for (const p of pengampuRows) {
    if (!pengampu.has(p.mapel_id)) pengampu.set(p.mapel_id, []);
    pengampu.get(p.mapel_id).push(p.guru_id);
  }

  // Slot guru yang sudah terpakai: Map<"hari|guruId", [[mulai,selesai]]>
  const guruBusy = new Map();
  const busyKey = (h, guruId) => `${h}|${guruId}`;
  const addBusy = (h, guruId, a, b) => {
    const k = busyKey(h, guruId);
    if (!guruBusy.has(k)) guruBusy.set(k, []);
    guruBusy.get(k).push([a, b]);
  };
  const isBusy = (h, guruId, a, b) =>
    (guruBusy.get(busyKey(h, guruId)) || []).some(([x, y]) => overlap(a, b, x, y));

  // muat jadwal yang sudah ada (kelas lain + slot manual) agar tidak bentrok
  const existing = await query(
    `SELECT j.kelas_id, j.guru_id, j.hari, j.jam_mulai, j.jam_selesai, j.is_manual
       FROM jadwal j WHERE j.sekolah_id = ?`,
    [sekolahId]
  );

  const targetSet = new Set(kelasList.map((k) => k.id));
  const manualSlots = new Map(); // kelas_id -> [[hari, mulai, selesai]]
  for (const e of existing) {
    const a = toMin(String(e.jam_mulai).slice(0, 5));
    const b = toMin(String(e.jam_selesai).slice(0, 5));
    const isTarget = targetSet.has(e.kelas_id);

    // jadwal kelas lain, atau slot manual pada kelas target -> dianggap terpakai
    if (!isTarget || e.is_manual) {
      if (e.guru_id) addBusy(e.hari, e.guru_id, a, b);
    }
    if (isTarget && e.is_manual) {
      if (!manualSlots.has(e.kelas_id)) manualSlots.set(e.kelas_id, []);
      manualSlots.get(e.kelas_id).push([e.hari, a, b]);
    }
  }

  // hapus jadwal non-manual pada kelas target (akan dibuat ulang)
  const rows = [];
  let totalSlot = 0;
  let slotKosong = 0;
  const perKelas = [];

  for (const kelas of kelasList) {
    const kandidat = mapelRows.filter(
      (m) => m.tingkat === null || toNum(m.tingkat) === toNum(kelas.tingkat)
    );
    const pool = kandidat.length ? kandidat : mapelRows;

    // antrean bobot: mapel dengan jam_per_pekan lebih besar muncul lebih sering
    const antrean = [];
    for (const m of pool) {
      const jam = Math.max(1, toNum(m.jam_per_pekan, 2));
      for (let i = 0; i < jam; i += 1) antrean.push(m);
    }

    let idx = 0;
    let dibuat = 0;
    const manual = manualSlots.get(kelas.id) || [];

    for (const h of hari) {
      const slots = buildSlots(cfg, h, kelas.tingkat);
      const mapelHariIni = new Set();

      for (const slot of slots) {
        // jangan tabrak slot manual
        if (manual.some(([mh, ma, mb]) => mh === h && overlap(slot.mulai, slot.selesai, ma, mb))) {
          continue;
        }

        totalSlot += 1;

        if (slot.upacara) {
          rows.push([
            uuid(), sekolahId, kelas.id, null, null, h,
            toHHMMSS(slot.mulai), toHHMMSS(slot.selesai),
            kelas.ruangan || null, 'Upacara', tahunAjaran, semester, 0,
          ]);
          dibuat += 1;
          continue;
        }

        // cari mapel+guru yang cocok, maksimal satu putaran antrean
        let placed = false;
        for (let tries = 0; tries < antrean.length && !placed; tries += 1) {
          const m = antrean[(idx + tries) % antrean.length];
          const guruKandidat = pengampu.get(m.id) || [];

          // hindari mapel yang sama lebih dari 2x sehari jika masih ada pilihan lain
          if (mapelHariIni.has(m.id) && tries < antrean.length - 1) continue;

          const guruId = guruKandidat.find((gid) => !isBusy(h, gid, slot.mulai, slot.selesai));
          if (guruKandidat.length && !guruId) continue;

          rows.push([
            uuid(), sekolahId, kelas.id, m.id, guruId || null, h,
            toHHMMSS(slot.mulai), toHHMMSS(slot.selesai),
            kelas.ruangan || null, null, tahunAjaran, semester, 0,
          ]);
          if (guruId) addBusy(h, guruId, slot.mulai, slot.selesai);
          mapelHariIni.add(m.id);
          idx = (idx + tries + 1) % antrean.length;
          dibuat += 1;
          placed = true;
        }

        if (!placed) {
          // tidak ada guru yang tersedia: buat slot kosong agar bisa diisi manual
          rows.push([
            uuid(), sekolahId, kelas.id, null, null, h,
            toHHMMSS(slot.mulai), toHHMMSS(slot.selesai),
            kelas.ruangan || null, 'Belum terisi', tahunAjaran, semester, 0,
          ]);
          slotKosong += 1;
          dibuat += 1;
        }
      }
    }

    perKelas.push({
      kelas_id: kelas.id, nama_kelas: kelas.nama_kelas, tingkat: kelas.tingkat, slot: dibuat,
    });
  }

  await withTransaction(async (conn) => {
    for (const kelas of kelasList) {
      await conn.execute(
        `DELETE FROM jadwal WHERE kelas_id = ? AND (is_manual = 0 OR is_manual IS NULL)`,
        [kelas.id]
      );
    }
    // insert bertahap (chunk) agar query tidak terlalu panjang
    const CHUNK = 100;
    for (let i = 0; i < rows.length; i += CHUNK) {
      const chunk = rows.slice(i, i + CHUNK);
      const placeholders = chunk.map(() => '(?,?,?,?,?,?,?,?,?,?,?,?,?)').join(',');
      await conn.query(
        `INSERT INTO jadwal
           (id, sekolah_id, kelas_id, mapel_id, guru_id, hari, jam_mulai, jam_selesai,
            ruangan, keterangan, tahun_ajaran, semester, is_manual)
         VALUES ${placeholders}`,
        chunk.flat()
      );
    }
  });

  return {
    ok: true,
    message: `Jadwal berhasil dibuat: ${rows.length} slot untuk ${kelasList.length} kelas`
      + (slotKosong ? ` (${slotKosong} slot belum terisi guru)` : ''),
    data: {
      total_schedules: rows.length,
      total_slots: totalSlot,
      slot_kosong: slotKosong,
      total_kelas: kelasList.length,
      hari,
      per_kelas: perKelas,
    },
  };
}

module.exports = { generateJadwal, DEFAULT_CONFIG, buildSlots, HARI_URUT };
