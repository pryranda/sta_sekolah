'use strict';

const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const multer = require('multer');
const config = require('../config');

function makeUploader(subdir, allowed) {
  const dest = path.join(config.uploadDir, subdir);
  fs.mkdirSync(dest, { recursive: true });

  const storage = multer.diskStorage({
    destination: (_req, _file, cb) => cb(null, dest),
    filename: (_req, file, cb) => {
      const ext = path.extname(file.originalname || '').toLowerCase().slice(0, 10);
      cb(null, `${Date.now()}-${crypto.randomBytes(6).toString('hex')}${ext}`);
    },
  });

  return multer({
    storage,
    limits: { fileSize: 10 * 1024 * 1024 }, // 10 MB
    fileFilter: (_req, file, cb) => {
      const ext = path.extname(file.originalname || '').toLowerCase().replace('.', '');
      if (!allowed.length || allowed.includes(ext)) return cb(null, true);
      return cb(new Error(`Tipe file .${ext} tidak diizinkan`));
    },
  });
}

const uploadTugas = makeUploader('tugas', ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'jpg', 'jpeg', 'png', 'zip', 'rar', 'txt']);
const uploadBukti = makeUploader('bukti', ['jpg', 'jpeg', 'png', 'pdf', 'webp', 'heic']);
// SVG sengaja tidak diizinkan: bisa memuat <script> dan dilayani apa adanya
// dari /uploads, sementara aplikasi merender logo dengan Image.network yang
// tidak bisa membaca SVG.
const uploadLogo = makeUploader('logo', ['jpg', 'jpeg', 'png', 'webp']);

module.exports = { makeUploader, uploadTugas, uploadBukti, uploadLogo };
