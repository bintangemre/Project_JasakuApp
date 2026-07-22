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

let _notifInterval = null;
async function fetchNotificationCounts() {
  try {
    const data = await apiFetch('/admin/notifications/counts');
    if (data) {
      Alpine.store('notifications').counts = data;
      Alpine.store('notifications').total = data.total || 0;
    }
  } catch (e) { /* silent */ }
}

function startNotificationPolling() {
  fetchNotificationCounts();
  if (_notifInterval) clearInterval(_notifInterval);
  _notifInterval = setInterval(fetchNotificationCounts, 15000);
}

function stopNotificationPolling() {
  if (_notifInterval) { clearInterval(_notifInterval); _notifInterval = null; }
}

function confirmModal(msg) {
  return new Promise((resolve) => {
    const store = Alpine.store('confirm');
    store.msg = msg;
    store.show = true;
    store.resolve = resolve;
  });
}

function getFileUrl(path) {
  if (!path) return '#';
  if (path.startsWith('http://') || path.startsWith('https://')) return path;
  const cleaned = path.replace(/\\/g, '/').replace(/^\//, '');
  return window.location.origin + '/' + cleaned;
}

function promptModal(msg) {
  return new Promise((resolve) => {
    const store = Alpine.store('prompt');
    store.msg = msg;
    store.value = '';
    store.show = true;
    store.resolve = resolve;
  });
}

document.addEventListener('alpine:init', () => {
  Alpine.store('nav', { page: 'login' });
  Alpine.store('toast', { show: false, msg: '', type: 'success' });
  Alpine.store('confirm', { show: false, msg: '', resolve: null });
  Alpine.store('prompt', { show: false, msg: '', value: '', resolve: null });
  Alpine.store('mobile', { show: false });
  Alpine.store('sidebar', { collapsed: false });
  Alpine.store('theme', {
    dark: localStorage.getItem('dark') === 'true' || (!localStorage.getItem('dark') && window.matchMedia('(prefers-color-scheme: dark)').matches)
  });
  Alpine.store('notifications', { counts: {}, total: 0, dropdownOpen: false });

  Alpine.data('providersPage', () => ({
    loading: true,
    providers: [],
    filter: 'all',
    _interval: null,
    init() { requireAuth(); this.load(); this._interval = setInterval(() => this.load(), 15000); },
    destroy() { if (this._interval) clearInterval(this._interval); },
    async load() {
      this.loading = true;
      try {
        this.providers = await apiFetch('/admin/providers' + (this.filter === 'pending' ? '?pending=true' : ''));
      } catch (e) { toast(e.message, 'error'); }
      finally { this.loading = false; }
    },
    async verifyProvider(id, notes) {
      try {
        await apiFetch('/admin/providers/' + id + '/verify', {
          method: 'PATCH',
          body: JSON.stringify({ status: 'verified', notes: notes || '' })
        });
        toast('Mitra diverifikasi');
        this.load();
      } catch (e) { toast(e.message, 'error'); }
    },
    async rejectProvider(id) {
      if (typeof window.__openChecklistModal !== 'function') return;
      const result = await window.__openChecklistModal(id);
      if (!result) return;
      try {
        await apiFetch('/admin/providers/' + id + '/verify', {
          method: 'PATCH',
          body: JSON.stringify(result)
        });
        toast('Mitra ditolak dengan catatan');
        this.load();
      } catch (e) { toast(e.message, 'error'); }
    },
    async unverifyProvider(id) {
      const ok = await confirmModal('Kembalikan mitra ke status pending?');
      if (!ok) return;
      try {
        await apiFetch('/admin/providers/' + id + '/unverify', { method: 'PATCH' });
        toast('Status mitra dikembalikan ke pending');
        this.load();
      } catch (e) { toast(e.message, 'error'); }
    },
    viewProviderDetail(id) {
      Alpine.store('nav').selectedProviderId = id;
      navigate('provider-detail');
    }
  }));

  Alpine.data('providerDetailPage', () => ({
    loading: true,
    provider: null,
    error: null,
    activeTab: 'profile',
    init() {
      requireAuth();
      this.load();
    },
    async load() {
      const id = Alpine.store('nav').selectedProviderId;
      if (!id) { navigate('providers'); return; }
      this.loading = true;
      this.error = null;
      try {
        this.provider = await apiFetch('/admin/providers/' + id + '/detail');
      } catch (e) { this.error = e.message; toast(e.message, 'error'); }
      finally { this.loading = false; }
    },
    goBack() { navigate('providers'); },
    async approveFromDetail() {
      const notes = await promptModal('Catatan (opsional):');
      if (notes === null) return;
      try {
        await apiFetch('/admin/providers/' + this.provider.id + '/verify', {
          method: 'PATCH',
          body: JSON.stringify({ status: 'verified', notes })
        });
        toast('Mitra berhasil diverifikasi');
        this.load();
      } catch (e) { toast(e.message, 'error'); }
    },
    async rejectFromDetail() {
      if (typeof window.__openChecklistModal !== 'function') return;
      const result = await window.__openChecklistModal(this.provider.id);
      if (!result) return;
      try {
        await apiFetch('/admin/providers/' + this.provider.id + '/verify', {
          method: 'PATCH',
          body: JSON.stringify(result)
        });
        toast('Mitra ditolak dengan catatan');
        this.load();
      } catch (e) { toast(e.message, 'error'); }
    },
    async resetToPending() {
      const ok = await confirmModal('Kembalikan mitra ke status pending?');
      if (!ok) return;
      try {
        await apiFetch('/admin/providers/' + this.provider.id + '/unverify', { method: 'PATCH' });
        toast('Status dikembalikan ke pending');
        this.load();
      } catch (e) { toast(e.message, 'error'); }
    },
    async rejectVerified() {
      if (typeof window.__openChecklistModal !== 'function') return;
      const result = await window.__openChecklistModal(this.provider.id);
      if (!result) return;
      try {
        await apiFetch('/admin/providers/' + this.provider.id + '/verify', {
          method: 'PATCH',
          body: JSON.stringify(result)
        });
        toast('Mitra ditolak dengan catatan');
        this.load();
      } catch (e) { toast(e.message, 'error'); }
    }
  }));

  Alpine.data('customersPage', () => ({
    loading: true,
    customers: [],
    init() { requireAuth(); this.load(); },
    async load() {
      this.loading = true;
      try {
        this.customers = await apiFetch('/admin/customers');
      } catch (e) { toast(e.message, 'error'); }
      finally { this.loading = false; }
    },
    async banUser(id) {
      const ok = await confirmModal('Ban pelanggan ini?');
      if (!ok) return;
      try {
        await apiFetch('/admin/customers/' + id + '/ban', { method: 'PATCH' });
        toast('Pelanggan di-ban');
        this.load();
      } catch (e) { toast(e.message, 'error'); }
    },
    async unbanUser(id) {
      try {
        await apiFetch('/admin/customers/' + id + '/unban', { method: 'PATCH' });
        toast('Ban dicabut');
        this.load();
      } catch (e) { toast(e.message, 'error'); }
    }
  }));

  const CHECKLIST_ITEMS = [
    { id: 'full_name', label: 'Nama lengkap sesuai KTP' },
    { id: 'profile_photo', label: 'Foto profil wajar dan sesuai' },
    { id: 'ktp_photo', label: 'Foto KTP jelas dan terbaca' },
    { id: 'selfie', label: 'Selfie sesuai KTP (face match)' },
    { id: 'documents', label: 'Dokumen ijazah/sertifikat jelas' },
    { id: 'phone', label: 'Nomor telepon valid' },
    { id: 'address', label: 'Alamat domisili valid' },
    { id: 'services', label: 'Layanan sesuai keahlian' },
  ];

  let _checklistResolve = null;

  Alpine.data('verificationChecklistModal', () => ({
    show: false,
    items: [],
    additionalNotes: '',
    submitting: false,
    init() {
      window.__openChecklistModal = (providerId) => {
        this.items = CHECKLIST_ITEMS.map(i => ({ ...i, status: 'passed', note: '' }));
        this.additionalNotes = '';
        this.show = true;
        return new Promise(resolve => { _checklistResolve = resolve; });
      };
    },
    close() {
      this.show = false;
      if (_checklistResolve) { _checklistResolve(null); _checklistResolve = null; }
    },
    async confirm() {
      this.submitting = true;
      const checklist = this.items.map(i => ({
        item: i.id,
        status: i.status,
        note: i.status === 'failed' ? (i.note || '') : undefined,
      }));
      this.show = false;
      this.submitting = false;
      if (_checklistResolve) {
        _checklistResolve({
          status: 'rejected',
          notes: this.additionalNotes || '',
          checklist,
        });
        _checklistResolve = null;
      }
    }
  }));

  Alpine.data('confirmExtensionPage', () => ({
    loading: true,
    extensions: [],
    activating: null,
    _interval: null,
    init() { requireAuth(); this.load(); this._interval = setInterval(() => this.load(), 15000); },
    destroy() { if (this._interval) clearInterval(this._interval); },
    async load() {
      this.loading = true;
      try {
        this.extensions = await apiFetch('/admin/extensions/pending-payment');
      } catch (e) { toast(e.message, 'error'); }
      finally { this.loading = false; }
    },
    async activateExtension(extensionId) {
      const ok = await confirmModal('Aktifkan ekstensi ini?');
      if (!ok) return;
      this.activating = extensionId;
      try {
        await apiFetch('/admin/extensions/' + extensionId + '/activate', { method: 'PATCH' });
        toast('Ekstensi berhasil diaktifkan');
        this.load();
      } catch (e) { toast(e.message, 'error'); }
      finally { this.activating = null; }
    }
  }));

  // ─── Pricing Types (Tabbed: Pricing Units / Contract Types / Service Mapping) ───

  Alpine.data('pricingTypesPage', () => ({
    activeTab: 'pricing-units',
    pricingUnits: [],
    contractTypes: [],
    services: [],
    loadingPU: true,
    loadingCT: true,
    loadingSvc: true,
    init() {
      requireAuth();
      this.loadPricingUnits();
      this.loadContractTypes();
      this.loadServices();
    },
    async loadPricingUnits() {
      this.loadingPU = true;
      try { this.pricingUnits = await apiFetch('/admin/pricing-units'); } catch (e) { toast(e.message, 'error'); }
      finally { this.loadingPU = false; }
    },
    async loadContractTypes() {
      this.loadingCT = true;
      try { this.contractTypes = await apiFetch('/admin/contract-types'); } catch (e) { toast(e.message, 'error'); }
      finally { this.loadingCT = false; }
    },
    async loadServices() {
      this.loadingSvc = true;
      try {
        const svcs = await apiFetch('/admin/services');
        // Fetch pivot counts for each service
        for (const svc of svcs) {
          try {
            const [puRes, ctRes] = await Promise.all([
              apiFetch('/admin/services/' + svc.id + '/pricing-units'),
              apiFetch('/admin/services/' + svc.id + '/contract-types'),
            ]);
            svc._puCount = puRes?.length || 0;
            svc._ctCount = ctRes?.length || 0;
          } catch { svc._puCount = 0; svc._ctCount = 0; }
        }
        this.services = svcs;
      } catch (e) { toast(e.message, 'error'); }
      finally { this.loadingSvc = false; }
    },
    openCreatePricingUnit() { Alpine.store('pricingUnitModal').openCreate(); },
    openEditPricingUnit(pu) { Alpine.store('pricingUnitModal').openEdit(pu); },
    async deletePricingUnit(pu) {
      const ok = await confirmModal('Hapus satuan harga "' + pu.name + '"?');
      if (!ok) return;
      try { await apiFetch('/admin/pricing-units/' + pu.id, { method: 'DELETE' }); toast('Satuan harga dihapus'); this.loadPricingUnits(); } catch (e) { toast(e.message, 'error'); }
    },
    openCreateContractType() { Alpine.store('contractTypeModal').openCreate(); },
    openEditContractType(ct) { Alpine.store('contractTypeModal').openEdit(ct); },
    async deleteContractType(ct) {
      const ok = await confirmModal('Hapus tipe kontrak "' + ct.name + '"?');
      if (!ok) return;
      try { await apiFetch('/admin/contract-types/' + ct.id, { method: 'DELETE' }); toast('Tipe kontrak dihapus'); this.loadContractTypes(); } catch (e) { toast(e.message, 'error'); }
    },
    openServiceMapping(svc) { Alpine.store('serviceMappingModal').open(svc); },
  }));

  Alpine.store('pricingUnitModal', { show: false, isEdit: false, editId: null, form: { name: '', unit: '', description: '' } });
  Alpine.data('pricingUnitModal', () => ({
    show: false, isEdit: false, editId: null, form: { name: '', unit: '', description: '' },
    init() { this.$store.pricingUnitModal = this; },
    openCreate() { this.isEdit = false; this.editId = null; this.form = { name: '', unit: '', description: '' }; this.show = true; },
    openEdit(pu) { this.isEdit = true; this.editId = pu.id; this.form = { name: pu.name || '', unit: pu.unit || '', description: pu.description || '' }; this.show = true; },
    close() { this.show = false; },
    async save() {
      try {
        if (this.isEdit) { await apiFetch('/admin/pricing-units/' + this.editId, { method: 'PUT', body: JSON.stringify(this.form) }); toast('Satuan harga diperbarui'); }
        else { await apiFetch('/admin/pricing-units', { method: 'POST', body: JSON.stringify(this.form) }); toast('Satuan harga ditambahkan'); }
        this.close();
        document.querySelector('[x-data="pricingTypesPage"]')?.__x?.$data.loadPricingUnits();
      } catch (e) { toast(e.message, 'error'); }
    }
  }));

  Alpine.store('contractTypeModal', { show: false, isEdit: false, editId: null, form: { name: '', description: '' } });
  Alpine.data('contractTypeModal', () => ({
    show: false, isEdit: false, editId: null, form: { name: '', description: '' },
    init() { this.$store.contractTypeModal = this; },
    openCreate() { this.isEdit = false; this.editId = null; this.form = { name: '', description: '' }; this.show = true; },
    openEdit(ct) { this.isEdit = true; this.editId = ct.id; this.form = { name: ct.name || '', description: ct.description || '' }; this.show = true; },
    close() { this.show = false; },
    async save() {
      try {
        if (this.isEdit) { await apiFetch('/admin/contract-types/' + this.editId, { method: 'PUT', body: JSON.stringify(this.form) }); toast('Tipe kontrak diperbarui'); }
        else { await apiFetch('/admin/contract-types', { method: 'POST', body: JSON.stringify(this.form) }); toast('Tipe kontrak ditambahkan'); }
        this.close();
        document.querySelector('[x-data="pricingTypesPage"]')?.__x?.$data.loadContractTypes();
      } catch (e) { toast(e.message, 'error'); }
    }
  }));

  Alpine.store('serviceMappingModal', { show: false, serviceId: '', serviceName: '', serviceCategory: '', allPU: [], allCT: [], assignedPU: [], assignedCT: [], loading: false });
  Alpine.data('serviceMappingModal', () => ({
    show: false, serviceId: '', serviceName: '', serviceCategory: '', allPU: [], allCT: [], assignedPU: [], assignedCT: [], loading: false,
    init() { this.$store.serviceMappingModal = this; },
    async open(svc) {
      this.serviceId = svc.id;
      this.serviceName = svc.name;
      this.serviceCategory = svc.categories?.name || '';
      this.show = true;
      this.loading = true;
      try {
        const [allPU, allCT, assignedPU, assignedCT] = await Promise.all([
          apiFetch('/admin/pricing-units'),
          apiFetch('/admin/contract-types'),
          apiFetch('/admin/services/' + svc.id + '/pricing-units'),
          apiFetch('/admin/services/' + svc.id + '/contract-types'),
        ]);
        this.allPU = allPU;
        this.allCT = allCT;
        this.assignedPU = (assignedPU || []).map(a => a.pricing_unit_id);
        this.assignedCT = (assignedCT || []).map(a => a.contract_type_id);
      } catch (e) { toast(e.message, 'error'); }
      finally { this.loading = false; }
    },
    close() { this.show = false; },
    async togglePricingUnit(puId) {
      const isAssigned = this.assignedPU.includes(puId);
      try {
        if (isAssigned) {
          await apiFetch('/admin/services/' + this.serviceId + '/pricing-units/' + puId, { method: 'DELETE' });
          this.assignedPU = this.assignedPU.filter(id => id !== puId);
        } else {
          await apiFetch('/admin/services/' + this.serviceId + '/pricing-units', { method: 'POST', body: JSON.stringify({ pricingUnitId: puId }) });
          this.assignedPU.push(puId);
        }
        // Refresh parent counts
        document.querySelector('[x-data="pricingTypesPage"]')?.__x?.$data.loadServices();
      } catch (e) { toast(e.message, 'error'); }
    },
    async toggleContractType(ctId) {
      const isAssigned = this.assignedCT.includes(ctId);
      try {
        if (isAssigned) {
          await apiFetch('/admin/services/' + this.serviceId + '/contract-types/' + ctId, { method: 'DELETE' });
          this.assignedCT = this.assignedCT.filter(id => id !== ctId);
        } else {
          await apiFetch('/admin/services/' + this.serviceId + '/contract-types', { method: 'POST', body: JSON.stringify({ contractTypeId: ctId }) });
          this.assignedCT.push(ctId);
        }
        document.querySelector('[x-data="pricingTypesPage"]')?.__x?.$data.loadServices();
      } catch (e) { toast(e.message, 'error'); }
    },
  }));

  Alpine.data('adminApp', () => ({
    init() {
      if (Alpine.store('theme').dark) document.documentElement.classList.add('dark');
      if (!getToken()) {
        Alpine.store('nav').page = 'login';
        stopNotificationPolling();
        return;
      }
      const hash = window.location.hash.replace('#', '');
      Alpine.store('nav').page = (hash && hash !== 'login') ? hash : 'dashboard';
      startNotificationPolling();
    },
    menu: sidebarMenu,
    get pageTitle() {
      const map = { dashboard: 'Beranda', 'confirm-payment': 'Konfirmasi Bayar', 'order-payout': 'Pencairan Dana', 'confirm-extension': 'Konfirmasi Ekstensi', 'custom-tasks': 'Custom Task', providers: 'Mitra', 'provider-detail': 'Detail Mitra', customers: 'Pelanggan', categories: 'Kategori', services: 'Layanan', payments: 'Pembayaran', 'pricing-types': 'Kelola Harga', reports: 'Laporan' };
      return map[Alpine.store('nav').page] || '';
    },
    get notifDropdownItems() {
      const c = Alpine.store('notifications').counts;
      const items = [];
      if (c.pendingPayments > 0) items.push({ label: 'Konfirmasi Bayar', count: c.pendingPayments, page: 'confirm-payment', icon: 'fa-hand-holding-usd', color: 'text-amber-500' });
      if (c.pendingOrderPayouts > 0) items.push({ label: 'Pencairan Dana', count: c.pendingOrderPayouts, page: 'order-payout', icon: 'fa-money-bill-wave', color: 'text-emerald-500' });
      if (c.pendingExtensions > 0) items.push({ label: 'Konfirmasi Ekstensi', count: c.pendingExtensions, page: 'confirm-extension', icon: 'fa-calendar-plus', color: 'text-blue-500' });
      if (c.pendingTaskPayments > 0) items.push({ label: 'Custom Task — Bayar', count: c.pendingTaskPayments, page: 'custom-tasks', icon: 'fa-tasks', color: 'text-purple-500' });
      if (c.pendingTaskPayouts > 0) items.push({ label: 'Custom Task — Pencairan', count: c.pendingTaskPayouts, page: 'custom-tasks', icon: 'fa-money-bill-wave', color: 'text-emerald-500' });
      if (c.pendingProviders > 0) items.push({ label: 'Mitra Pending', count: c.pendingProviders, page: 'providers', icon: 'fa-hard-hat', color: 'text-indigo-500' });
      if (c.openReports > 0) items.push({ label: 'Laporan Baru', count: c.openReports, page: 'reports', icon: 'fa-flag', color: 'text-red-500' });
      return items;
    },
    toggleNotifDropdown() {
      Alpine.store('notifications').dropdownOpen = !Alpine.store('notifications').dropdownOpen;
    },
    closeNotifDropdown() {
      Alpine.store('notifications').dropdownOpen = false;
    },
    navigateFromNotif(page) {
      Alpine.store('notifications').dropdownOpen = false;
      navigate(page);
    }
  }));
});
