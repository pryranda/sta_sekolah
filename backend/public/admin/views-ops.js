'use strict';

window.STA = window.STA || {};

(function (STA) {
  const { apiFetch } = STA.api;
  const { esc, formatRp, formatDate, toast, openModal, closeModal, confirmDialog } = STA.ui;

  // ====================================================================
  // JADWAL PELAJARAN & HARI LIBUR
  // ====================================================================
  async function renderJadwal(root) {
    root.innerHTML = `
      <div class="tabs">
        <button class="tab-btn active" data-tab="jadwal">Jadwal Pelajaran</button>
        <button class="tab-btn" data-tab="libur">Hari Libur</button>
      </div>
      <div id="jadwal-tab-body"></div>
    `;

    let tab = 'jadwal';
    root.querySelectorAll('.tab-btn').forEach((btn) => {
      btn.onclick = () => {
        root.querySelectorAll('.tab-btn').forEach((b) => b.classList.remove('active'));
        btn.classList.add('active');
        tab = btn.dataset.tab;
        renderTab();
      };
    });

    async function renderTab() {
      const box = root.querySelector('#jadwal-tab-body');
      if (tab === 'libur') {
        await renderHolidaysTab(box);
        return;
      }

      const [kelasRes, mapelRes, guruRes] = await Promise.all([
        apiFetch('/admin/kelas'),
        apiFetch('/admin/mapel'),
        apiFetch('/admin/guru'),
      ]);
      const kelasList = kelasRes.data || [];
      const mapelList = mapelRes.data || [];
      const guruList = guruRes.data || [];

      box.innerHTML = `
        <div class="card">
          <div class="toolbar">
            <div class="toolbar-filters">
              <select id="jdw-kelas">
                ${kelasList.length
                  ? kelasList.map((k) => `<option value="${esc(k.id)}">${esc(k.nama_kelas)} (Tingkat ${esc(k.tingkat)})</option>`).join('')
                  : '<option value="">Belum ada kelas</option>'}
              </select>
              <select id="jdw-hari">
                <option value="">Semua Hari</option>
                ${['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'].map((h) => `<option value="${h}">${h}</option>`).join('')}
              </select>
            </div>
            <div class="toolbar-actions">
              <button id="btn-jdw-config" class="btn btn-outline btn-sm">Konfigurasi Jam</button>
              <button id="btn-jdw-clear" class="btn btn-danger-soft btn-sm">Kosongkan Kelas</button>
              <button id="btn-jdw-gen" class="btn btn-primary">Generate Jadwal Otomatis</button>
            </div>
          </div>
          <div class="table-wrap">
            <table>
              <thead>
                <tr><th>Hari</th><th>Jam</th><th>Mata Pelajaran</th><th>Guru</th><th>Keterangan</th><th>Aksi</th></tr>
              </thead>
              <tbody id="jdw-tbody"><tr><td colspan="6" class="empty-state">Pilih kelas...</td></tr></tbody>
            </table>
          </div>
        </div>
      `;

      const kelasSel = box.querySelector('#jdw-kelas');
      const hariSel = box.querySelector('#jdw-hari');

      async function loadJadwal() {
        const kelasId = kelasSel.value;
        const tbody = box.querySelector('#jdw-tbody');
        if (!kelasId) {
          tbody.innerHTML = '<tr><td colspan="6" class="empty-state">Belum ada kelas tersedia.</td></tr>';
          return;
        }
        const qs = hariSel.value ? `?hari=${encodeURIComponent(hariSel.value)}` : '';
        const rows = (await apiFetch(`/admin/schedule/kelas/${kelasId}${qs}`)).data || [];
        if (!rows.length) {
          tbody.innerHTML = '<tr><td colspan="6" class="empty-state">Jadwal kelas masih kosong. Klik "Generate Jadwal Otomatis".</td></tr>';
          return;
        }
        tbody.innerHTML = rows.map((j) => `
          <tr>
            <td><strong>${esc(j.hari)}</strong></td>
            <td><code>${esc(String(j.jam_mulai || '').slice(0, 5))} - ${esc(String(j.jam_selesai || '').slice(0, 5))}</code></td>
            <td>${esc(j.nama_mapel || j.keterangan || '-')}</td>
            <td>${esc(j.guru_nama || '-')}</td>
            <td>${j.is_manual ? '<span class="badge badge-yellow">Manual</span>' : '<span class="badge badge-gray">Otomatis</span>'}</td>
            <td>
              <div class="row-actions">
                <button class="btn btn-outline btn-sm" data-edit="${esc(j.id)}">Edit</button>
                <button class="btn btn-danger-soft btn-sm" data-del="${esc(j.id)}">Hapus</button>
              </div>
            </td>
          </tr>
        `).join('');

        tbody.querySelectorAll('[data-edit]').forEach((b) => {
          b.onclick = () => openSlotModal(rows.find((x) => x.id === b.dataset.edit), mapelList, guruList, loadJadwal);
        });
        tbody.querySelectorAll('[data-del]').forEach((b) => {
          b.onclick = async () => {
            await apiFetch(`/admin/schedule/manual/${b.dataset.del}`, { method: 'DELETE' });
            toast('Slot jadwal dihapus', 'success');
            loadJadwal();
          };
        });
      }

      kelasSel.onchange = loadJadwal;
      hariSel.onchange = loadJadwal;
      box.querySelector('#btn-jdw-config').onclick = () => openScheduleConfigModal();
      box.querySelector('#btn-jdw-gen').onclick = () => openGenerateScheduleModal(kelasList, loadJadwal);
      box.querySelector('#btn-jdw-clear').onclick = async () => {
        if (!kelasSel.value) return;
        if (!(await confirmDialog('Kosongkan Jadwal', 'Hapus seluruh jadwal untuk kelas ini?'))) return;
        await apiFetch(`/admin/schedule/kelas/${kelasSel.value}`, { method: 'DELETE' });
        toast('Jadwal kelas dikosongkan', 'success');
        loadJadwal();
      };

      await loadJadwal();
    }

    await renderTab();
  }

  function openSlotModal(slot, mapelList, guruList, onSaved) {
    const wrap = document.createElement('form');
    wrap.className = 'form-stack';
    wrap.innerHTML = `
      <div class="form-grid">
        <div class="form-group">
          <label>Jam Mulai</label>
          <input name="jam_mulai" type="time" value="${esc(String(slot.jam_mulai || '').slice(0, 5))}" required />
        </div>
        <div class="form-group">
          <label>Jam Selesai</label>
          <input name="jam_selesai" type="time" value="${esc(String(slot.jam_selesai || '').slice(0, 5))}" required />
        </div>
        <div class="form-group">
          <label>Mata Pelajaran</label>
          <select name="mapel_id">
            <option value="">-- Kosong / Upacara --</option>
            ${mapelList.map((m) => `<option value="${esc(m.id)}" ${slot.mapel_id === m.id ? 'selected' : ''}>${esc(m.nama_mapel)}</option>`).join('')}
          </select>
        </div>
        <div class="form-group">
          <label>Guru Pengampu</label>
          <select name="guru_id">
            <option value="">-- Belum Terisi --</option>
            ${guruList.map((g) => `<option value="${esc(g.id)}" ${slot.guru_id === g.id ? 'selected' : ''}>${esc(g.nama)}</option>`).join('')}
          </select>
        </div>
      </div>
      <div class="modal-footer">
        <button type="button" class="btn btn-outline" id="sl-cancel">Batal</button>
        <button type="submit" class="btn btn-primary">Simpan Slot</button>
      </div>
    `;
    wrap.querySelector('#sl-cancel').onclick = closeModal;
    wrap.onsubmit = async (e) => {
      e.preventDefault();
      const body = Object.fromEntries(new FormData(wrap).entries());
      try {
        await apiFetch(`/admin/schedule/${slot.id}`, { method: 'PUT', body });
        toast('Slot jadwal diperbarui', 'success');
        closeModal();
        onSaved();
      } catch (err) {
        toast(err.message, 'error');
      }
    };
    openModal(`Edit Jadwal (${slot.hari})`, wrap);
  }

  async function openScheduleConfigModal() {
    const res = await apiFetch('/admin/schedule/config');
    const cfg = res.data || {};
    const wrap = document.createElement('form');
    wrap.className = 'form-stack';
    wrap.innerHTML = `
      <div class="form-grid">
        <div class="form-group"><label>Jam Mulai</label><input name="startTime" type="time" value="${esc(cfg.startTime || '07:00')}" /></div>
        <div class="form-group"><label>Durasi per Jam Pelajaran (menit)</label><input name="lessonDuration" type="number" value="${esc(cfg.lessonDuration ?? 30)}" /></div>
        <div class="form-group"><label>Jam Pulang Kelas 1-3</label><input name="endTimeLower" type="time" value="${esc(cfg.endTimeLower || '13:30')}" /></div>
        <div class="form-group"><label>Jam Pulang Kelas 4+</label><input name="endTimeUpper" type="time" value="${esc(cfg.endTimeUpper || '14:30')}" /></div>
        <div class="form-group"><label>Hari Upacara</label><input name="upacaraDay" type="text" value="${esc(cfg.upacaraDay || 'Senin')}" /></div>
        <div class="form-group"><label>Durasi Upacara (menit)</label><input name="upacaraDuration" type="number" value="${esc(cfg.upacaraDuration ?? 60)}" /></div>
        <div class="form-group full">
          <label>Jam Istirahat (JSON array)</label>
          <textarea name="breaks">${esc(JSON.stringify(cfg.breaks || []))}</textarea>
        </div>
      </div>
      <div class="modal-footer">
        <button type="button" class="btn btn-outline" id="sc-cancel">Batal</button>
        <button type="submit" class="btn btn-primary">Simpan Konfigurasi</button>
      </div>
    `;
    wrap.querySelector('#sc-cancel').onclick = closeModal;
    wrap.onsubmit = async (e) => {
      e.preventDefault();
      const raw = Object.fromEntries(new FormData(wrap).entries());
      try {
        const body = {
          startTime: raw.startTime,
          lessonDuration: Number(raw.lessonDuration || 30),
          endTimeLower: raw.endTimeLower,
          endTimeUpper: raw.endTimeUpper,
          upacaraDay: raw.upacaraDay,
          upacaraDuration: Number(raw.upacaraDuration || 60),
          breaks: JSON.parse(raw.breaks || '[]'),
        };
        await apiFetch('/admin/schedule/config', { method: 'PUT', body });
        toast('Konfigurasi jadwal disimpan', 'success');
        closeModal();
      } catch (err) {
        toast(err.message, 'error');
      }
    };
    openModal('Konfigurasi Jam Pelajaran', wrap);
  }

  function openGenerateScheduleModal(kelasList, onDone) {
    const wrap = document.createElement('form');
    wrap.className = 'form-stack';
    wrap.innerHTML = `
      <div class="form-group">
        <label>Pilih Kelas yang Akan Digenerate (tahan Ctrl/Cmd untuk pilih banyak)</label>
        <select name="kelas_ids" multiple size="5" required>
          ${kelasList.map((k) => `<option value="${esc(k.id)}" selected>${esc(k.nama_kelas)}</option>`).join('')}
        </select>
      </div>
      <div class="form-grid">
        <div class="form-group"><label>Tahun Ajaran</label><input name="tahun_ajaran" type="text" value="2026/2027" /></div>
        <div class="form-group"><label>Semester</label><select name="semester"><option value="1">1 (Ganjil)</option><option value="2">2 (Genap)</option></select></div>
      </div>
      <div class="modal-footer">
        <button type="button" class="btn btn-outline" id="gs-cancel">Batal</button>
        <button type="submit" class="btn btn-primary">Generate Jadwal</button>
      </div>
    `;
    wrap.querySelector('#gs-cancel').onclick = closeModal;
    wrap.onsubmit = async (e) => {
      e.preventDefault();
      const kelas_ids = Array.from(wrap.querySelector('[name="kelas_ids"]').selectedOptions).map((o) => o.value);
      const tahun_ajaran = wrap.querySelector('[name="tahun_ajaran"]').value.trim();
      const semester = Number(wrap.querySelector('[name="semester"]').value);
      try {
        const res = await apiFetch('/admin/schedule/generate', {
          method: 'POST',
          body: { kelas_ids, tahun_ajaran, semester },
        });
        toast(res.message || 'Jadwal berhasil dibuat', 'success');
        closeModal();
        onDone();
      } catch (err) {
        toast(err.message, 'error');
      }
    };
    openModal('Generate Jadwal Otomatis', wrap);
  }

  async function renderHolidaysTab(box) {
    const rows = (await apiFetch('/admin/holidays')).data || [];
    box.innerHTML = `
      <div class="card">
        <div class="card-header"><h3 class="card-title">Tambah Hari Libur</h3></div>
        <form id="hol-form" class="toolbar" style="margin-bottom:0;">
          <div class="toolbar-filters">
            <input name="tanggal" type="date" required />
            <input name="keterangan" type="text" placeholder="Keterangan hari libur..." style="min-width:260px;" required />
          </div>
          <button type="submit" class="btn btn-primary">+ Tambah</button>
        </form>
      </div>
      <div class="card">
        <div class="table-wrap">
          <table>
            <thead><tr><th>Tanggal</th><th>Keterangan</th><th>Aksi</th></tr></thead>
            <tbody>
              ${rows.length ? rows.map((h) => `
                <tr>
                  <td><strong>${esc(formatDate(h.tanggal))}</strong></td>
                  <td>${esc(h.keterangan || '-')}</td>
                  <td><button class="btn btn-danger-soft btn-sm" data-del-hol="${esc(h.id)}">Hapus</button></td>
                </tr>
              `).join('') : '<tr><td colspan="3" class="empty-state">Belum ada hari libur terdaftar.</td></tr>'}
            </tbody>
          </table>
        </div>
      </div>
    `;
    box.querySelector('#hol-form').onsubmit = async (e) => {
      e.preventDefault();
      const body = Object.fromEntries(new FormData(e.target).entries());
      try {
        await apiFetch('/admin/holidays', { method: 'POST', body });
        toast('Hari libur ditambahkan', 'success');
        renderHolidaysTab(box);
      } catch (err) {
        toast(err.message, 'error');
      }
    };
    box.querySelectorAll('[data-del-hol]').forEach((b) => {
      b.onclick = async () => {
        await apiFetch(`/admin/holidays/${b.dataset.delHol}`, { method: 'DELETE' });
        toast('Hari libur dihapus', 'success');
        renderHolidaysTab(box);
      };
    });
  }

  // ====================================================================
  // PENGUMUMAN
  // ====================================================================
  async function renderPengumuman(root) {
    root.innerHTML = `
      <div class="card">
        <div class="toolbar">
          <h3 class="card-title">Pengumuman Sekolah</h3>
          <button id="btn-ann-add" class="btn btn-primary">+ Buat Pengumuman</button>
        </div>
        <div class="table-wrap">
          <table>
            <thead><tr><th>Judul</th><th>Kategori</th><th>Prioritas</th><th>Target</th><th>Dibaca</th><th>Tanggal</th><th>Aksi</th></tr></thead>
            <tbody id="ann-tbody"><tr><td colspan="7" class="empty-state">Memuat pengumuman...</td></tr></tbody>
          </table>
        </div>
      </div>
    `;

    async function load() {
      const rows = (await apiFetch('/admin/pengumuman')).data || [];
      const tbody = root.querySelector('#ann-tbody');
      if (!rows.length) {
        tbody.innerHTML = '<tr><td colspan="7" class="empty-state">Belum ada pengumuman.</td></tr>';
        return;
      }
      tbody.innerHTML = rows.map((p) => `
        <tr>
          <td><strong>${esc(p.judul)}</strong><div class="hint">${esc(String(p.isi || '').slice(0, 90))}</div></td>
          <td>${esc(p.kategori || 'umum')}</td>
          <td><span class="badge ${p.prioritas === 'tinggi' ? 'badge-red' : 'badge-blue'}">${esc(p.prioritas)}</span></td>
          <td>${esc(p.target_role || 'semua')}</td>
          <td>${esc(p.dibaca_oleh ?? 0)}</td>
          <td>${esc(formatDate(p.created_at))}</td>
          <td><button class="btn btn-danger-soft btn-sm" data-del="${esc(p.id)}">Hapus</button></td>
        </tr>
      `).join('');
      tbody.querySelectorAll('[data-del]').forEach((b) => {
        b.onclick = async () => {
          if (!(await confirmDialog('Hapus Pengumuman', 'Hapus pengumuman ini?'))) return;
          await apiFetch(`/admin/pengumuman/${b.dataset.del}`, { method: 'DELETE' });
          toast('Pengumuman dihapus', 'success');
          load();
        };
      });
    }

    root.querySelector('#btn-ann-add').onclick = () => {
      const wrap = document.createElement('form');
      wrap.className = 'form-stack';
      wrap.innerHTML = `
        <div class="form-grid">
          <div class="form-group full"><label>Judul *</label><input name="judul" type="text" required /></div>
          <div class="form-group"><label>Kategori</label><input name="kategori" type="text" value="umum" /></div>
          <div class="form-group">
            <label>Prioritas</label>
            <select name="prioritas"><option value="normal">normal</option><option value="tinggi">tinggi</option><option value="rendah">rendah</option></select>
          </div>
          <div class="form-group full">
            <label>Target Role</label>
            <select name="target_role"><option value="semua">semua</option><option value="siswa">siswa</option><option value="orang_tua">orang_tua</option><option value="guru">guru</option></select>
          </div>
          <div class="form-group full"><label>Isi Pengumuman</label><textarea name="isi" rows="4"></textarea></div>
        </div>
        <div class="modal-footer">
          <button type="button" class="btn btn-outline" id="an-cancel">Batal</button>
          <button type="submit" class="btn btn-primary">Publikasikan</button>
        </div>
      `;
      wrap.querySelector('#an-cancel').onclick = closeModal;
      wrap.onsubmit = async (e) => {
        e.preventDefault();
        try {
          await apiFetch('/admin/pengumuman', { method: 'POST', body: Object.fromEntries(new FormData(wrap).entries()) });
          toast('Pengumuman dipublikasikan', 'success');
          closeModal();
          load();
        } catch (err) {
          toast(err.message, 'error');
        }
      };
      openModal('Buat Pengumuman Baru', wrap);
    };

    await load();
  }

  // ====================================================================
  // KEUANGAN / SPP
  // ====================================================================
  async function renderSpp(root) {
    root.innerHTML = `
      <div class="tabs">
        <button class="tab-btn active" data-tab="pending">Verifikasi Pending</button>
        <button class="tab-btn" data-tab="tagihan">Daftar Tagihan</button>
        <button class="tab-btn" data-tab="generate">Generate Tagihan</button>
        <button class="tab-btn" data-tab="jenis">Jenis Pembayaran</button>
        <button class="tab-btn" data-tab="laporan">Laporan Keuangan</button>
      </div>
      <div id="spp-tab-body"></div>
    `;

    let tab = 'pending';
    root.querySelectorAll('.tab-btn').forEach((b) => {
      b.onclick = () => {
        root.querySelectorAll('.tab-btn').forEach((x) => x.classList.remove('active'));
        b.classList.add('active');
        tab = b.dataset.tab;
        renderTab();
      };
    });

    async function renderTab() {
      const box = root.querySelector('#spp-tab-body');
      if (tab === 'pending') await renderSppPending(box);
      else if (tab === 'tagihan') await renderSppTagihan(box);
      else if (tab === 'generate') await renderSppGenerate(box);
      else if (tab === 'jenis') await renderSppJenis(box);
      else await renderSppLaporan(box);
    }

    await renderTab();
  }

  async function renderSppPending(box) {
    const rows = (await apiFetch('/spp/admin/pembayaran/pending')).data || [];
    STA.state.pendingCount = rows.length;
    STA.updateSidebarBadges();

    box.innerHTML = `
      <div class="card">
        <div class="card-header"><h3 class="card-title">Pembayaran Menunggu Verifikasi (${rows.length})</h3></div>
        <div class="table-wrap">
          <table>
            <thead><tr><th>Siswa</th><th>Tagihan</th><th>Jumlah Bayar</th><th>Orang Tua</th><th>Bukti</th><th>Aksi</th></tr></thead>
            <tbody>
              ${rows.length ? rows.map((p) => `
                <tr>
                  <td><strong>${esc(p.nama_siswa)}</strong><div class="hint">NIS ${esc(p.nis || '-')} · ${esc(p.nama_kelas || '-')}</div></td>
                  <td>${esc(p.jenis_pembayaran)}<div class="hint">${esc(p.periode_bulan)}/${esc(p.periode_tahun)}</div></td>
                  <td><strong>${esc(formatRp(p.jumlah_bayar))}</strong><div class="hint">${esc(p.metode_bayar)}</div></td>
                  <td>${esc(p.nama_orang_tua || '-')}</td>
                  <td>${p.bukti_transfer_url ? `<a class="btn btn-outline btn-sm" href="${esc(p.bukti_transfer_url)}" target="_blank" rel="noopener">Lihat Bukti</a>` : '<span class="hint">-</span>'}</td>
                  <td>
                    <div class="row-actions">
                      <button class="btn btn-primary btn-sm" data-verify="approved" data-id="${esc(p.id)}">Setujui</button>
                      <button class="btn btn-danger-soft btn-sm" data-verify="rejected" data-id="${esc(p.id)}">Tolak</button>
                    </div>
                  </td>
                </tr>
              `).join('') : '<tr><td colspan="6" class="empty-state">Tidak ada pembayaran yang menunggu verifikasi.</td></tr>'}
            </tbody>
          </table>
        </div>
      </div>
    `;

    box.querySelectorAll('[data-verify]').forEach((btn) => {
      btn.onclick = async () => {
        const action = btn.dataset.verify;
        const note = window.prompt(action === 'approved' ? 'Catatan persetujuan (opsional):' : 'Alasan penolakan (opsional):', '') ?? null;
        if (note === null) return;
        try {
          const res = await apiFetch(`/spp/admin/pembayaran/${btn.dataset.id}/verify`, {
            method: 'POST',
            body: { action, note },
          });
          toast(res.message || 'Berhasil diverifikasi', 'success');
          renderSppPending(box);
        } catch (err) {
          toast(err.message, 'error');
        }
      };
    });
  }

  async function renderSppTagihan(box) {
    const kelasList = (await apiFetch('/admin/kelas')).data || [];
    const now = new Date();
    box.innerHTML = `
      <div class="card">
        <div class="toolbar">
          <div class="toolbar-filters">
            <input id="tg-tahun" type="number" value="${now.getFullYear()}" style="width:95px;" />
            <select id="tg-bulan"><option value="">Semua Bulan</option>${Array.from({ length: 12 }, (_, i) => `<option value="${i + 1}">Bulan ${i + 1}</option>`).join('')}</select>
            <select id="tg-status">
              <option value="">Semua Status</option>
              <option value="belum_bayar">belum_bayar</option>
              <option value="menunggu_verifikasi">menunggu_verifikasi</option>
              <option value="lunas">lunas</option>
            </select>
            <select id="tg-kelas"><option value="">Semua Kelas</option>${kelasList.map((k) => `<option value="${esc(k.id)}">${esc(k.nama_kelas)}</option>`).join('')}</select>
          </div>
        </div>
        <div class="table-wrap">
          <table>
            <thead><tr><th>Siswa</th><th>Kelas</th><th>Jenis</th><th>Periode</th><th>Nominal</th><th>Status</th></tr></thead>
            <tbody id="tg-tbody"><tr><td colspan="6" class="empty-state">Memuat tagihan...</td></tr></tbody>
          </table>
        </div>
      </div>
    `;

    async function load() {
      const qs = new URLSearchParams();
      const t = box.querySelector('#tg-tahun').value;
      const b = box.querySelector('#tg-bulan').value;
      const s = box.querySelector('#tg-status').value;
      const k = box.querySelector('#tg-kelas').value;
      if (t) qs.set('tahun', t);
      if (b) qs.set('bulan', b);
      if (s) qs.set('status', s);
      if (k) qs.set('kelas_id', k);
      const rows = (await apiFetch(`/spp/admin/tagihan?${qs}`)).data || [];
      const tbody = box.querySelector('#tg-tbody');
      tbody.innerHTML = rows.length ? rows.map((r) => `
        <tr>
          <td><strong>${esc(r.nama_siswa)}</strong><div class="hint">NIS ${esc(r.nis || '-')}</div></td>
          <td>${esc(r.nama_kelas || '-')}</td>
          <td>${esc(r.jenis_pembayaran)}</td>
          <td>${esc(r.periode_bulan)}/${esc(r.periode_tahun)}</td>
          <td>${esc(formatRp(r.nominal_akhir))}</td>
          <td><span class="badge ${r.status === 'lunas' ? 'badge-green' : r.status === 'menunggu_verifikasi' ? 'badge-yellow' : 'badge-red'}">${esc(r.status)}</span></td>
        </tr>
      `).join('') : '<tr><td colspan="6" class="empty-state">Tidak ada tagihan.</td></tr>';
    }

    ['#tg-tahun', '#tg-bulan', '#tg-status', '#tg-kelas'].forEach((sel) => {
      box.querySelector(sel).onchange = load;
    });
    await load();
  }

  async function renderSppGenerate(box) {
    const [jenisRes, kelasRes] = await Promise.all([
      apiFetch('/spp/admin/jenis-pembayaran'),
      apiFetch('/admin/kelas'),
    ]);
    const jenisList = jenisRes.data || [];
    const kelasList = kelasRes.data || [];
    const year = new Date().getFullYear();

    box.innerHTML = `
      <div class="card">
        <div class="card-header"><h3 class="card-title">Generate Tagihan Massal (Satu Jenis Pembayaran)</h3></div>
        <form id="gen1-form" class="form-stack">
          <div class="form-grid">
            <div class="form-group">
              <label>Jenis Pembayaran *</label>
              <select name="jenis_pembayaran_id" required>
                ${jenisList.map((j) => `<option value="${esc(j.id)}">${esc(j.nama)} (${esc(formatRp(j.nominal_default))})</option>`).join('')}
              </select>
            </div>
            <div class="form-group">
              <label>Kelas (opsional, kosong = semua)</label>
              <select name="kelas_id">
                <option value="">Semua Kelas</option>
                ${kelasList.map((k) => `<option value="${esc(k.id)}">${esc(k.nama_kelas)}</option>`).join('')}
              </select>
            </div>
            <div class="form-group"><label>Tahun</label><input name="tahun" type="number" value="${year}" required /></div>
            <div class="form-group"><label>Nominal Override (opsional)</label><input name="nominal_override" type="number" placeholder="Kosong = nominal default" /></div>
            <div class="form-group"><label>Bulan Mulai</label><input name="bulan_mulai" type="number" min="1" max="12" value="1" required /></div>
            <div class="form-group"><label>Bulan Selesai</label><input name="bulan_selesai" type="number" min="1" max="12" value="12" required /></div>
          </div>
          <div><button type="submit" class="btn btn-primary" ${!jenisList.length ? 'disabled' : ''}>Generate Tagihan</button></div>
        </form>
      </div>

      <div class="card">
        <div class="card-header"><h3 class="card-title">Generate Semua Jenis Pembayaran Sekaligus</h3></div>
        <form id="genall-form" class="form-grid">
          <div class="form-group"><label>Tahun</label><input name="tahun" type="number" value="${year}" required /></div>
          <div class="form-group"><label>Bulan Mulai</label><input name="bulan_mulai" type="number" min="1" max="12" value="1" required /></div>
          <div class="form-group"><label>Bulan Selesai</label><input name="bulan_selesai" type="number" min="1" max="12" value="12" required /></div>
          <div class="form-group" style="justify-content:flex-end;"><button type="submit" class="btn btn-soft" ${!jenisList.length ? 'disabled' : ''}>Generate Semua Jenis</button></div>
        </form>
      </div>
    `;

    box.querySelector('#gen1-form').onsubmit = async (e) => {
      e.preventDefault();
      const raw = Object.fromEntries(new FormData(e.target).entries());
      const body = {
        jenis_pembayaran_id: raw.jenis_pembayaran_id,
        tahun: Number(raw.tahun),
        bulan_mulai: Number(raw.bulan_mulai),
        bulan_selesai: Number(raw.bulan_selesai),
      };
      if (raw.kelas_id) body.kelas_id = raw.kelas_id;
      if (raw.nominal_override !== '') body.nominal_override = Number(raw.nominal_override);
      try {
        const res = await apiFetch('/spp/admin/tagihan/generate-massal', { method: 'POST', body });
        toast(res.message || 'Tagihan berhasil dibuat', 'success');
      } catch (err) {
        toast(err.message, 'error');
      }
    };

    box.querySelector('#genall-form').onsubmit = async (e) => {
      e.preventDefault();
      const raw = Object.fromEntries(new FormData(e.target).entries());
      try {
        const res = await apiFetch('/spp/admin/tagihan/generate-all', {
          method: 'POST',
          body: { tahun: Number(raw.tahun), bulan_mulai: Number(raw.bulan_mulai), bulan_selesai: Number(raw.bulan_selesai) },
        });
        toast(res.message || 'Semua tagihan dibuat', 'success');
      } catch (err) {
        toast(err.message, 'error');
      }
    };
  }

  async function renderSppJenis(box) {
    const rows = (await apiFetch('/spp/admin/jenis-pembayaran')).data || [];
    box.innerHTML = `
      <div class="card">
        <div class="card-header"><h3 class="card-title">Tambah Jenis Pembayaran</h3></div>
        <form id="jp-form" class="toolbar" style="margin-bottom:0;">
          <div class="toolbar-filters">
            <input name="nama" type="text" placeholder="Nama (mis. SPP Bulanan)" required />
            <input name="kode" type="text" placeholder="Kode (SPP)" style="width:110px;" />
            <input name="nominal_default" type="number" placeholder="Nominal Default" required />
            <select name="tipe"><option value="bulanan">bulanan</option><option value="tahunan">tahunan</option><option value="sekali">sekali</option></select>
          </div>
          <button type="submit" class="btn btn-primary">+ Tambah</button>
        </form>
      </div>
      <div class="card">
        <div class="table-wrap">
          <table>
            <thead><tr><th>Nama</th><th>Kode</th><th>Nominal Default</th><th>Tipe</th></tr></thead>
            <tbody>
              ${rows.length ? rows.map((j) => `
                <tr><td><strong>${esc(j.nama)}</strong></td><td><code>${esc(j.kode || '-')}</code></td><td>${esc(formatRp(j.nominal_default))}</td><td>${esc(j.tipe)}</td></tr>
              `).join('') : '<tr><td colspan="4" class="empty-state">Belum ada jenis pembayaran.</td></tr>'}
            </tbody>
          </table>
        </div>
      </div>
    `;
    box.querySelector('#jp-form').onsubmit = async (e) => {
      e.preventDefault();
      try {
        await apiFetch('/spp/admin/jenis-pembayaran', { method: 'POST', body: Object.fromEntries(new FormData(e.target).entries()) });
        toast('Jenis pembayaran ditambahkan', 'success');
        renderSppJenis(box);
      } catch (err) {
        toast(err.message, 'error');
      }
    };
  }

  async function renderSppLaporan(box) {
    const now = new Date();
    box.innerHTML = `
      <div class="card">
        <div class="toolbar">
          <div class="toolbar-filters">
            <select id="lap-bulan">${Array.from({ length: 12 }, (_, i) => `<option value="${i + 1}" ${i + 1 === now.getMonth() + 1 ? 'selected' : ''}>Bulan ${i + 1}</option>`).join('')}</select>
            <input id="lap-tahun" type="number" value="${now.getFullYear()}" style="width:100px;" />
          </div>
        </div>
        <div id="lap-body"></div>
      </div>
    `;
    async function load() {
      const b = box.querySelector('#lap-bulan').value;
      const t = box.querySelector('#lap-tahun').value;
      const d = (await apiFetch(`/spp/admin/laporan?bulan=${b}&tahun=${t}`)).data || {};
      const r = d.ringkasan || {};
      box.querySelector('#lap-body').innerHTML = `
        <div class="stats-grid">
          <div class="stat-card"><div class="stat-label">Total Tagihan</div><div class="stat-value">${esc(formatRp(r.total_nominal))}</div></div>
          <div class="stat-card accent"><div class="stat-label">Total Terbayar</div><div class="stat-value">${esc(formatRp(r.total_terbayar))}</div></div>
          <div class="stat-card"><div class="stat-label">Tunggakan</div><div class="stat-value">${esc(formatRp(r.tunggakan))}</div></div>
          <div class="stat-card"><div class="stat-label">Realisasi</div><div class="stat-value">${esc(r.persentase_pembayaran ?? 0)}%</div></div>
        </div>
        <h4 style="margin:14px 0 8px;">Top Tunggakan Siswa</h4>
        <div class="table-wrap">
          <table>
            <thead><tr><th>Siswa</th><th>Kelas</th><th>Jumlah Tagihan</th><th>Total Tunggakan</th></tr></thead>
            <tbody>
              ${(d.top_tunggakan || []).length ? d.top_tunggakan.map((x) => `
                <tr><td><strong>${esc(x.nama)}</strong> (${esc(x.nis)})</td><td>${esc(x.nama_kelas || '-')}</td><td>${esc(x.jumlah_tagihan)}</td><td>${esc(formatRp(x.total_tunggakan))}</td></tr>
              `).join('') : '<tr><td colspan="4" class="empty-state">Tidak ada tunggakan.</td></tr>'}
            </tbody>
          </table>
        </div>
      `;
    }
    box.querySelector('#lap-bulan').onchange = load;
    box.querySelector('#lap-tahun').onchange = load;
    await load();
  }

  // ====================================================================
  // PENGATURAN SEKOLAH
  // ====================================================================
  async function renderSekolahSettings(root) {
    const res = await apiFetch(`/sekolah/info?sekolah_id=${encodeURIComponent(STA.state.user.sekolah_id || '')}`);
    const s = res.data || {};
    root.innerHTML = `
      <div class="card">
        <div class="card-header"><h3 class="card-title">Logo & Identitas Sekolah</h3></div>
        <div style="display:flex;align-items:center;gap:16px;margin-bottom:16px;flex-wrap:wrap;">
          <img id="set-logo-preview" src="${esc(s.logo_url || '')}" alt="Logo" style="width:72px;height:72px;border-radius:12px;object-fit:cover;border:1px solid var(--border);${s.logo_url ? '' : 'display:none;'}" />
          <div>
            <input id="set-logo-file" type="file" accept="image/png,image/jpeg,image/webp" class="hidden" />
            <button type="button" id="btn-upload-logo" class="btn btn-soft btn-sm">Unggah Logo Baru (PNG/JPG/WEBP)</button>
            <div class="hint" style="margin-top:4px;">Logo otomatis tersimpan dan muncul di aplikasi & panel admin.</div>
          </div>
        </div>
        <form id="set-info-form" class="form-stack">
          <div class="form-grid">
            <div class="form-group"><label>Nama Sekolah *</label><input name="nama" type="text" value="${esc(s.nama || '')}" required /></div>
            <div class="form-group"><label>Telepon</label><input name="telepon" type="text" value="${esc(s.telepon || '')}" /></div>
            <div class="form-group"><label>Email</label><input name="email" type="email" value="${esc(s.email || '')}" /></div>
            <div class="form-group"><label>Website</label><input name="website" type="text" value="${esc(s.website || '')}" /></div>
            <div class="form-group"><label>Jam Masuk</label><input name="jam_masuk" type="time" value="${esc(String(s.jam_masuk || '07:00').slice(0, 5))}" /></div>
            <div class="form-group"><label>Jam Pulang</label><input name="jam_pulang" type="time" value="${esc(String(s.jam_pulang || '13:30').slice(0, 5))}" /></div>
            <div class="form-group full"><label>URL Logo</label><input id="set-logo-url" name="logo_url" type="text" value="${esc(s.logo_url || '')}" /></div>
            <div class="form-group full"><label>Alamat</label><textarea name="alamat">${esc(s.alamat || '')}</textarea></div>
          </div>
          <div><button type="submit" class="btn btn-primary">Simpan Profil Sekolah</button></div>
        </form>
      </div>

      <div class="card">
        <div class="card-header">
          <h3 class="card-title">Lokasi & Radius Absensi GPS</h3>
          <button type="button" id="btn-gps-now" class="btn btn-outline btn-sm">Ambil Lokasi Browser</button>
        </div>
        <form id="set-loc-form" class="form-stack">
          <div class="form-grid">
            <div class="form-group"><label>Latitude</label><input id="set-lat" name="latitude" type="text" value="${esc(s.latitude || '0')}" /></div>
            <div class="form-group"><label>Longitude</label><input id="set-lng" name="longitude" type="text" value="${esc(s.longitude || '0')}" /></div>
            <div class="form-group"><label>Radius Maksimal (meter)</label><input name="radius_maksimal" type="number" value="${esc(s.radius_maksimal || 150)}" /></div>
          </div>
          <div><button type="submit" class="btn btn-primary">Simpan Lokasi GPS</button></div>
        </form>
      </div>
    `;

    root.querySelector('#btn-upload-logo').onclick = () => root.querySelector('#set-logo-file').click();
    root.querySelector('#set-logo-file').onchange = async (e) => {
      const file = e.target.files?.[0];
      if (!file) return;
      const fd = new FormData();
      fd.append('logo', file);
      try {
        const up = await apiFetch('/sekolah/upload-logo', { method: 'POST', body: fd });
        const url = up.data?.url || '';
        root.querySelector('#set-logo-url').value = url;
        const img = root.querySelector('#set-logo-preview');
        img.src = url;
        img.style.display = 'block';
        toast('Logo berhasil diunggah. Klik "Simpan Profil Sekolah" untuk menerapkan.', 'success');
      } catch (err) {
        toast(err.message, 'error');
      }
    };

    root.querySelector('#set-info-form').onsubmit = async (e) => {
      e.preventDefault();
      const body = Object.fromEntries(new FormData(e.target).entries());
      if (body.jam_masuk && body.jam_masuk.length === 5) body.jam_masuk += ':00';
      if (body.jam_pulang && body.jam_pulang.length === 5) body.jam_pulang += ':00';
      try {
        await apiFetch('/sekolah/info', { method: 'PUT', body });
        toast('Profil sekolah disimpan', 'success');
        STA.loadSchoolHeader();
      } catch (err) {
        toast(err.message, 'error');
      }
    };

    root.querySelector('#btn-gps-now').onclick = () => {
      if (!navigator.geolocation) return toast('Browser tidak mendukung geolocation', 'error');
      navigator.geolocation.getCurrentPosition(
        (pos) => {
          root.querySelector('#set-lat').value = pos.coords.latitude.toFixed(7);
          root.querySelector('#set-lng').value = pos.coords.longitude.toFixed(7);
          toast('Koordinat GPS diambil', 'success');
        },
        (err) => toast(`Gagal mengambil lokasi: ${err.message}`, 'error')
      );
    };

    root.querySelector('#set-loc-form').onsubmit = async (e) => {
      e.preventDefault();
      try {
        await apiFetch('/sekolah/lokasi', { method: 'PUT', body: Object.fromEntries(new FormData(e.target).entries()) });
        toast('Lokasi absensi diperbarui', 'success');
      } catch (err) {
        toast(err.message, 'error');
      }
    };
  }

  // ====================================================================
  // SUPERADMIN — KELOLA SEKOLAH
  // ====================================================================
  async function renderSuperadminSekolah(root) {
    const rows = (await apiFetch('/sekolah')).data || [];
    root.innerHTML = `
      <div class="card">
        <div class="toolbar">
          <h3 class="card-title">Daftar Sekolah Terdaftar (${rows.length})</h3>
          <button id="btn-sa-add" class="btn btn-primary">+ Daftarkan Sekolah Baru</button>
        </div>
        <div class="table-wrap">
          <table>
            <thead><tr><th>Nama Sekolah</th><th>Siswa</th><th>Guru</th><th>Kelas</th><th>Admin</th><th>Aksi</th></tr></thead>
            <tbody>
              ${rows.length ? rows.map((s) => `
                <tr>
                  <td><strong>${esc(s.nama)}</strong><div class="hint">${esc(s.alamat || '')}</div></td>
                  <td>${esc(s.jumlah_siswa)}</td>
                  <td>${esc(s.jumlah_guru)}</td>
                  <td>${esc(s.jumlah_kelas)}</td>
                  <td>${esc(s.jumlah_admin)}</td>
                  <td><button class="btn btn-danger-soft btn-sm" data-del-sch="${esc(s.id)}">Hapus</button></td>
                </tr>
              `).join('') : '<tr><td colspan="6" class="empty-state">Belum ada sekolah.</td></tr>'}
            </tbody>
          </table>
        </div>
      </div>
    `;

    root.querySelector('#btn-sa-add').onclick = () => {
      const wrap = document.createElement('form');
      wrap.className = 'form-stack';
      wrap.innerHTML = `
        <div class="form-grid">
          <div class="form-group full"><label>Nama Sekolah *</label><input name="nama" type="text" required /></div>
          <div class="form-group"><label>Username Admin Pertama *</label><input name="admin_username" type="text" required /></div>
          <div class="form-group"><label>Password Admin *</label><input name="admin_password" type="password" required /></div>
          <div class="form-group full"><label>Alamat</label><textarea name="alamat"></textarea></div>
        </div>
        <div class="modal-footer">
          <button type="button" class="btn btn-outline" id="sa-cancel">Batal</button>
          <button type="submit" class="btn btn-primary">Daftarkan Sekolah</button>
        </div>
      `;
      wrap.querySelector('#sa-cancel').onclick = closeModal;
      wrap.onsubmit = async (e) => {
        e.preventDefault();
        try {
          await apiFetch('/sekolah', { method: 'POST', body: Object.fromEntries(new FormData(wrap).entries()) });
          toast('Sekolah berhasil didaftarkan', 'success');
          closeModal();
          renderSuperadminSekolah(root);
        } catch (err) {
          toast(err.message, 'error');
        }
      };
      openModal('Daftarkan Sekolah Baru', wrap);
    };

    root.querySelectorAll('[data-del-sch]').forEach((b) => {
      b.onclick = async () => {
        const s = rows.find((x) => x.id === b.dataset.delSch);
        if (!s) return;
        const typed = window.prompt(`Ketik nama sekolah persis "${s.nama}" untuk menghapus seluruh datanya:`);
        if (typed !== s.nama) return;
        try {
          await apiFetch(`/sekolah/${s.id}`, { method: 'DELETE', body: { konfirmasi: typed } });
          toast('Sekolah dihapus', 'success');
          renderSuperadminSekolah(root);
        } catch (err) {
          toast(err.message, 'error');
        }
      };
    });
  }

  STA.viewsOps = {
    renderJadwal,
    renderPengumuman,
    renderSpp,
    renderSekolahSettings,
    renderSuperadminSekolah,
  };
})(window.STA);
