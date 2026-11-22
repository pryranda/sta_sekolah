'use strict';

const crypto = require('crypto');

const uuid = () => crypto.randomUUID();

/** Response sukses dengan bentuk { success, message, data } yang dipakai app Flutter. */
function ok(res, data = null, message = 'OK', extra = {}) {
  return res.json({ success: true, message, data, ...extra });
}

function fail(res, message = 'Terjadi kesalahan', status = 400, extra = {}) {
  return res.status(status).json({ success: false, message, data: null, ...extra });
}

/** Tanggal hari ini sebagai 'YYYY-MM-DD' pada zona waktu server. */
function todayStr(d = new Date()) {
  const p = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

/** Jam sekarang sebagai 'HH:MM:SS'. */
function nowTimeStr(d = new Date()) {
  const p = (n) => String(n).padStart(2, '0');
  return `${p(d.getHours())}:${p(d.getMinutes())}:${p(d.getSeconds())}`;
}

function nowDateTimeStr(d = new Date()) {
  return `${todayStr(d)} ${nowTimeStr(d)}`;
}

function toNum(v, def = 0) {
  if (v === null || v === undefined || v === '') return def;
  const n = Number(v);
  return Number.isFinite(n) ? n : def;
}

function toIntOrNull(v) {
  if (v === null || v === undefined || v === '') return null;
  const n = parseInt(v, 10);
  return Number.isFinite(n) ? n : null;
}

/** Nilai akhir = 30% tugas + 30% UTS + 40% UAS. */
function hitungNilaiAkhir(tugas, uts, uas) {
  const t = toNum(tugas), u = toNum(uts), a = toNum(uas);
  return Math.round((t * 0.3 + u * 0.3 + a * 0.4) * 100) / 100;
}

function predikat(nilai) {
  const n = toNum(nilai);
  if (n >= 90) return 'A';
  if (n >= 80) return 'B';
  if (n >= 70) return 'C';
  if (n >= 60) return 'D';
  return 'E';
}

/** Ubah nilai undefined menjadi null agar aman untuk mysql2. */
function nz(...vals) {
  return vals.map((v) => (v === undefined ? null : v));
}

/** Jarak haversine dalam meter. */
function jarakMeter(lat1, lon1, lat2, lon2) {
  const R = 6371000;
  const toRad = (x) => (x * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return Math.round(R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a)));
}

/** Potong 'HH:MM:SS' -> 'HH:MM' (app memanggil substring(0,5) pada beberapa tempat). */
function hhmm(t) {
  if (!t) return null;
  return String(t).slice(0, 5);
}

const asyncHandler = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

module.exports = {
  uuid, ok, fail, todayStr, nowTimeStr, nowDateTimeStr,
  toNum, toIntOrNull, hitungNilaiAkhir, predikat, nz,
  jarakMeter, hhmm, asyncHandler,
};
