-- ============================================================
-- STA Sekolah - Database Schema (MySQL 8)
-- ============================================================
SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

CREATE DATABASE IF NOT EXISTS sta_sekolah
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE sta_sekolah;

-- ------------------------------------------------------------
-- SEKOLAH
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sekolah (
  id              CHAR(36)      NOT NULL PRIMARY KEY,
  nama            VARCHAR(150)  NOT NULL,
  alamat          TEXT,
  telepon         VARCHAR(30),
  email           VARCHAR(120),
  website         VARCHAR(150),
  logo_url        VARCHAR(255),
  latitude        DECIMAL(10,7) DEFAULT 0,
  longitude       DECIMAL(10,7) DEFAULT 0,
  radius_maksimal INT           DEFAULT 150,
  jam_masuk       TIME          DEFAULT '07:00:00',
  jam_pulang      TIME          DEFAULT '13:30:00',
  created_at      TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
  updated_at      TIMESTAMP     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- USERS (login untuk semua role)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
  id         CHAR(36)     NOT NULL PRIMARY KEY,
  sekolah_id CHAR(36)     NOT NULL,
  username   VARCHAR(80)  NOT NULL,
  password   VARCHAR(255) NOT NULL,
  role       ENUM('siswa','guru','orang_tua','admin') NOT NULL,
  role_name  VARCHAR(60)  DEFAULT NULL,
  nama       VARCHAR(150) DEFAULT NULL,
  email      VARCHAR(120) DEFAULT NULL,
  jabatan    VARCHAR(60)  DEFAULT NULL,
  is_active  TINYINT(1)   DEFAULT 1,
  created_at TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_users_username (username),
  KEY idx_users_sekolah (sekolah_id),
  CONSTRAINT fk_users_sekolah FOREIGN KEY (sekolah_id) REFERENCES sekolah(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- GURU
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS guru (
  id            CHAR(36)     NOT NULL PRIMARY KEY,
  sekolah_id    CHAR(36)     NOT NULL,
  user_id       CHAR(36)     DEFAULT NULL,
  nama          VARCHAR(150) NOT NULL,
  nip           VARCHAR(40)  DEFAULT NULL,
  email         VARCHAR(120) DEFAULT NULL,
  no_hp         VARCHAR(30)  DEFAULT NULL,
  jenis_kelamin ENUM('L','P') DEFAULT 'L',
  alamat        TEXT,
  foto_url      VARCHAR(255) DEFAULT NULL,
  status        ENUM('aktif','nonaktif') DEFAULT 'aktif',
  created_at    TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMP    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_guru_sekolah (sekolah_id),
  KEY idx_guru_user (user_id),
  CONSTRAINT fk_guru_sekolah FOREIGN KEY (sekolah_id) REFERENCES sekolah(id) ON DELETE CASCADE,
  CONSTRAINT fk_guru_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- MAPEL
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mapel (
  id         CHAR(36)     NOT NULL PRIMARY KEY,
  sekolah_id CHAR(36)     NOT NULL,
  nama_mapel VARCHAR(120) NOT NULL,
  kode_mapel VARCHAR(20)  NOT NULL,
  tingkat    INT          DEFAULT NULL,
  jam_per_pekan INT       DEFAULT 2,
  created_at TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
  KEY idx_mapel_sekolah (sekolah_id),
  CONSTRAINT fk_mapel_sekolah FOREIGN KEY (sekolah_id) REFERENCES sekolah(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- GURU <-> MAPEL
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS guru_mapel (
  id         CHAR(36)  NOT NULL PRIMARY KEY,
  guru_id    CHAR(36)  NOT NULL,
  mapel_id   CHAR(36)  NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_guru_mapel (guru_id, mapel_id),
  CONSTRAINT fk_gm_guru  FOREIGN KEY (guru_id)  REFERENCES guru(id)  ON DELETE CASCADE,
  CONSTRAINT fk_gm_mapel FOREIGN KEY (mapel_id) REFERENCES mapel(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- KELAS
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS kelas (
  id            CHAR(36)     NOT NULL PRIMARY KEY,
  sekolah_id    CHAR(36)     NOT NULL,
  nama_kelas    VARCHAR(60)  NOT NULL,
  tingkat       INT          DEFAULT 1,
  kapasitas     INT          DEFAULT 28,
  tahun_ajaran  VARCHAR(20)  DEFAULT NULL,
  wali_kelas_id CHAR(36)     DEFAULT NULL,
  ruangan       VARCHAR(40)  DEFAULT NULL,
  created_at    TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMP    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_kelas_sekolah (sekolah_id),
  CONSTRAINT fk_kelas_sekolah FOREIGN KEY (sekolah_id) REFERENCES sekolah(id) ON DELETE CASCADE,
  CONSTRAINT fk_kelas_wali    FOREIGN KEY (wali_kelas_id) REFERENCES guru(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- SISWA
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS siswa (
  id            CHAR(36)     NOT NULL PRIMARY KEY,
  sekolah_id    CHAR(36)     NOT NULL,
  user_id       CHAR(36)     DEFAULT NULL,
  kelas_id      CHAR(36)     DEFAULT NULL,
  nama          VARCHAR(150) NOT NULL,
  nis           VARCHAR(30)  DEFAULT NULL,
  nisn          VARCHAR(30)  DEFAULT NULL,
  tempat_lahir  VARCHAR(100) DEFAULT NULL,
  tanggal_lahir DATE         DEFAULT NULL,
  jenis_kelamin ENUM('L','P') DEFAULT 'L',
  agama         VARCHAR(40)  DEFAULT NULL,
  alamat        TEXT,
  no_hp         VARCHAR(30)  DEFAULT NULL,
  email         VARCHAR(120) DEFAULT NULL,
  foto_url      VARCHAR(255) DEFAULT NULL,
  tahun_ajaran  VARCHAR(20)  DEFAULT NULL,
  semester      INT          DEFAULT 1,
  status        ENUM('aktif','lulus','pindah','nonaktif') DEFAULT 'aktif',
  created_at    TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMP    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_siswa_nis (sekolah_id, nis),
  KEY idx_siswa_kelas (kelas_id),
  KEY idx_siswa_user (user_id),
  CONSTRAINT fk_siswa_sekolah FOREIGN KEY (sekolah_id) REFERENCES sekolah(id) ON DELETE CASCADE,
  CONSTRAINT fk_siswa_kelas   FOREIGN KEY (kelas_id)   REFERENCES kelas(id)   ON DELETE SET NULL,
  CONSTRAINT fk_siswa_user    FOREIGN KEY (user_id)    REFERENCES users(id)   ON DELETE SET NULL
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- ORANG TUA
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS orang_tua (
  id      CHAR(36) NOT NULL PRIMARY KEY,
  sekolah_id CHAR(36) NOT NULL,
  user_id CHAR(36) DEFAULT NULL,

  nama_ibu                 VARCHAR(150) DEFAULT NULL,
  pekerjaan_ibu            VARCHAR(100) DEFAULT NULL,
  hp_ibu                   VARCHAR(30)  DEFAULT NULL,
  tahun_lahir_ibu          INT          DEFAULT NULL,
  jenjang_pendidikan_ibu   VARCHAR(40)  DEFAULT NULL,
  penghasilan_ibu          VARCHAR(60)  DEFAULT NULL,
  nik_ibu                  VARCHAR(30)  DEFAULT NULL,

  nama_ayah                VARCHAR(150) DEFAULT NULL,
  pekerjaan_ayah           VARCHAR(100) DEFAULT NULL,
  hp_ayah                  VARCHAR(30)  DEFAULT NULL,
  tahun_lahir_ayah         INT          DEFAULT NULL,
  jenjang_pendidikan_ayah  VARCHAR(40)  DEFAULT NULL,
  penghasilan_ayah         VARCHAR(60)  DEFAULT NULL,
  nik_ayah                 VARCHAR(30)  DEFAULT NULL,

  nama_wali                VARCHAR(150) DEFAULT NULL,
  pekerjaan_wali           VARCHAR(100) DEFAULT NULL,
  tahun_lahir_wali         INT          DEFAULT NULL,
  jenjang_pendidikan_wali  VARCHAR(40)  DEFAULT NULL,
  penghasilan_wali         VARCHAR(60)  DEFAULT NULL,

  alamat     TEXT,
  email      VARCHAR(120) DEFAULT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_ortu_user (user_id),
  CONSTRAINT fk_ortu_sekolah FOREIGN KEY (sekolah_id) REFERENCES sekolah(id) ON DELETE CASCADE,
  CONSTRAINT fk_ortu_user    FOREIGN KEY (user_id)    REFERENCES users(id)   ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS siswa_orang_tua (
  id           CHAR(36) NOT NULL PRIMARY KEY,
  siswa_id     CHAR(36) NOT NULL,
  orang_tua_id CHAR(36) NOT NULL,
  hubungan     VARCHAR(30) DEFAULT 'orang_tua',
  UNIQUE KEY uq_siswa_ortu (siswa_id, orang_tua_id),
  CONSTRAINT fk_so_siswa FOREIGN KEY (siswa_id)     REFERENCES siswa(id)     ON DELETE CASCADE,
  CONSTRAINT fk_so_ortu  FOREIGN KEY (orang_tua_id) REFERENCES orang_tua(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- JADWAL
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS jadwal (
  id           CHAR(36)    NOT NULL PRIMARY KEY,
  sekolah_id   CHAR(36)    NOT NULL,
  kelas_id     CHAR(36)    NOT NULL,
  mapel_id     CHAR(36)    DEFAULT NULL,
  guru_id      CHAR(36)    DEFAULT NULL,
  hari         ENUM('Senin','Selasa','Rabu','Kamis','Jumat','Sabtu') NOT NULL,
  jam_mulai    TIME        NOT NULL,
  jam_selesai  TIME        NOT NULL,
  ruangan      VARCHAR(40) DEFAULT NULL,
  keterangan   VARCHAR(80) DEFAULT NULL,
  tahun_ajaran VARCHAR(20) DEFAULT NULL,
  semester     INT         DEFAULT 1,
  is_manual    TINYINT(1)  DEFAULT 0,
  created_at   TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
  KEY idx_jadwal_kelas (kelas_id, hari),
  KEY idx_jadwal_guru (guru_id),
  CONSTRAINT fk_jadwal_sekolah FOREIGN KEY (sekolah_id) REFERENCES sekolah(id) ON DELETE CASCADE,
  CONSTRAINT fk_jadwal_kelas   FOREIGN KEY (kelas_id)   REFERENCES kelas(id)   ON DELETE CASCADE,
  CONSTRAINT fk_jadwal_mapel   FOREIGN KEY (mapel_id)   REFERENCES mapel(id)   ON DELETE SET NULL,
  CONSTRAINT fk_jadwal_guru    FOREIGN KEY (guru_id)    REFERENCES guru(id)    ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS schedule_config (
  sekolah_id CHAR(36) NOT NULL PRIMARY KEY,
  config     JSON     NOT NULL,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_sconf_sekolah FOREIGN KEY (sekolah_id) REFERENCES sekolah(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- ABSENSI SISWA
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS absensi (
  id              CHAR(36)   NOT NULL PRIMARY KEY,
  siswa_id        CHAR(36)   NOT NULL,
  kelas_id        CHAR(36)   DEFAULT NULL,
  tanggal         DATE       NOT NULL,
  status          ENUM('hadir','izin','sakit','alpha','terlambat') DEFAULT 'hadir',
  jam_masuk       TIME       DEFAULT NULL,
  jam_pulang      TIME       DEFAULT NULL,
  keterangan      TEXT,
  latitude        VARCHAR(40) DEFAULT NULL,
  longitude       VARCHAR(40) DEFAULT NULL,
  jarak           VARCHAR(20) DEFAULT NULL,
  device          VARCHAR(60) DEFAULT NULL,
  approval_status ENUM('','pending','approved','rejected') DEFAULT '',
  approval_note   TEXT,
  approved_by     CHAR(36)   DEFAULT NULL,
  approved_at     DATETIME   DEFAULT NULL,
  created_at      TIMESTAMP  DEFAULT CURRENT_TIMESTAMP,
  updated_at      TIMESTAMP  DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_absensi (siswa_id, tanggal),
  KEY idx_absensi_tanggal (tanggal),
  CONSTRAINT fk_absensi_siswa FOREIGN KEY (siswa_id) REFERENCES siswa(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- ABSENSI GURU
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS absensi_guru (
  id         CHAR(36)  NOT NULL PRIMARY KEY,
  guru_id    CHAR(36)  NOT NULL,
  tanggal    DATE      NOT NULL,
  jam_masuk  TIME      DEFAULT NULL,
  jam_keluar TIME      DEFAULT NULL,
  status     ENUM('hadir','izin','sakit','alpha') DEFAULT 'hadir',
  keterangan TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_absensi_guru (guru_id, tanggal),
  CONSTRAINT fk_ag_guru FOREIGN KEY (guru_id) REFERENCES guru(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- NILAI
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS nilai (
  id           CHAR(36)    NOT NULL PRIMARY KEY,
  siswa_id     CHAR(36)    NOT NULL,
  mapel_id     CHAR(36)    NOT NULL,
  guru_id      CHAR(36)    DEFAULT NULL,
  semester     INT         DEFAULT 1,
  tahun_ajaran VARCHAR(20) DEFAULT NULL,
  nilai_tugas  DECIMAL(5,2) DEFAULT 0,
  nilai_uts    DECIMAL(5,2) DEFAULT 0,
  nilai_uas    DECIMAL(5,2) DEFAULT 0,
  nilai_akhir  DECIMAL(5,2) DEFAULT 0,
  predikat     VARCHAR(5)  DEFAULT NULL,
  catatan      TEXT,
  created_at   TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
  updated_at   TIMESTAMP   DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_nilai (siswa_id, mapel_id, semester, tahun_ajaran),
  KEY idx_nilai_siswa (siswa_id),
  CONSTRAINT fk_nilai_siswa FOREIGN KEY (siswa_id) REFERENCES siswa(id) ON DELETE CASCADE,
  CONSTRAINT fk_nilai_mapel FOREIGN KEY (mapel_id) REFERENCES mapel(id) ON DELETE CASCADE,
  CONSTRAINT fk_nilai_guru  FOREIGN KEY (guru_id)  REFERENCES guru(id)  ON DELETE SET NULL
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- TUGAS
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tugas (
  id         CHAR(36)     NOT NULL PRIMARY KEY,
  sekolah_id CHAR(36)     NOT NULL,
  kelas_id   CHAR(36)     NOT NULL,
  mapel_id   CHAR(36)     DEFAULT NULL,
  guru_id    CHAR(36)     DEFAULT NULL,
  judul      VARCHAR(200) NOT NULL,
  deskripsi  TEXT,
  deadline   DATETIME     DEFAULT NULL,
  status     ENUM('aktif','selesai','draft') DEFAULT 'aktif',
  created_at TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_tugas_kelas (kelas_id),
  KEY idx_tugas_guru (guru_id),
  CONSTRAINT fk_tugas_sekolah FOREIGN KEY (sekolah_id) REFERENCES sekolah(id) ON DELETE CASCADE,
  CONSTRAINT fk_tugas_kelas   FOREIGN KEY (kelas_id)   REFERENCES kelas(id)   ON DELETE CASCADE,
  CONSTRAINT fk_tugas_mapel   FOREIGN KEY (mapel_id)   REFERENCES mapel(id)   ON DELETE SET NULL,
  CONSTRAINT fk_tugas_guru    FOREIGN KEY (guru_id)    REFERENCES guru(id)    ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS tugas_submission (
  id           CHAR(36)     NOT NULL PRIMARY KEY,
  tugas_id     CHAR(36)     NOT NULL,
  siswa_id     CHAR(36)     NOT NULL,
  file_nama    VARCHAR(255) DEFAULT NULL,
  file_url     VARCHAR(255) DEFAULT NULL,
  catatan      TEXT,
  submitted_at DATETIME     DEFAULT NULL,
  nilai        DECIMAL(5,2) DEFAULT NULL,
  feedback     TEXT,
  graded_at    DATETIME     DEFAULT NULL,
  graded_by    CHAR(36)     DEFAULT NULL,
  UNIQUE KEY uq_submission (tugas_id, siswa_id),
  CONSTRAINT fk_sub_tugas FOREIGN KEY (tugas_id) REFERENCES tugas(id) ON DELETE CASCADE,
  CONSTRAINT fk_sub_siswa FOREIGN KEY (siswa_id) REFERENCES siswa(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- PENGUMUMAN
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS pengumuman (
  id          CHAR(36)     NOT NULL PRIMARY KEY,
  sekolah_id  CHAR(36)     NOT NULL,
  judul       VARCHAR(200) NOT NULL,
  isi         TEXT,
  kategori    VARCHAR(40)  DEFAULT 'umum',
  prioritas   ENUM('rendah','normal','tinggi') DEFAULT 'normal',
  target_role VARCHAR(40)  DEFAULT 'semua',
  created_by  CHAR(36)     DEFAULT NULL,
  created_at  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
  KEY idx_peng_sekolah (sekolah_id),
  CONSTRAINT fk_peng_sekolah FOREIGN KEY (sekolah_id) REFERENCES sekolah(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS pengumuman_read (
  id            CHAR(36)  NOT NULL PRIMARY KEY,
  pengumuman_id CHAR(36)  NOT NULL,
  user_id       CHAR(36)  NOT NULL,
  read_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_peng_read (pengumuman_id, user_id),
  CONSTRAINT fk_pr_peng FOREIGN KEY (pengumuman_id) REFERENCES pengumuman(id) ON DELETE CASCADE,
  CONSTRAINT fk_pr_user FOREIGN KEY (user_id)       REFERENCES users(id)      ON DELETE CASCADE
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- KEUANGAN / SPP
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS jenis_pembayaran (
  id              CHAR(36)     NOT NULL PRIMARY KEY,
  sekolah_id      CHAR(36)     NOT NULL,
  nama            VARCHAR(120) NOT NULL,
  kode            VARCHAR(30)  DEFAULT NULL,
  nominal_default BIGINT       DEFAULT 0,
  tipe            ENUM('bulanan','tahunan','sekali') DEFAULT 'bulanan',
  is_active       TINYINT(1)   DEFAULT 1,
  created_at      TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
  KEY idx_jp_sekolah (sekolah_id),
  CONSTRAINT fk_jp_sekolah FOREIGN KEY (sekolah_id) REFERENCES sekolah(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS tagihan (
  id                   CHAR(36) NOT NULL PRIMARY KEY,
  sekolah_id           CHAR(36) NOT NULL,
  siswa_id             CHAR(36) NOT NULL,
  jenis_pembayaran_id  CHAR(36) NOT NULL,
  periode_bulan        INT      NOT NULL,
  periode_tahun        INT      NOT NULL,
  nominal              BIGINT   DEFAULT 0,
  diskon               BIGINT   DEFAULT 0,
  nominal_akhir        BIGINT   DEFAULT 0,
  tanggal_jatuh_tempo  DATE     DEFAULT NULL,
  status               ENUM('belum_bayar','menunggu_verifikasi','lunas','batal') DEFAULT 'belum_bayar',
  keterangan           TEXT,
  created_at           TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at           TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_tagihan (siswa_id, jenis_pembayaran_id, periode_bulan, periode_tahun),
  KEY idx_tagihan_periode (periode_tahun, periode_bulan),
  CONSTRAINT fk_tag_sekolah FOREIGN KEY (sekolah_id) REFERENCES sekolah(id) ON DELETE CASCADE,
  CONSTRAINT fk_tag_siswa   FOREIGN KEY (siswa_id)   REFERENCES siswa(id)   ON DELETE CASCADE,
  CONSTRAINT fk_tag_jp      FOREIGN KEY (jenis_pembayaran_id) REFERENCES jenis_pembayaran(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS pembayaran (
  id                 CHAR(36)     NOT NULL PRIMARY KEY,
  sekolah_id         CHAR(36)     NOT NULL,
  tagihan_id         CHAR(36)     NOT NULL,
  siswa_id           CHAR(36)     NOT NULL,
  dibayar_oleh       CHAR(36)     DEFAULT NULL,
  jumlah_bayar       BIGINT       DEFAULT 0,
  metode_bayar       VARCHAR(40)  DEFAULT 'transfer_bank',
  nomor_referensi    VARCHAR(80)  DEFAULT NULL,
  catatan            TEXT,
  bukti_transfer_url VARCHAR(255) DEFAULT NULL,
  tanggal_bayar      DATETIME     DEFAULT CURRENT_TIMESTAMP,
  status             ENUM('pending','approved','rejected') DEFAULT 'pending',
  verified_by        CHAR(36)     DEFAULT NULL,
  verified_at        DATETIME     DEFAULT NULL,
  verify_note        TEXT,
  created_at         TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
  KEY idx_bayar_status (status),
  KEY idx_bayar_tagihan (tagihan_id),
  CONSTRAINT fk_bayar_sekolah FOREIGN KEY (sekolah_id) REFERENCES sekolah(id) ON DELETE CASCADE,
  CONSTRAINT fk_bayar_tagihan FOREIGN KEY (tagihan_id) REFERENCES tagihan(id) ON DELETE CASCADE,
  CONSTRAINT fk_bayar_siswa   FOREIGN KEY (siswa_id)   REFERENCES siswa(id)   ON DELETE CASCADE
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- HARI LIBUR
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS hari_libur (
  id         CHAR(36)     NOT NULL PRIMARY KEY,
  sekolah_id CHAR(36)     NOT NULL,
  tanggal    DATE         NOT NULL,
  keterangan VARCHAR(200) DEFAULT NULL,
  created_at TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_libur (sekolah_id, tanggal),
  CONSTRAINT fk_libur_sekolah FOREIGN KEY (sekolah_id) REFERENCES sekolah(id) ON DELETE CASCADE
) ENGINE=InnoDB;

SET FOREIGN_KEY_CHECKS = 1;
