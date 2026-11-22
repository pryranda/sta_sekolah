-- ============================================================
-- Migrasi 001 — dukungan banyak sekolah + peran superadmin
--
-- Aman dijalankan berulang.
-- ============================================================
USE sta_sekolah;

-- Peran baru: superadmin (admin aplikasi, bekerja lintas sekolah).
ALTER TABLE users
  MODIFY COLUMN role ENUM('siswa','guru','orang_tua','admin','superadmin') NOT NULL;

-- Superadmin tidak terikat pada satu sekolah, jadi sekolah_id boleh kosong.
ALTER TABLE users
  MODIFY COLUMN sekolah_id CHAR(36) NULL;

-- Nama sekolah dijadikan unik supaya tidak ada dua sekolah bernama sama.
SET @ada := (
  SELECT COUNT(*) FROM information_schema.STATISTICS
   WHERE TABLE_SCHEMA = 'sta_sekolah'
     AND TABLE_NAME = 'sekolah'
     AND INDEX_NAME = 'uq_sekolah_nama'
);
SET @sql := IF(@ada = 0,
  'ALTER TABLE sekolah ADD UNIQUE KEY uq_sekolah_nama (nama)',
  'SELECT "uq_sekolah_nama sudah ada" AS info');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
