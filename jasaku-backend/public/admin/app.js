const API_BASE = window.location.origin + '/api';
const CATEGORY_ICONS = ['wrench', 'bolt', 'paintbrush', 'droplets', 'snowflake', 'wind', 'trash', 'sparkles'];

function getToken() { return localStorage.getItem('admin_token'); }
function getUser() { try { return JSON.parse(localStorage.getItem('admin_user') || '{}'); } catch { return {}; } }
function requireAuth() { if (!getToken()) navigate('login'); }

function navigate(page) {
  window.location.hash = page;
  Alpine.store('nav').page = page;
}

let toastTimer = null;
function toast(msg, type = 'success') {
  const store = Alpine.store('toast');
  store.msg = msg;
  store.type = type;
  store.show = true;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => store.show = false, 3000);
}

async function apiFetch(path, options = {}) {
  const token = getToken();
  const headers = { ...options.headers };
  if (token) headers['Authorization'] = `Bearer ${token}`;
  if (!(options.body instanceof FormData)) {
    headers['Content-Type'] = 'application/json';
  }
  const res = await fetch(API_BASE + path, { ...options, headers });
  if (res.status === 401) {
    localStorage.removeItem('admin_token');
    localStorage.removeItem('admin_user');
    navigate('login');
    return null;
  }
  const text = await res.text();
  let json;
  try { json = JSON.parse(text); } catch {
    throw new Error('Gagal: server mengembalikan HTML (mungkin endpoint salah atau error 500) — ' + path);
  }
  if (!json.success) throw new Error(json.message || 'Request failed');
  return json.data;
}

function logout() {
  localStorage.removeItem('admin_token');
  localStorage.removeItem('admin_user');
  navigate('login');
}

function toggleDark() {
  const dark = !Alpine.store('theme').dark;
  Alpine.store('theme').dark = dark;
  localStorage.setItem('dark', dark);
  document.documentElement.classList.toggle('dark', dark);
}

function confirmModal(msg) {
  return new Promise((resolve) => {
    const store = Alpine.store('confirm');
    store.msg = msg;
    store.show = true;
    store.resolve = resolve;
  });
}

document.addEventListener('alpine:init', () => {
  Alpine.store('nav', { page: 'login' });
  Alpine.store('toast', { show: false, msg: '', type: 'success' });
  Alpine.store('confirm', { show: false, msg: '', resolve: null });
  Alpine.store('mobile', { show: false });
  Alpine.store('sidebar', { collapsed: false });
  Alpine.store('theme', {
    dark: localStorage.getItem('dark') === 'true' || (!localStorage.getItem('dark') && window.matchMedia('(prefers-color-scheme: dark)').matches)
  });

  Alpine.data('adminApp', () => ({
    init() {
      if (Alpine.store('theme').dark) document.documentElement.classList.add('dark');
      if (!getToken()) {
        Alpine.store('nav').page = 'login';
        return;
      }
      const hash = window.location.hash.replace('#', '');
      Alpine.store('nav').page = (hash && hash !== 'login') ? hash : 'dashboard';
    },
    menu: sidebarMenu,
    get pageTitle() {
      const map = { dashboard: 'Beranda', providers: 'Mitra', customers: 'Pelanggan', categories: 'Kategori', services: 'Layanan', payments: 'Pembayaran', 'pricing-types': 'Tipe Harga' };
      return map[Alpine.store('nav').page] || '';
    }
  }));
});
