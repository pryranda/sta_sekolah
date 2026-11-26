'use strict';

window.STA = window.STA || {};

(function (STA) {
  const { getApiUrl, setApiUrl, getToken, getUser, setSession, clearSession, apiFetch } = STA.api;
  const { esc, toast, openModal, closeModal } = STA.ui;

  STA.state = {
    user: null,
    activeRoute: 'dashboard',
    pendingCount: 0,
  };

  const ADMIN_NAV = [
    { section: 'Utama' },
    { id: 'dashboard', title: 'Dashboard', subtitle: 'Ringkasan data & aksi cepat', render: () => STA.viewsData.renderDashboard },
    { section: 'Data Master' },
    { id: 'siswa', title: 'Data Siswa', subtitle: 'Kelola & upload massal data siswa', render: () => STA.viewsData.renderSiswa },
    { id: 'guru', title: 'Data Guru', subtitle: 'Kelola & upload massal data guru', render: () => STA.viewsData.renderGuru },
    { id: 'kelas', title: 'Data Kelas', subtitle: 'Daftar kelas & wali kelas', render: () => STA.viewsData.renderKelas },
    { id: 'mapel', title: 'Mapel & Pengampu', subtitle: 'Mata pelajaran dan mapping guru', render: () => STA.viewsData.renderMapel },
    { id: 'ortu', title: 'Orang Tua', subtitle: 'Akun orang tua & penautan anak', render: () => STA.viewsData.renderOrtu },
    { section: 'Akademik & Keuangan' },
    { id: 'jadwal', title: 'Jadwal & Libur', subtitle: 'Generator jadwal otomatis & hari libur', render: () => STA.viewsOps.renderJadwal },
    { id: 'pengumuman', title: 'Pengumuman', subtitle: 'Publikasi pengumuman sekolah', render: () => STA.viewsOps.renderPengumuman },
    { id: 'spp', title: 'Keuangan & SPP', subtitle: 'Verifikasi bukti bayar, tagihan & laporan', badgeKey: 'pending', render: () => STA.viewsOps.renderSpp },
    { section: 'Sistem' },
    { id: 'sekolah', title: 'Pengaturan Sekolah', subtitle: 'Identitas, logo, jam & lokasi GPS', render: () => STA.viewsOps.renderSekolahSettings },
  ];

  const SUPERADMIN_NAV = [
    { section: 'Admin Aplikasi' },
    { id: 'superadmin-sekolah', title: 'Daftar Sekolah', subtitle: 'Kelola multi-sekolah & akun admin', render: () => STA.viewsOps.renderSuperadminSekolah },
  ];

  function getNavList() {
    return STA.state.user?.role === 'superadmin' ? SUPERADMIN_NAV : ADMIN_NAV;
  }

  function buildSidebar() {
    const navEl = document.getElementById('sidebar-nav');
    const items = getNavList();
    navEl.innerHTML = items.map((item) => {
      if (item.section) return `<div class="nav-section">${esc(item.section)}</div>`;
      const active = item.id === STA.state.activeRoute ? 'active' : '';
      const badge = item.badgeKey === 'pending' && STA.state.pendingCount > 0
        ? `<span class="nav-pill" id="nav-pill-pending">${STA.state.pendingCount}</span>`
        : '';
      return `<button class="nav-item ${active}" data-route="${esc(item.id)}"><span>${esc(item.title)}</span>${badge}</button>`;
    }).join('');

    navEl.querySelectorAll('[data-route]').forEach((btn) => {
      btn.onclick = () => {
        closeMobileSidebar();
        STA.navigate(btn.dataset.route);
      };
    });
  }

  STA.updateSidebarBadges = function () {
    buildSidebar();
  };

  STA.loadSchoolHeader = async function () {
    const user = STA.state.user;
    if (!user || user.role === 'superadmin') return;
    try {
      const res = await apiFetch(`/sekolah/info?sekolah_id=${encodeURIComponent(user.sekolah_id || '')}`);
      const s = res.data;
      if (!s) return;
      document.getElementById('sidebar-school-name').textContent = s.nama || 'STA Sekolah';
      const logoImg = document.getElementById('sidebar-logo');
      const fallback = document.getElementById('sidebar-logo-fallback');
      if (s.logo_url) {
        logoImg.src = s.logo_url;
        logoImg.classList.remove('hidden');
        fallback.classList.add('hidden');
      } else {
        logoImg.classList.add('hidden');
        fallback.classList.remove('hidden');
      }
    } catch {
      // Abaikan jika gagal memuat info header sekolah
    }
  };

  STA.navigate = async function (routeId) {
    const items = getNavList().filter((x) => x.id);
    const target = items.find((x) => x.id === routeId) || items[0];
    if (!target) return;

    STA.state.activeRoute = target.id;
    buildSidebar();
    document.getElementById('page-title').textContent = target.title;
    document.getElementById('page-subtitle').textContent = target.subtitle;

    const main = document.getElementById('main-content');
    main.innerHTML = '<div class="empty-state">Memuat halaman...</div>';
    try {
      const renderer = target.render();
      await renderer(main);
    } catch (err) {
      main.innerHTML = `<div class="alert alert-error">Gagal memuat halaman: ${esc(err.message)}</div>`;
    }
  };

  function showLogin(msg = '') {
    document.getElementById('app-shell').classList.add('hidden');
    document.getElementById('login-view').classList.remove('hidden');
    document.getElementById('login-api-url').value = getApiUrl();
    const errEl = document.getElementById('login-error');
    if (msg) {
      errEl.textContent = msg;
      errEl.classList.remove('hidden');
    } else {
      errEl.classList.add('hidden');
    }
  }

  function showApp(user) {
    STA.state.user = user;
    document.getElementById('login-view').classList.add('hidden');
    document.getElementById('app-shell').classList.remove('hidden');

    document.getElementById('user-name').textContent = user.nama || user.username;
    document.getElementById('user-username').textContent = `@${user.username}`;
    document.getElementById('user-avatar').textContent = (user.nama || user.username || 'A')[0].toUpperCase();
    document.getElementById('sidebar-user-role').textContent = user.role === 'superadmin' ? 'Admin Aplikasi' : 'Admin Sekolah';
    document.getElementById('api-badge').textContent = `API: ${getApiUrl().replace(/^https?:\/\//, '')}`;

    if (user.role === 'superadmin') {
      document.getElementById('sidebar-school-name').textContent = 'Multi-Sekolah';
      STA.navigate('superadmin-sekolah');
    } else {
      STA.loadSchoolHeader();
      STA.navigate('dashboard');
    }
  }

  STA.onUnauthorized = () => {
    showLogin('Sesi berakhir. Silakan login kembali.');
  };

  function closeMobileSidebar() {
    document.getElementById('sidebar').classList.remove('open');
    document.getElementById('sidebar-backdrop').classList.add('hidden');
  }

  function bindGlobalEvents() {
    document.getElementById('modal-close').onclick = closeModal;
    document.getElementById('modal-root').onclick = (e) => {
      if (e.target.id === 'modal-root') closeModal();
    };
    document.getElementById('sidebar-open').onclick = () => {
      document.getElementById('sidebar').classList.add('open');
      document.getElementById('sidebar-backdrop').classList.remove('hidden');
    };
    document.getElementById('sidebar-close').onclick = closeMobileSidebar;
    document.getElementById('sidebar-backdrop').onclick = closeMobileSidebar;

    document.getElementById('btn-logout').onclick = () => {
      clearSession();
      showLogin();
    };

    document.getElementById('btn-change-pw').onclick = () => {
      const wrap = document.createElement('form');
      wrap.className = 'form-stack';
      wrap.innerHTML = `
        <div class="form-group"><label>Password Lama *</label><input name="currentPassword" type="password" required /></div>
        <div class="form-group"><label>Password Baru * (min. 6 karakter)</label><input name="newPassword" type="password" required minlength="6" /></div>
        <div class="modal-footer">
          <button type="button" class="btn btn-outline" id="cp-cancel">Batal</button>
          <button type="submit" class="btn btn-primary">Simpan Password</button>
        </div>
      `;
      wrap.querySelector('#cp-cancel').onclick = closeModal;
      wrap.onsubmit = async (e) => {
        e.preventDefault();
        try {
          await apiFetch('/auth/change-password', { method: 'PUT', body: Object.fromEntries(new FormData(wrap).entries()) });
          toast('Password berhasil diubah', 'success');
          closeModal();
        } catch (err) {
          toast(err.message, 'error');
        }
      };
      openModal('Ubah Password', wrap);
    };

    document.getElementById('login-form').onsubmit = async (e) => {
      e.preventDefault();
      const errEl = document.getElementById('login-error');
      errEl.classList.add('hidden');
      const btn = document.getElementById('login-submit');
      btn.disabled = true;

      const apiUrlInput = document.getElementById('login-api-url').value.trim();
      setApiUrl(apiUrlInput);

      try {
        const res = await apiFetch('/auth/login', {
          method: 'POST',
          skipAuthRedirect: true,
          body: {
            username: document.getElementById('login-username').value.trim(),
            password: document.getElementById('login-password').value,
          },
        });
        const { token, user } = res.data || {};
        if (!user || !['admin', 'superadmin'].includes(user.role)) {
          throw new Error('Panel ini hanya untuk akun Admin Sekolah atau Admin Aplikasi.');
        }
        setSession(token, user);
        showApp(user);
      } catch (err) {
        errEl.textContent = err.message || 'Gagal login';
        errEl.classList.remove('hidden');
      } finally {
        btn.disabled = false;
      }
    };
  }

  async function boot() {
    bindGlobalEvents();
    const token = getToken();
    const cachedUser = getUser();
    if (!token || !cachedUser) {
      showLogin();
      return;
    }
    try {
      const profile = await apiFetch('/auth/profile');
      const user = profile.data || cachedUser;
      if (!['admin', 'superadmin'].includes(user.role)) {
        clearSession();
        showLogin('Akun bukan admin.');
        return;
      }
      setSession(token, user);
      showApp(user);
    } catch {
      clearSession();
      showLogin();
    }
  }

  boot();
})(window.STA);
