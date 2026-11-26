'use strict';

window.STA = window.STA || {};

(function (STA) {
  const DEFAULT_API_FALLBACK = 'http://10.0.0.39:5001/api';
  const STORAGE_API = 'sta_admin_api_url';
  const STORAGE_TOKEN = 'sta_admin_token';
  const STORAGE_USER = 'sta_admin_user';

  function getDefaultApiUrl() {
    const loc = window.location;
    if (loc.protocol.startsWith('http') && loc.hostname && !['localhost', '127.0.0.1'].includes(loc.hostname)) {
      return `${loc.protocol}//${loc.hostname}:5001/api`;
    }
    return DEFAULT_API_FALLBACK;
  }

  function getApiUrl() {
    const saved = localStorage.getItem(STORAGE_API);
    if (saved && saved.trim()) return saved.trim().replace(/\/+$/, '');
    return getDefaultApiUrl();
  }

  function setApiUrl(url) {
    const clean = String(url || '').trim().replace(/\/+$/, '');
    if (clean) localStorage.setItem(STORAGE_API, clean);
    else localStorage.removeItem(STORAGE_API);
  }

  function getToken() {
    return localStorage.getItem(STORAGE_TOKEN) || '';
  }

  function getUser() {
    try {
      const raw = localStorage.getItem(STORAGE_USER);
      return raw ? JSON.parse(raw) : null;
    } catch {
      return null;
    }
  }

  function setSession(token, user) {
    localStorage.setItem(STORAGE_TOKEN, token);
    localStorage.setItem(STORAGE_USER, JSON.stringify(user));
  }

  function clearSession() {
    localStorage.removeItem(STORAGE_TOKEN);
    localStorage.removeItem(STORAGE_USER);
  }

  async function apiFetch(path, options = {}) {
    const base = getApiUrl();
    const url = path.startsWith('http') ? path : `${base}${path.startsWith('/') ? '' : '/'}${path}`;
    const headers = new Headers(options.headers || {});
    const token = getToken();
    if (token) headers.set('Authorization', `Bearer ${token}`);

    let body = options.body;
    const isForm = typeof FormData !== 'undefined' && body instanceof FormData;
    if (body && typeof body === 'object' && !isForm) {
      headers.set('Content-Type', 'application/json');
      body = JSON.stringify(body);
    }

    const res = await fetch(url, {
      method: options.method || 'GET',
      headers,
      body,
    });

    let json = null;
    const text = await res.text();
    try {
      json = text ? JSON.parse(text) : null;
    } catch {
      json = null;
    }

    if (res.status === 401 && !options.skipAuthRedirect) {
      clearSession();
      if (typeof STA.onUnauthorized === 'function') STA.onUnauthorized();
    }

    if (!res.ok || (json && json.success === false)) {
      const err = new Error((json && json.message) || `HTTP ${res.status}`);
      err.status = res.status;
      err.payload = json;
      throw err;
    }

    return json || { success: true, data: null };
  }

  function esc(val) {
    return String(val ?? '')
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  function formatRp(num) {
    const n = Number(num || 0);
    return 'Rp ' + n.toLocaleString('id-ID');
  }

  function formatDate(str) {
    if (!str) return '-';
    return String(str).slice(0, 10);
  }

  function toast(message, type = 'info') {
    const root = document.getElementById('toast-root');
    if (!root) return;
    const el = document.createElement('div');
    el.className = `toast ${type}`;
    el.textContent = message;
    root.appendChild(el);
    setTimeout(() => el.remove(), 3800);
  }

  function openModal(title, htmlOrNode, { large = false } = {}) {
    const root = document.getElementById('modal-root');
    const box = document.getElementById('modal-box');
    const titleEl = document.getElementById('modal-title');
    const bodyEl = document.getElementById('modal-body');

    box.classList.toggle('modal-lg', Boolean(large));
    titleEl.textContent = title;
    if (typeof htmlOrNode === 'string') {
      bodyEl.innerHTML = htmlOrNode;
    } else {
      bodyEl.innerHTML = '';
      bodyEl.appendChild(htmlOrNode);
    }
    root.classList.remove('hidden');
    return bodyEl;
  }

  function closeModal() {
    const root = document.getElementById('modal-root');
    root.classList.add('hidden');
    document.getElementById('modal-body').innerHTML = '';
  }

  function confirmDialog(title, message, confirmLabel = 'Ya, Lanjutkan', danger = true) {
    return new Promise((resolve) => {
      const wrap = document.createElement('div');
      wrap.innerHTML = `
        <p style="margin:0 0 14px;">${esc(message)}</p>
        <div class="modal-footer">
          <button type="button" class="btn btn-outline" data-act="cancel">Batal</button>
          <button type="button" class="btn ${danger ? 'btn-danger' : 'btn-primary'}" data-act="ok">${esc(confirmLabel)}</button>
        </div>
      `;
      wrap.querySelector('[data-act="cancel"]').onclick = () => {
        closeModal();
        resolve(false);
      };
      wrap.querySelector('[data-act="ok"]').onclick = () => {
        closeModal();
        resolve(true);
      };
      openModal(title, wrap);
    });
  }

  STA.api = {
    getDefaultApiUrl,
    getApiUrl,
    setApiUrl,
    getToken,
    getUser,
    setSession,
    clearSession,
    apiFetch,
  };
  STA.ui = {
    esc,
    formatRp,
    formatDate,
    toast,
    openModal,
    closeModal,
    confirmDialog,
  };
})(window.STA);
