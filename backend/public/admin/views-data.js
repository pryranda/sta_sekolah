'use strict';

window.STA = window.STA || {};

(function (STA) {
  const { apiFetch } = STA.api;
  const { esc, formatDate, toast, openModal, closeModal, confirmDialog } = STA.ui;
  const { openImportWizard, downloadCsv } = STA.csv;

  // Helper umum untuk import dengan fallback per-baris jika /import belum tersedia di server.
  async function importWithFallback(importPath, singlePath, payload, rows, mapSingleRow, onProgress) {
    try {
      const res = await apiFetch(importPath, { method: 'POST', body: payload });
      if (onProgress) onProgress(rows.length, rows.length);
      return res.data;
    } catch (err) {
      if (err.status !== 404) throw err;
      const results = [];
      let berhasil = 0;
      let gagal = 0;
      for (let i = 0; i < rows.length; i += 1) {
        try {
          const singleBody = mapSingleRow ? mapSingleRow(rows[i]) : rows[i];
          await apiFetch(singlePath, { method: 'POST', body: singleBody });
          berhasil += 1;
          results.push({ row: i + 1, status: 'ok', message: 'Berhasil ditambahkan' });
        } catch (rowErr) {
          gagal += 1;
          results.push({ row: i + 1, status: 'error', message: rowErr.message });
        }
        if (onProgress) onProgress(i + 1, rows.length);
      }
      return { total: rows.length, berhasil, gagal, results };
    }
  }

  // ====================================================================
  // DASHBOARD
  // ====================================================================
  async function renderDashboard(root) {
    root.innerHTML = '<div class="empty-state">Memuat ringkasan...</div>';
    const [dashRes, sekolahRes] = await Promise.all([
      apiFetch('/admin/dashboard'),
      apiFetch(`/sekolah/info?sekolah_id=${encodeURIComponent(STA.state.user.sekolah_id || '')}`).catch(() => ({ data: null })),
    ]);
    const d = dashRes.data || {};
    const s = sekolahRes.data;
    STA.state.pendingCount = Number(d.pembayaran_pending || 0);
    STA.updateSidebarBadges();

    root.innerHTML = `
      <div class="stats-grid">
        <div class="stat-card accent">
          <div class="stat-label">Siswa Aktif</div>
          <div class="stat-value">${esc(d.total_siswa ?? 0)}</div>
        </div>
        <div class="stat-card">
          <div class="stat-label">Guru Aktif</div>
          <div class="stat-value">${esc(d.total_guru ?? 0)}</div>
        </div>
        <div class="stat-card">
          <div class="stat-label">Jumlah Kelas</div>
          <div class="stat-value">${esc(d.total_kelas ?? 0)}</div>
        </div>
        <div class="stat-card">
          <div class="stat-label">Mata Pelajaran</div>
          <div class="stat-value">${esc(d.total_mapel ?? 0)}</div>
        </div>
        <div class="stat-card">
          <div class="stat-label">Verifikasi SPP Pending</div>
          <div class="stat-value" style="color:${d.pembayaran_pending > 0 ? 'var(--danger)' : 'inherit'}">
            ${esc(d.pembayaran_pending ?? 0)}
          </div>
        </div>
      </div>

      <div class="card">
        <div class="card-header">
          <h3 class="card-title">Aksi Cepat Admin</h3>
        </div>
        <div class="quick-actions">
          <button class="btn btn-primary" data-go="siswa-import">Upload CSV / Excel Siswa</button>
          <button class="btn btn-soft" data-go="siswa">Kelola Data Siswa</button>
          <button class="btn btn-outline" data-go="guru">Kelola Data Guru</button>
          <button class="btn btn-outline" data-go="spp">Verifikasi & Tagihan SPP</button>
          <button class="btn btn-outline" data-go="jadwal">Atur & Generate Jadwal</button>
          <button class="btn btn-outline" data-go="sekolah">Pengaturan Sekolah</button>
        </div>
      </div>

      ${s ? `
        <div class="card">
          <div class="card-header">
            <h3 class="card-title">Identitas Sekolah</h3>
            <button class="btn btn-outline btn-sm" data-go="sekolah">Ubah Pengaturan</button>
          </div>
          <div class="form-grid">
            <div><span class="hint">Nama Sekolah</span><div style="font-weight:700;">${esc(s.nama)}</div></div>
            <div><span class="hint">Telepon / Email</span><div>${esc(s.telepon || '-')} &middot; ${esc(s.email || '-')}</div></div>
            <div><span class="hint">Jam Masuk / Pulang</span><div>${esc((s.jam_masuk || '-').slice(0, 5))} - ${esc((s.jam_pulang || '-').slice(0, 5))}</div></div>
            <div><span class="hint">Koordinat & Radius GPS</span><div>${esc(s.latitude)}, ${esc(s.longitude)} (${esc(s.radius_maksimal)} m)</div></div>
            <div class="form-group full"><span class="hint">Alamat</span><div>${esc(s.alamat || '-')}</div></div>
          </div>
        </div>
      ` : ''}
    `;

    root.querySelectorAll('[data-go]').forEach((btn) => {
      btn.onclick = () => {
        const target = btn.dataset.go;
        if (target === 'siswa-import') {
          STA.navigate('siswa').then(() => {
            const impBtn = document.getElementById('btn-siswa-import');
            if (impBtn) impBtn.click();
          });
        } else {
          STA.navigate(target);
        }
      };
    });
  }

  // ====================================================================
  // SISWA + IMPORT CSV
  // ====================================================================
  async function renderSiswa(root) {
    root.innerHTML = `
      <div class="card">
        <div class="toolbar">
          <div class="toolbar-filters">
            <input id="siswa-search" type="text" placeholder="Cari nama / NIS / NISN..." style="min-width:220px;" />
            <select id="siswa-filter-kelas"><option value="">Semua Kelas</option></select>
            <select id="siswa-filter-status">
              <option value="">Semua Status</option>
              <option value="aktif">Aktif</option>
              <option value="lulus">Lulus</option>
              <option value="pindah">Pindah</option>
              <option value="nonaktif">Nonaktif</option>
            </select>
          </div>
          <div class="toolbar-actions">
            <button id="btn-siswa-export" class="btn btn-outline btn-sm">Export CSV</button>
            <button id="btn-siswa-import" class="btn btn-soft">Upload CSV / Excel</button>
            <button id="btn-siswa-add" class="btn btn-primary">+ Tambah Siswa</button>
          </div>
        </div>
        <div class="table-wrap">
          <table>
            <thead>
              <tr>
                <th>NIS / NISN</th>
                <th>Nama Lengkap</th>
                <th>Kelas</th>
                <th>JK</th>
                <th>Username</th>
                <th>Status</th>
                <th>Orang Tua</th>
                <th>Aksi</th>
              </tr>
            </thead>
            <tbody id="siswa-tbody">
              <tr><td colspan="8" class="empty-state">Memuat data siswa...</td></tr>
            </tbody>
          </table>
        </div>
      </div>
    `;

    const kelasRes = await apiFetch('/admin/kelas');
    const kelasList = kelasRes.data || [];
    const kelasSel = root.querySelector('#siswa-filter-kelas');
    kelasList.forEach((k) => {
      const opt = document.createElement('option');
      opt.value = k.id;
      opt.textContent = k.nama_kelas;
      kelasSel.appendChild(opt);
    });

    let currentRows = [];

    async function loadRows() {
      const qs = new URLSearchParams();
      const search = root.querySelector('#siswa-search').value.trim();
      const kelasId = kelasSel.value;
      const status = root.querySelector('#siswa-filter-status').value;
      if (search) qs.set('search', search);
      if (kelasId) qs.set('kelas_id', kelasId);
      if (status) qs.set('status', status);

      const res = await apiFetch(`/admin/siswa${qs.toString() ? `?${qs}` : ''}`);
      currentRows = res.data || [];
      const tbody = root.querySelector('#siswa-tbody');

      if (!currentRows.length) {
        tbody.innerHTML = '<tr><td colspan="8" class="empty-state">Belum ada data siswa sesuai filter.</td></tr>';
        return;
      }

      tbody.innerHTML = currentRows.map((s) => `
        <tr>
          <td>
            <div style="font-weight:700;">${esc(s.nis || '-')}</div>
            <div class="hint">${esc(s.nisn || '')}</div>
          </td>
          <td>
            <div style="font-weight:600;">${esc(s.nama)}</div>
            <div class="hint">${esc(s.email || s.no_hp || '')}</div>
          </td>
          <td>${s.nama_kelas ? `<span class="badge badge-blue">${esc(s.nama_kelas)}</span>` : '<span class="hint">-</span>'}</td>
          <td>${esc(s.jenis_kelamin || '-')}</td>
          <td><code>${esc(s.username || '-')}</code></td>
          <td><span class="badge ${s.status === 'aktif' ? 'badge-green' : 'badge-gray'}">${esc(s.status)}</span></td>
          <td>${esc(s.nama_ibu || s.nama_ayah || '-')}</td>
          <td>
            <div class="row-actions">
              <button class="btn btn-outline btn-sm" data-edit="${esc(s.id)}">Ubah</button>
              <button class="btn btn-danger-soft btn-sm" data-del="${esc(s.id)}">Hapus</button>
            </div>
          </td>
        </tr>
      `).join('');

      tbody.querySelectorAll('[data-edit]').forEach((b) => {
        b.onclick = () => {
          const item = currentRows.find((x) => x.id === b.dataset.edit);
          if (item) openSiswaForm(item, kelasList, loadRows);
        };
      });
      tbody.querySelectorAll('[data-del]').forEach((b) => {
        b.onclick = async () => {
          const item = currentRows.find((x) => x.id === b.dataset.del);
          if (!item) return;
          const ok = await confirmDialog('Hapus Siswa', `Hapus siswa "${item.nama}" beserta akun loginnya?`);
          if (!ok) return;
          try {
            await apiFetch(`/admin/siswa/${item.id}`, { method: 'DELETE' });
            toast(`Siswa ${item.nama} dihapus`, 'success');
            loadRows();
          } catch (err) {
            toast(err.message, 'error');
          }
        };
      });
    }

    let searchTimer = null;
    root.querySelector('#siswa-search').oninput = () => {
      clearTimeout(searchTimer);
      searchTimer = setTimeout(loadRows, 250);
    };
    kelasSel.onchange = loadRows;
    root.querySelector('#siswa-filter-status').onchange = loadRows;

    root.querySelector('#btn-siswa-add').onclick = () => openSiswaForm(null, kelasList, loadRows);
    root.querySelector('#btn-siswa-export').onclick = () => {
      if (!currentRows.length) return toast('Tidak ada data untuk diexport', 'error');
      downloadCsv(
        'data-siswa.csv',
        ['nis', 'nisn', 'nama', 'nama_kelas', 'jenis_kelamin', 'tempat_lahir', 'tanggal_lahir', 'agama', 'no_hp', 'email', 'alamat', 'username', 'status'],
        currentRows
      );
    };
    root.querySelector('#btn-siswa-import').onclick = () => openSiswaImport(kelasList, loadRows);

    await loadRows();
  }

  function openSiswaForm(siswa, kelasList, onSaved) {
    const isEdit = Boolean(siswa);
    const wrap = document.createElement('form');
    wrap.className = 'form-stack';
    wrap.innerHTML = `
      <div class="form-grid">
        <div class="form-group">
          <label>Nama Lengkap *</label>
          <input name="nama" type="text" value="${esc(siswa?.nama || '')}" required />
        </div>
        <div class="form-group">
          <label>NIS *</label>
          <input name="nis" type="text" value="${esc(siswa?.nis || '')}" required />
        </div>
        <div class="form-group">
          <label>NISN</label>
          <input name="nisn" type="text" value="${esc(siswa?.nisn || '')}" />
        </div>
        <div class="form-group">
          <label>Kelas</label>
          <select name="kelas_id">
            <option value="">-- Belum Ada Kelas --</option>
            ${kelasList.map((k) => `<option value="${esc(k.id)}" ${siswa?.kelas_id === k.id ? 'selected' : ''}>${esc(k.nama_kelas)}</option>`).join('')}
          </select>
        </div>
        <div class="form-group">
          <label>Jenis Kelamin</label>
          <select name="jenis_kelamin">
            <option value="L" ${siswa?.jenis_kelamin !== 'P' ? 'selected' : ''}>Laki-laki (L)</option>
            <option value="P" ${siswa?.jenis_kelamin === 'P' ? 'selected' : ''}>Perempuan (P)</option>
          </select>
        </div>
        <div class="form-group">
          <label>Status</label>
          <select name="status" ${!isEdit ? 'disabled' : ''}>
            ${['aktif', 'lulus', 'pindah', 'nonaktif'].map((st) => `<option value="${st}" ${(siswa?.status || 'aktif') === st ? 'selected' : ''}>${st}</option>`).join('')}
          </select>
        </div>
        <div class="form-group">
          <label>Tempat Lahir</label>
          <input name="tempat_lahir" type="text" value="${esc(siswa?.tempat_lahir || '')}" />
        </div>
        <div class="form-group">
          <label>Tanggal Lahir</label>
          <input name="tanggal_lahir" type="date" value="${esc(siswa?.tanggal_lahir ? String(siswa.tanggal_lahir).slice(0, 10) : '')}" />
        </div>
        <div class="form-group">
          <label>Agama</label>
          <input name="agama" type="text" value="${esc(siswa?.agama || '')}" />
        </div>
        <div class="form-group">
          <label>No. HP</label>
          <input name="no_hp" type="text" value="${esc(siswa?.no_hp || '')}" />
        </div>
        <div class="form-group">
          <label>Email</label>
          <input name="email" type="email" value="${esc(siswa?.email || '')}" />
        </div>
        <div class="form-group">
          <label>Tahun Ajaran</label>
          <input name="tahun_ajaran" type="text" placeholder="2026/2027" value="${esc(siswa?.tahun_ajaran || '')}" />
        </div>
        ${!isEdit ? `
          <div class="form-group">
            <label>Username Login</label>
            <input name="username" type="text" placeholder="Default: sama dengan NIS" />
          </div>
          <div class="form-group">
            <label>Password Login *</label>
            <input name="password" type="password" placeholder="Min. 6 karakter (default: NIS)" />
          </div>
        ` : `
          <div class="form-group full">
            <label>Reset Password Baru (opsional)</label>
            <input name="password" type="password" placeholder="Kosongkan jika tidak mengubah password" />
          </div>
        `}
        <div class="form-group full">
          <label>Alamat</label>
          <textarea name="alamat">${esc(siswa?.alamat || '')}</textarea>
        </div>
      </div>
      <div class="modal-footer">
        <button type="button" class="btn btn-outline" id="f-cancel">Batal</button>
        <button type="submit" class="btn btn-primary">${isEdit ? 'Simpan Perubahan' : 'Simpan Siswa'}</button>
      </div>
    `;

    wrap.querySelector('#f-cancel').onclick = closeModal;
    wrap.onsubmit = async (e) => {
      e.preventDefault();
      const fd = new FormData(wrap);
      const body = Object.fromEntries(fd.entries());
      if (!isEdit && !body.password) body.password = body.nis;
      if (isEdit && !body.password) delete body.password;
      try {
        if (isEdit) {
          await apiFetch(`/admin/siswa/${siswa.id}`, { method: 'PUT', body });
          toast('Data siswa diperbarui', 'success');
        } else {
          await apiFetch('/admin/siswa', { method: 'POST', body });
          toast('Siswa berhasil ditambahkan', 'success');
        }
        closeModal();
        onSaved();
      } catch (err) {
        toast(err.message, 'error');
      }
    };

    openModal(isEdit ? `Ubah Siswa: ${siswa.nama}` : 'Tambah Siswa Baru', wrap);
  }

  function openSiswaImport(kelasList, onSaved) {
    const kelasByName = new Map(kelasList.map((k) => [String(k.nama_kelas).trim().toLowerCase(), k]));
    const headers = ['nama', 'nis', 'nisn', 'kelas', 'jenis_kelamin', 'tempat_lahir', 'tanggal_lahir', 'agama', 'no_hp', 'email', 'alamat', 'tahun_ajaran', 'username', 'password'];

    openImportWizard({
      title: 'Upload Massal Data Siswa (CSV / Excel)',
      description: 'Kolom wajib: nama dan nis. Kolom kelas dicocokkan otomatis dengan nama kelas.',
      templateFilename: 'template-upload-siswa.csv',
      templateHeaders: headers,
      sampleRows: [
        {
          nama: 'Ahmad Fauzi',
          nis: '2026001',
          nisn: '0123456789',
          kelas: kelasList[0]?.nama_kelas || '1A',
          jenis_kelamin: 'L',
          tempat_lahir: 'Jakarta',
          tanggal_lahir: '2015-04-12',
          agama: 'Islam',
          no_hp: '08123456789',
          email: 'ahmad@contoh.sch.id',
          alamat: 'Jl. Pendidikan No. 1',
          tahun_ajaran: '2026/2027',
          username: '2026001',
          password: 'siswa123',
        },
      ],
      aliasMap: {
        nama_siswa: 'nama',
        nama_lengkap: 'nama',
        nama_kelas: 'kelas',
        jk: 'jenis_kelamin',
        gender: 'jenis_kelamin',
        tgl_lahir: 'tanggal_lahir',
        hp: 'no_hp',
        telepon: 'no_hp',
      },
      extraControlsHtml: `
        <div class="form-group">
          <label>Kelas Default (jika kolom kelas kosong)</label>
          <select id="imp-default-kelas">
            <option value="">-- Tanpa Kelas Default --</option>
            ${kelasList.map((k) => `<option value="${esc(k.id)}">${esc(k.nama_kelas)}</option>`).join('')}
          </select>
        </div>
        <div class="form-group">
          <label>Password Default (jika kolom password kosong & NIS &lt; 6 digit)</label>
          <input id="imp-default-pw" type="text" value="siswa123" placeholder="Min. 6 karakter" />
        </div>
      `,
      validateAndNormalize: (items, wrap) => {
        const defKelasId = wrap.querySelector('#imp-default-kelas').value;
        const defPw = wrap.querySelector('#imp-default-pw').value.trim();

        return items.map((r) => {
          const nama = (r.nama || '').trim();
          const nis = (r.nis || '').trim();
          let err = '';
          let kelasId = defKelasId || null;

          if (!nama) err = 'Nama wajib diisi';
          else if (!nis) err = 'NIS wajib diisi';

          if (!err && r.kelas) {
            const matched = kelasByName.get(String(r.kelas).trim().toLowerCase());
            if (!matched) err = `Kelas "${r.kelas}" tidak ada`;
            else kelasId = matched.id;
          }

          const rawPass = (r.password || defPw || nis).trim();
          if (!err && rawPass.length < 6) err = 'Password < 6 karakter';

          const jk = String(r.jenis_kelamin || '').trim().toUpperCase().startsWith('P') ? 'P' : 'L';
          return {
            _error: err,
            preview: {
              nama,
              nis,
              nisn: r.nisn || '',
              kelas: r.kelas || (kelasList.find((k) => k.id === kelasId)?.nama_kelas || '-'),
              jenis_kelamin: jk,
              tempat_lahir: r.tempat_lahir || '',
            },
            payload: {
              ...r,
              nama,
              nis,
              kelas_id: kelasId,
              jenis_kelamin: jk,
              username: (r.username || nis).trim(),
              password: rawPass,
            },
          };
        });
      },
      submitRows: (rows, wrap, onProgress) => {
        const defKelasId = wrap.querySelector('#imp-default-kelas').value || null;
        const defPw = wrap.querySelector('#imp-default-pw').value.trim();
        return importWithFallback(
          '/admin/siswa/import',
          '/admin/siswa',
          { rows, default_kelas_id: defKelasId, default_password: defPw },
          rows,
          null,
          onProgress
        );
      },
      onComplete: onSaved,
    });
  }

  // ====================================================================
  // GURU + IMPORT CSV
  // ====================================================================
  async function renderGuru(root) {
    root.innerHTML = `
      <div class="card">
        <div class="toolbar">
          <div class="toolbar-filters">
            <input id="guru-search" type="text" placeholder="Cari nama / NIP / username..." style="min-width:220px;" />
          </div>
          <div class="toolbar-actions">
            <button id="btn-guru-export" class="btn btn-outline btn-sm">Export CSV</button>
            <button id="btn-guru-import" class="btn btn-soft">Upload CSV / Excel</button>
            <button id="btn-guru-add" class="btn btn-primary">+ Tambah Guru</button>
          </div>
        </div>
        <div class="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Nama Guru</th>
                <th>NIP</th>
                <th>JK</th>
                <th>Username</th>
                <th>Kontak</th>
                <th>Mapel</th>
                <th>Status</th>
                <th>Aksi</th>
              </tr>
            </thead>
            <tbody id="guru-tbody"><tr><td colspan="8" class="empty-state">Memuat data guru...</td></tr></tbody>
          </table>
        </div>
      </div>
    `;

    let rows = [];
    async function load() {
      const res = await apiFetch('/admin/guru');
      rows = res.data || [];
      draw();
    }

    function draw() {
      const q = root.querySelector('#guru-search').value.trim().toLowerCase();
      const filtered = q
        ? rows.filter((g) => [g.nama, g.nip, g.username, g.email].some((v) => String(v || '').toLowerCase().includes(q)))
        : rows;
      const tbody = root.querySelector('#guru-tbody');
      if (!filtered.length) {
        tbody.innerHTML = '<tr><td colspan="8" class="empty-state">Belum ada data guru.</td></tr>';
        return;
      }
      tbody.innerHTML = filtered.map((g) => `
        <tr>
          <td><strong>${esc(g.nama)}</strong></td>
          <td>${esc(g.nip || '-')}</td>
          <td>${esc(g.jenis_kelamin || '-')}</td>
          <td><code>${esc(g.username || '-')}</code></td>
          <td>${esc(g.no_hp || '-')}<div class="hint">${esc(g.email || '')}</div></td>
          <td><span class="badge badge-blue">${esc(g.jumlah_mapel ?? 0)} mapel</span></td>
          <td><span class="badge ${g.status === 'aktif' ? 'badge-green' : 'badge-gray'}">${esc(g.status)}</span></td>
          <td>
            <div class="row-actions">
              <button class="btn btn-outline btn-sm" data-edit="${esc(g.id)}">Ubah</button>
              <button class="btn btn-danger-soft btn-sm" data-del="${esc(g.id)}">Hapus</button>
            </div>
          </td>
        </tr>
      `).join('');

      tbody.querySelectorAll('[data-edit]').forEach((b) => {
        b.onclick = () => openGuruForm(rows.find((x) => x.id === b.dataset.edit), load);
      });
      tbody.querySelectorAll('[data-del]').forEach((b) => {
        b.onclick = async () => {
          const item = rows.find((x) => x.id === b.dataset.del);
          if (!item) return;
          if (!(await confirmDialog('Hapus Guru', `Hapus guru "${item.nama}" beserta akun loginnya?`))) return;
          try {
            await apiFetch(`/admin/guru/${item.id}`, { method: 'DELETE' });
            toast(`Guru ${item.nama} dihapus`, 'success');
            load();
          } catch (err) {
            toast(err.message, 'error');
          }
        };
      });
    }

    root.querySelector('#guru-search').oninput = draw;
    root.querySelector('#btn-guru-add').onclick = () => openGuruForm(null, load);
    root.querySelector('#btn-guru-export').onclick = () => {
      if (!rows.length) return toast('Tidak ada data', 'error');
      downloadCsv('data-guru.csv', ['nama', 'nip', 'jenis_kelamin', 'username', 'no_hp', 'email', 'alamat', 'status'], rows);
    };
    root.querySelector('#btn-guru-import').onclick = () => {
      openImportWizard({
        title: 'Upload Massal Data Guru (CSV / Excel)',
        description: 'Kolom wajib: nama serta salah satu username/nip/email.',
        templateFilename: 'template-upload-guru.csv',
        templateHeaders: ['nama', 'nip', 'username', 'password', 'jenis_kelamin', 'no_hp', 'email', 'alamat'],
        sampleRows: [{
          nama: 'Siti Aminah, S.Pd',
          nip: '198704122010012001',
          username: 'guru.siti',
          password: 'guru123',
          jenis_kelamin: 'P',
          no_hp: '08129876543',
          email: 'siti@contoh.sch.id',
          alamat: 'Jl. Merdeka No. 5',
        }],
        aliasMap: { nama_guru: 'nama', jk: 'jenis_kelamin', hp: 'no_hp' },
        extraControlsHtml: `
          <div class="form-group full">
            <label>Password Default (jika kolom password kosong)</label>
            <input id="imp-guru-pw" type="text" value="guru123" placeholder="Min. 6 karakter" />
          </div>
        `,
        validateAndNormalize: (items, wrap) => {
          const defPw = wrap.querySelector('#imp-guru-pw').value.trim();
          return items.map((r) => {
            const nama = (r.nama || '').trim();
            const username = (r.username || r.nip || r.email || '').trim();
            const password = (r.password || defPw || '').trim();
            let err = '';
            if (!nama) err = 'Nama wajib diisi';
            else if (!username) err = 'Username/NIP wajib diisi';
            else if (password.length < 6) err = 'Password < 6 karakter';
            return {
              _error: err,
              preview: { nama, nip: r.nip || '', username, password: '***', jenis_kelamin: r.jenis_kelamin || 'L', no_hp: r.no_hp || '' },
              payload: { ...r, nama, username, password },
            };
          });
        },
        submitRows: (items, wrap, onProgress) => importWithFallback(
          '/admin/guru/import',
          '/admin/guru',
          { rows: items, default_password: wrap.querySelector('#imp-guru-pw').value.trim() },
          items,
          null,
          onProgress
        ),
        onComplete: load,
      });
    };

    await load();
  }

  function openGuruForm(guru, onSaved) {
    const isEdit = Boolean(guru);
    const wrap = document.createElement('form');
    wrap.className = 'form-stack';
    wrap.innerHTML = `
      <div class="form-grid">
        <div class="form-group"><label>Nama Guru *</label><input name="nama" type="text" value="${esc(guru?.nama || '')}" required /></div>
        <div class="form-group"><label>NIP</label><input name="nip" type="text" value="${esc(guru?.nip || '')}" /></div>
        <div class="form-group">
          <label>Jenis Kelamin</label>
          <select name="jenis_kelamin">
            <option value="L" ${guru?.jenis_kelamin !== 'P' ? 'selected' : ''}>Laki-laki (L)</option>
            <option value="P" ${guru?.jenis_kelamin === 'P' ? 'selected' : ''}>Perempuan (P)</option>
          </select>
        </div>
        <div class="form-group">
          <label>Status</label>
          <select name="status" ${!isEdit ? 'disabled' : ''}>
            <option value="aktif" ${(guru?.status || 'aktif') === 'aktif' ? 'selected' : ''}>aktif</option>
            <option value="nonaktif" ${guru?.status === 'nonaktif' ? 'selected' : ''}>nonaktif</option>
          </select>
        </div>
        <div class="form-group"><label>No. HP</label><input name="no_hp" type="text" value="${esc(guru?.no_hp || '')}" /></div>
        <div class="form-group"><label>Email</label><input name="email" type="email" value="${esc(guru?.email || '')}" /></div>
        ${!isEdit ? `
          <div class="form-group"><label>Username Login *</label><input name="username" type="text" placeholder="Default: NIP / Email" /></div>
          <div class="form-group"><label>Password Login *</label><input name="password" type="password" placeholder="Min. 6 karakter" required /></div>
        ` : `
          <div class="form-group full"><label>Reset Password Baru (opsional)</label><input name="password" type="password" placeholder="Kosongkan jika tetap" /></div>
        `}
        <div class="form-group full"><label>Alamat</label><textarea name="alamat">${esc(guru?.alamat || '')}</textarea></div>
      </div>
      <div class="modal-footer">
        <button type="button" class="btn btn-outline" id="g-cancel">Batal</button>
        <button type="submit" class="btn btn-primary">${isEdit ? 'Simpan Perubahan' : 'Simpan Guru'}</button>
      </div>
    `;
    wrap.querySelector('#g-cancel').onclick = closeModal;
    wrap.onsubmit = async (e) => {
      e.preventDefault();
      const body = Object.fromEntries(new FormData(wrap).entries());
      if (isEdit && !body.password) delete body.password;
      try {
        if (isEdit) await apiFetch(`/admin/guru/${guru.id}`, { method: 'PUT', body });
        else await apiFetch('/admin/guru', { method: 'POST', body });
        toast(isEdit ? 'Data guru diperbarui' : 'Guru ditambahkan', 'success');
        closeModal();
        onSaved();
      } catch (err) {
        toast(err.message, 'error');
      }
    };
    openModal(isEdit ? `Ubah Guru: ${guru.nama}` : 'Tambah Guru Baru', wrap);
  }

  // ====================================================================
  // KELAS
  // ====================================================================
  async function renderKelas(root) {
    root.innerHTML = `
      <div class="card">
        <div class="toolbar">
          <div><h3 class="card-title">Daftar Kelas</h3></div>
          <button id="btn-kelas-add" class="btn btn-primary">+ Tambah Kelas</button>
        </div>
        <div class="table-wrap">
          <table>
            <thead>
              <tr><th>Nama Kelas</th><th>Tingkat</th><th>Wali Kelas</th><th>Jumlah Siswa</th><th>Kapasitas</th><th>Ruangan</th><th>Tahun Ajaran</th><th>Aksi</th></tr>
            </thead>
            <tbody id="kelas-tbody"><tr><td colspan="8" class="empty-state">Memuat data kelas...</td></tr></tbody>
          </table>
        </div>
      </div>
    `;

    const [kelasRes, guruRes] = await Promise.all([apiFetch('/admin/kelas'), apiFetch('/admin/guru')]);
    let rows = kelasRes.data || [];
    const guruList = guruRes.data || [];

    async function load() {
      rows = (await apiFetch('/admin/kelas')).data || [];
      draw();
    }

    function draw() {
      const tbody = root.querySelector('#kelas-tbody');
      if (!rows.length) {
        tbody.innerHTML = '<tr><td colspan="8" class="empty-state">Belum ada kelas.</td></tr>';
        return;
      }
      tbody.innerHTML = rows.map((k) => `
        <tr>
          <td><strong>${esc(k.nama_kelas)}</strong></td>
          <td>${esc(k.tingkat)}</td>
          <td>${esc(k.wali_kelas || '-')}</td>
          <td><span class="badge badge-blue">${esc(k.jumlah_siswa ?? 0)}</span></td>
          <td>${esc(k.kapasitas ?? 28)}</td>
          <td>${esc(k.ruangan || '-')}</td>
          <td>${esc(k.tahun_ajaran || '-')}</td>
          <td>
            <div class="row-actions">
              <button class="btn btn-outline btn-sm" data-edit="${esc(k.id)}">Ubah</button>
              <button class="btn btn-danger-soft btn-sm" data-del="${esc(k.id)}">Hapus</button>
            </div>
          </td>
        </tr>
      `).join('');

      tbody.querySelectorAll('[data-edit]').forEach((b) => {
        b.onclick = () => openKelasForm(rows.find((x) => x.id === b.dataset.edit), guruList, load);
      });
      tbody.querySelectorAll('[data-del]').forEach((b) => {
        b.onclick = async () => {
          const item = rows.find((x) => x.id === b.dataset.del);
          if (!item || !(await confirmDialog('Hapus Kelas', `Hapus kelas "${item.nama_kelas}"?`))) return;
          try {
            await apiFetch(`/admin/kelas/${item.id}`, { method: 'DELETE' });
            toast('Kelas dihapus', 'success');
            load();
          } catch (err) {
            toast(err.message, 'error');
          }
        };
      });
    }

    root.querySelector('#btn-kelas-add').onclick = () => openKelasForm(null, guruList, load);
    draw();
  }

  function openKelasForm(kelas, guruList, onSaved) {
    const isEdit = Boolean(kelas);
    const wrap = document.createElement('form');
    wrap.className = 'form-stack';
    wrap.innerHTML = `
      <div class="form-grid">
        <div class="form-group"><label>Nama Kelas *</label><input name="nama_kelas" type="text" value="${esc(kelas?.nama_kelas || '')}" placeholder="Contoh: 1A / VII A" required /></div>
        <div class="form-group"><label>Tingkat *</label><input name="tingkat" type="number" min="1" max="12" value="${esc(kelas?.tingkat ?? 1)}" required /></div>
        <div class="form-group"><label>Kapasitas</label><input name="kapasitas" type="number" min="1" value="${esc(kelas?.kapasitas ?? 28)}" /></div>
        <div class="form-group"><label>Ruangan</label><input name="ruangan" type="text" value="${esc(kelas?.ruangan || '')}" /></div>
        <div class="form-group"><label>Tahun Ajaran</label><input name="tahun_ajaran" type="text" placeholder="2026/2027" value="${esc(kelas?.tahun_ajaran || '')}" /></div>
        <div class="form-group">
          <label>Wali Kelas</label>
          <select name="wali_kelas_id">
            <option value="">-- Pilih Wali Kelas --</option>
            ${guruList.map((g) => `<option value="${esc(g.id)}" ${kelas?.wali_kelas_id === g.id ? 'selected' : ''}>${esc(g.nama)}</option>`).join('')}
          </select>
        </div>
      </div>
      <div class="modal-footer">
        <button type="button" class="btn btn-outline" id="k-cancel">Batal</button>
        <button type="submit" class="btn btn-primary">${isEdit ? 'Simpan Perubahan' : 'Buat Kelas'}</button>
      </div>
    `;
    wrap.querySelector('#k-cancel').onclick = closeModal;
    wrap.onsubmit = async (e) => {
      e.preventDefault();
      const body = Object.fromEntries(new FormData(wrap).entries());
      try {
        if (isEdit) await apiFetch(`/admin/kelas/${kelas.id}`, { method: 'PUT', body });
        else await apiFetch('/admin/kelas', { method: 'POST', body });
        toast(isEdit ? 'Kelas diperbarui' : 'Kelas ditambahkan', 'success');
        closeModal();
        onSaved();
      } catch (err) {
        toast(err.message, 'error');
      }
    };
    openModal(isEdit ? `Ubah Kelas: ${kelas.nama_kelas}` : 'Tambah Kelas Baru', wrap);
  }

  // ====================================================================
  // MAPEL & MAPPING GURU-MAPEL
  // ====================================================================
  async function renderMapel(root) {
    root.innerHTML = `
      <div class="tabs">
        <button class="tab-btn active" data-tab="mapel">Daftar Mata Pelajaran</button>
        <button class="tab-btn" data-tab="mapping">Mapping Guru - Mapel</button>
      </div>
      <div id="mapel-tab-body"></div>
    `;

    let activeTab = 'mapel';
    root.querySelectorAll('.tab-btn').forEach((btn) => {
      btn.onclick = () => {
        root.querySelectorAll('.tab-btn').forEach((b) => b.classList.remove('active'));
        btn.classList.add('active');
        activeTab = btn.dataset.tab;
        renderTab();
      };
    });

    async function renderTab() {
      const box = root.querySelector('#mapel-tab-body');
      if (activeTab === 'mapel') {
        const mapels = (await apiFetch('/admin/mapel')).data || [];
        box.innerHTML = `
          <div class="card">
            <div class="toolbar">
              <h3 class="card-title">Daftar Mata Pelajaran (${mapels.length})</h3>
              <div class="toolbar-actions">
                <button id="btn-mapel-import" class="btn btn-soft">Upload CSV</button>
                <button id="btn-mapel-add" class="btn btn-primary">+ Tambah Mapel</button>
              </div>
            </div>
            <div class="table-wrap">
              <table>
                <thead><tr><th>Kode</th><th>Nama Mata Pelajaran</th><th>Tingkat</th><th>Jam/Pekan</th><th>Aksi</th></tr></thead>
                <tbody>
                  ${mapels.length ? mapels.map((m) => `
                    <tr>
                      <td><code>${esc(m.kode_mapel)}</code></td>
                      <td><strong>${esc(m.nama_mapel)}</strong></td>
                      <td>${esc(m.tingkat ?? 'Semua')}</td>
                      <td>${esc(m.jam_per_pekan ?? 2)} jam</td>
                      <td>
                        <div class="row-actions">
                          <button class="btn btn-outline btn-sm" data-edit="${esc(m.id)}">Ubah</button>
                          <button class="btn btn-danger-soft btn-sm" data-del="${esc(m.id)}">Hapus</button>
                        </div>
                      </td>
                    </tr>
                  `).join('') : '<tr><td colspan="5" class="empty-state">Belum ada mata pelajaran.</td></tr>'}
                </tbody>
              </table>
            </div>
          </div>
        `;
        box.querySelector('#btn-mapel-add').onclick = () => openMapelForm(null, renderTab);
        box.querySelector('#btn-mapel-import').onclick = () => {
          openImportWizard({
            title: 'Upload Massal Mata Pelajaran (CSV)',
            description: 'Kolom wajib: nama_mapel dan kode_mapel.',
            templateFilename: 'template-mapel.csv',
            templateHeaders: ['kode_mapel', 'nama_mapel', 'tingkat', 'jam_per_pekan'],
            sampleRows: [{ kode_mapel: 'MTK', nama_mapel: 'Matematika', tingkat: '', jam_per_pekan: '4' }],
            aliasMap: { kode: 'kode_mapel', nama: 'nama_mapel', jam: 'jam_per_pekan' },
            validateAndNormalize: (items) => items.map((r) => {
              const kode_mapel = (r.kode_mapel || '').trim().toUpperCase();
              const nama_mapel = (r.nama_mapel || '').trim();
              let err = '';
              if (!kode_mapel) err = 'Kode mapel wajib';
              else if (!nama_mapel) err = 'Nama mapel wajib';
              return {
                _error: err,
                preview: { kode_mapel, nama_mapel, tingkat: r.tingkat || 'Semua', jam_per_pekan: r.jam_per_pekan || '2' },
                payload: { kode_mapel, nama_mapel, tingkat: r.tingkat || null, jam_per_pekan: r.jam_per_pekan || 2 },
              };
            }),
            submitRows: (rows, _w, onProgress) => importWithFallback('/admin/mapel/import', '/admin/mapel', { rows }, rows, null, onProgress),
            onComplete: renderTab,
          });
        };
        box.querySelectorAll('[data-edit]').forEach((b) => {
          b.onclick = () => openMapelForm(mapels.find((x) => x.id === b.dataset.edit), renderTab);
        });
        box.querySelectorAll('[data-del]').forEach((b) => {
          b.onclick = async () => {
            const m = mapels.find((x) => x.id === b.dataset.del);
            if (!m || !(await confirmDialog('Hapus Mapel', `Hapus mata pelajaran "${m.nama_mapel}"?`))) return;
            await apiFetch(`/admin/mapel/${m.id}`, { method: 'DELETE' });
            toast('Mapel dihapus', 'success');
            renderTab();
          };
        });
      } else {
        const [mapRes, guruRes, mapelRes] = await Promise.all([
          apiFetch('/admin/guru-mapel'),
          apiFetch('/admin/guru'),
          apiFetch('/admin/mapel'),
        ]);
        const mappings = mapRes.data || [];
        const gurus = guruRes.data || [];
        const mapels = mapelRes.data || [];
        box.innerHTML = `
          <div class="card">
            <div class="card-header"><h3 class="card-title">Tambah Pengampu Guru - Mapel</h3></div>
            <form id="gm-form" class="toolbar" style="margin-bottom:0;">
              <div class="toolbar-filters">
                <select name="guru_id" required>
                  <option value="">-- Pilih Guru --</option>
                  ${gurus.map((g) => `<option value="${esc(g.id)}">${esc(g.nama)}</option>`).join('')}
                </select>
                <select name="mapel_id" required>
                  <option value="">-- Pilih Mata Pelajaran --</option>
                  ${mapels.map((m) => `<option value="${esc(m.id)}">${esc(m.nama_mapel)} (${esc(m.kode_mapel)})</option>`).join('')}
                </select>
              </div>
              <button type="submit" class="btn btn-primary">+ Hubungkan</button>
            </form>
          </div>
          <div class="card">
            <div class="card-header"><h3 class="card-title">Daftar Pengampu (${mappings.length})</h3></div>
            <div class="table-wrap">
              <table>
                <thead><tr><th>Guru</th><th>NIP</th><th>Mata Pelajaran</th><th>Kode</th><th>Aksi</th></tr></thead>
                <tbody>
                  ${mappings.length ? mappings.map((gm) => `
                    <tr>
                      <td><strong>${esc(gm.guru_nama)}</strong></td>
                      <td>${esc(gm.nip || '-')}</td>
                      <td>${esc(gm.nama_mapel)}</td>
                      <td><code>${esc(gm.kode_mapel)}</code></td>
                      <td><button class="btn btn-danger-soft btn-sm" data-del-gm="${esc(gm.id)}">Hapus</button></td>
                    </tr>
                  `).join('') : '<tr><td colspan="5" class="empty-state">Belum ada mapping guru-mapel.</td></tr>'}
                </tbody>
              </table>
            </div>
          </div>
        `;
        box.querySelector('#gm-form').onsubmit = async (e) => {
          e.preventDefault();
          const body = Object.fromEntries(new FormData(e.target).entries());
          try {
            const res = await apiFetch('/admin/guru-mapel', { method: 'POST', body });
            toast(res.message || 'Berhasil ditambahkan', 'success');
            renderTab();
          } catch (err) {
            toast(err.message, 'error');
          }
        };
        box.querySelectorAll('[data-del-gm]').forEach((b) => {
          b.onclick = async () => {
            await apiFetch(`/admin/guru-mapel/${b.dataset.delGm}`, { method: 'DELETE' });
            toast('Mapping dihapus', 'success');
            renderTab();
          };
        });
      }
    }

    await renderTab();
  }

  function openMapelForm(mapel, onSaved) {
    const isEdit = Boolean(mapel);
    const wrap = document.createElement('form');
    wrap.className = 'form-stack';
    wrap.innerHTML = `
      <div class="form-grid">
        <div class="form-group"><label>Kode Mapel *</label><input name="kode_mapel" type="text" value="${esc(mapel?.kode_mapel || '')}" required /></div>
        <div class="form-group"><label>Nama Mapel *</label><input name="nama_mapel" type="text" value="${esc(mapel?.nama_mapel || '')}" required /></div>
        <div class="form-group"><label>Tingkat (opsional)</label><input name="tingkat" type="number" min="1" max="12" value="${esc(mapel?.tingkat ?? '')}" placeholder="Kosong = semua tingkat" /></div>
        <div class="form-group"><label>Jam per Pekan</label><input name="jam_per_pekan" type="number" min="1" value="${esc(mapel?.jam_per_pekan ?? 2)}" /></div>
      </div>
      <div class="modal-footer">
        <button type="button" class="btn btn-outline" id="m-cancel">Batal</button>
        <button type="submit" class="btn btn-primary">${isEdit ? 'Simpan Perubahan' : 'Simpan Mapel'}</button>
      </div>
    `;
    wrap.querySelector('#m-cancel').onclick = closeModal;
    wrap.onsubmit = async (e) => {
      e.preventDefault();
      const body = Object.fromEntries(new FormData(wrap).entries());
      if (body.tingkat === '') body.tingkat = null;
      try {
        if (isEdit) await apiFetch(`/admin/mapel/${mapel.id}`, { method: 'PUT', body });
        else await apiFetch('/admin/mapel', { method: 'POST', body });
        toast('Mata pelajaran disimpan', 'success');
        closeModal();
        onSaved();
      } catch (err) {
        toast(err.message, 'error');
      }
    };
    openModal(isEdit ? 'Ubah Mata Pelajaran' : 'Tambah Mata Pelajaran', wrap);
  }

  // ====================================================================
  // ORANG TUA
  // ====================================================================
  async function renderOrtu(root) {
    root.innerHTML = `
      <div class="card">
        <div class="toolbar">
          <div class="toolbar-filters">
            <input id="ortu-search" type="text" placeholder="Cari nama orang tua / username..." style="min-width:240px;" />
          </div>
          <div class="toolbar-actions">
            <button id="btn-ortu-import" class="btn btn-soft">Upload CSV Orang Tua</button>
            <button id="btn-ortu-add" class="btn btn-primary">+ Tambah Orang Tua</button>
          </div>
        </div>
        <div class="table-wrap">
          <table>
            <thead>
              <tr><th>Nama Ibu / Ayah / Wali</th><th>Username</th><th>HP Ibu / Ayah</th><th>Jumlah Anak</th><th>Aksi</th></tr>
            </thead>
            <tbody id="ortu-tbody"><tr><td colspan="5" class="empty-state">Memuat data orang tua...</td></tr></tbody>
          </table>
        </div>
      </div>
    `;

    const [ortuRes, siswaRes] = await Promise.all([apiFetch('/admin/orang-tua'), apiFetch('/admin/siswa')]);
    let rows = ortuRes.data || [];
    const siswaList = siswaRes.data || [];

    async function load() {
      rows = (await apiFetch('/admin/orang-tua')).data || [];
      draw();
    }

    function draw() {
      const q = root.querySelector('#ortu-search').value.trim().toLowerCase();
      const filtered = q
        ? rows.filter((o) => [o.nama_ibu, o.nama_ayah, o.nama_wali, o.username].some((v) => String(v || '').toLowerCase().includes(q)))
        : rows;
      const tbody = root.querySelector('#ortu-tbody');
      if (!filtered.length) {
        tbody.innerHTML = '<tr><td colspan="5" class="empty-state">Belum ada data orang tua.</td></tr>';
        return;
      }
      tbody.innerHTML = filtered.map((o) => `
        <tr>
          <td>
            <strong>${esc(o.nama_ibu || o.nama_ayah || o.nama_wali || '-')}</strong>
            <div class="hint">${esc([o.nama_ibu && `Ibu: ${o.nama_ibu}`, o.nama_ayah && `Ayah: ${o.nama_ayah}`].filter(Boolean).join(' · '))}</div>
          </td>
          <td><code>${esc(o.username || '-')}</code></td>
          <td>${esc(o.hp_ibu || o.hp_ayah || '-')}</td>
          <td><span class="badge badge-blue">${esc(o.jumlah_anak ?? 0)} anak</span></td>
          <td>
            <button class="btn btn-outline btn-sm" data-link="${esc(o.id)}">Tautkan Anak</button>
          </td>
        </tr>
      `).join('');

      tbody.querySelectorAll('[data-link]').forEach((b) => {
        b.onclick = () => openOrtuLinkModal(rows.find((x) => x.id === b.dataset.link), siswaList, load);
      });
    }

    root.querySelector('#ortu-search').oninput = draw;
    root.querySelector('#btn-ortu-add').onclick = () => openOrtuForm(siswaList, load);
    root.querySelector('#btn-ortu-import').onclick = () => {
      const siswaByNis = new Map(siswaList.map((s) => [String(s.nis || '').trim(), s]));
      openImportWizard({
        title: 'Upload Massal Orang Tua (CSV)',
        description: 'Kolom anak_nis boleh berisi satu atau beberapa NIS dipisah titik koma/spasi untuk menautkan anak otomatis.',
        templateFilename: 'template-orang-tua.csv',
        templateHeaders: ['nama_ibu', 'hp_ibu', 'nama_ayah', 'hp_ayah', 'username', 'password', 'email', 'alamat', 'anak_nis'],
        sampleRows: [{
          nama_ibu: 'Siti Aminah',
          hp_ibu: '081234567890',
          nama_ayah: 'Budi Santoso',
          hp_ayah: '081298765432',
          username: 'ortu.budi',
          password: 'ortu123',
          email: '',
          alamat: 'Jl. Melati No. 3',
          anak_nis: siswaList[0]?.nis || '2026001',
        }],
        aliasMap: { nis_anak: 'anak_nis', nama_orang_tua: 'nama_ibu' },
        validateAndNormalize: (items) => items.map((r) => {
          const hasName = Boolean((r.nama_ibu || r.nama_ayah || r.nama_wali || '').trim());
          const username = (r.username || '').trim();
          const password = (r.password || '').trim();
          const nisTokens = String(r.anak_nis || '').split(/[;,|\s]+/).filter(Boolean);
          const siswaIds = nisTokens.map((nis) => siswaByNis.get(nis)?.id).filter(Boolean);
          let err = '';
          if (!hasName) err = 'Minimal nama ibu/ayah/wali wajib';
          else if (!username) err = 'Username wajib';
          else if (password.length < 6) err = 'Password < 6 karakter';
          return {
            _error: err,
            preview: {
              nama_ibu: r.nama_ibu || r.nama_ayah || r.nama_wali,
              hp_ibu: r.hp_ibu || r.hp_ayah || '',
              nama_ayah: r.nama_ayah || '',
              username,
              anak_nis: nisTokens.join(', ') || '-',
            },
            payload: { ...r, username, password, siswa_ids: siswaIds },
          };
        }),
        submitRows: async (items, _w, onProgress) => {
          const results = [];
          let berhasil = 0;
          let gagal = 0;
          for (let i = 0; i < items.length; i += 1) {
            try {
              await apiFetch('/admin/orang-tua', { method: 'POST', body: items[i] });
              berhasil += 1;
              results.push({ row: i + 1, status: 'ok', message: 'Berhasil ditambahkan' });
            } catch (e) {
              gagal += 1;
              results.push({ row: i + 1, status: 'error', message: e.message });
            }
            if (onProgress) onProgress(i + 1, items.length);
          }
          return { total: items.length, berhasil, gagal, results };
        },
        onComplete: load,
      });
    };

    draw();
  }

  function openOrtuForm(siswaList, onSaved) {
    const wrap = document.createElement('form');
    wrap.className = 'form-stack';
    wrap.innerHTML = `
      <div class="form-grid">
        <div class="form-group"><label>Nama Ibu</label><input name="nama_ibu" type="text" /></div>
        <div class="form-group"><label>HP Ibu</label><input name="hp_ibu" type="text" /></div>
        <div class="form-group"><label>Nama Ayah</label><input name="nama_ayah" type="text" /></div>
        <div class="form-group"><label>HP Ayah</label><input name="hp_ayah" type="text" /></div>
        <div class="form-group"><label>Nama Wali</label><input name="nama_wali" type="text" /></div>
        <div class="form-group"><label>Email</label><input name="email" type="email" /></div>
        <div class="form-group"><label>Username Login *</label><input name="username" type="text" required /></div>
        <div class="form-group"><label>Password Login *</label><input name="password" type="password" placeholder="Min. 6 karakter" required /></div>
        <div class="form-group full">
          <label>Tautkan ke Siswa (tahan Ctrl/Cmd untuk pilih lebih dari satu)</label>
          <select name="siswa_ids" multiple size="4">
            ${siswaList.map((s) => `<option value="${esc(s.id)}">${esc(s.nama)} (${esc(s.nis || '-')}) - ${esc(s.nama_kelas || 'Tanpa kelas')}</option>`).join('')}
          </select>
        </div>
        <div class="form-group full"><label>Alamat</label><textarea name="alamat"></textarea></div>
      </div>
      <div class="modal-footer">
        <button type="button" class="btn btn-outline" id="o-cancel">Batal</button>
        <button type="submit" class="btn btn-primary">Simpan Akun Orang Tua</button>
      </div>
    `;
    wrap.querySelector('#o-cancel').onclick = closeModal;
    wrap.onsubmit = async (e) => {
      e.preventDefault();
      const fd = new FormData(wrap);
      const body = Object.fromEntries(fd.entries());
      body.siswa_ids = Array.from(wrap.querySelector('[name="siswa_ids"]').selectedOptions).map((o) => o.value);
      try {
        await apiFetch('/admin/orang-tua', { method: 'POST', body });
        toast('Akun orang tua dibuat', 'success');
        closeModal();
        onSaved();
      } catch (err) {
        toast(err.message, 'error');
      }
    };
    openModal('Tambah Akun Orang Tua', wrap);
  }

  function openOrtuLinkModal(ortu, siswaList, onSaved) {
    const wrap = document.createElement('form');
    wrap.className = 'form-stack';
    wrap.innerHTML = `
      <p style="margin:0;">Tautkan siswa ke akun <strong>${esc(ortu.nama_ibu || ortu.nama_ayah || ortu.username)}</strong>:</p>
      <div class="form-group">
        <label>Pilih Siswa</label>
        <select name="siswa_id" required>
          <option value="">-- Pilih Siswa --</option>
          ${siswaList.map((s) => `<option value="${esc(s.id)}">${esc(s.nama)} (${esc(s.nis || '-')}) - ${esc(s.nama_kelas || '-')}</option>`).join('')}
        </select>
      </div>
      <div class="modal-footer">
        <button type="button" class="btn btn-outline" id="ol-cancel">Tutup</button>
        <button type="submit" class="btn btn-primary">Tautkan Anak</button>
      </div>
    `;
    wrap.querySelector('#ol-cancel').onclick = closeModal;
    wrap.onsubmit = async (e) => {
      e.preventDefault();
      const siswaId = wrap.querySelector('[name="siswa_id"]').value;
      try {
        const res = await apiFetch(`/admin/orang-tua/${ortu.id}/anak`, { method: 'POST', body: { siswa_id: siswaId } });
        toast(res.message || 'Berhasil ditautkan', 'success');
        closeModal();
        onSaved();
      } catch (err) {
        toast(err.message, 'error');
      }
    };
    openModal('Tautkan Siswa ke Orang Tua', wrap);
  }

  STA.viewsData = {
    renderDashboard,
    renderSiswa,
    renderGuru,
    renderKelas,
    renderMapel,
    renderOrtu,
  };
})(window.STA);
