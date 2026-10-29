// Embedded Shopify Admin panel for push campaigns. Plain browser JavaScript,
// served as-is by the accounts_orders service (no build step). Every request
// carries a fresh App Bridge session token; the server decides access.
'use strict';

(() => {
  const statusLabels = {
    draft: 'Borrador',
    scheduled: 'Programado',
    targeting: 'Preparando',
    sending: 'Enviando',
    complete: 'Enviado',
    cancelled: 'Cancelado',
  };
  const cancellable = new Set(['draft', 'scheduled', 'targeting', 'sending']);
  const testDeviceKey = 'monetta.avisos.testDevice';
  const dateFormat = new Intl.DateTimeFormat('es-MX', { dateStyle: 'medium', timeStyle: 'short' });

  /** The draft under review: { id, title, body, eligible }. */
  let pending = null;
  let busy = false;

  const $ = (id) => document.getElementById(id);

  class ApiError extends Error {
    constructor(status, code) {
      super(`HTTP ${status}${code ? ` ${code}` : ''}`);
      this.status = status;
      this.code = code;
    }
  }

  async function api(path, { method = 'GET', body } = {}) {
    const token = await window.shopify.idToken();
    const headers = { Authorization: `Bearer ${token}` };
    if (body !== undefined) headers['Content-Type'] = 'application/json';
    const response = await fetch(path, {
      method,
      headers,
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    let payload = null;
    try {
      payload = await response.json();
    } catch {
      payload = null;
    }
    if (!response.ok) {
      const error = payload && payload.error;
      throw new ApiError(response.status, typeof error === 'string' ? error : error && error.code);
    }
    return payload;
  }

  function show(id, visible) {
    $(id).hidden = !visible;
  }

  function showStatus(message, tone = 'info') {
    const banner = $('status');
    banner.textContent = message;
    banner.className = `banner ${tone}`;
    banner.hidden = false;
    if (tone === 'success' && window.shopify && window.shopify.toast) {
      window.shopify.toast.show(message);
    }
  }

  function clearStatus() {
    $('status').hidden = true;
  }

  function errorMessage(error) {
    if (!(error instanceof ApiError)) return 'No se pudo conectar con el servidor de Monetta. Intenta de nuevo.';
    if (error.status === 400) return 'Revisa los campos: algún dato no es válido.';
    if (error.status === 401) return 'Tu sesión de Shopify expiró. Recarga la página.';
    if (error.status === 403) return 'Tu usuario de Shopify no tiene acceso a avisos.';
    if (error.status === 404) return 'Las notificaciones push están apagadas en este servidor.';
    if (error.status === 409) return 'Este aviso ya cambió de estado. Actualiza la lista.';
    if (error.status === 503) return 'El servidor no está disponible por ahora. Intenta en unos minutos.';
    return 'No se pudo completar. Intenta de nuevo.';
  }

  // `disabled` belongs to the panel state (draft locked, nobody eligible), so a
  // request in flight only dims the page; `run` refuses overlapping requests.
  function setBusy(value) {
    busy = value;
    document.body.setAttribute('aria-busy', String(value));
  }

  async function run(task) {
    if (busy) return;
    setBusy(true);
    try {
      await task();
    } catch (error) {
      showStatus(errorMessage(error), 'error');
    } finally {
      setBusy(false);
    }
  }

  // ---- Composer ------------------------------------------------------------

  function productKeyFrom(input) {
    const value = input.trim();
    const match = /^(\d+)$/.exec(value)
      || /\/products\/(\d+)(?:[/?#]|$)/.exec(value)
      || /Product\/(\d+)$/.exec(value);
    return match ? `shopify:gid://shopify/Product/${match[1]}` : null;
  }

  /** Returns { body } ready for POST /admin/notification-campaigns, or { error }. */
  function readDraft() {
    const title = $('title').value.trim();
    const body = $('body').value.trim();
    if (title === '' || body === '') return { error: 'Escribe el título y el mensaje.' };
    if (title.length > 80 || body.length > 180) return { error: 'El título o el mensaje es demasiado largo.' };

    let imageUrl = null;
    const rawImage = $('image-url').value.trim();
    if (rawImage !== '') {
      try {
        const url = new URL(rawImage);
        if (url.protocol !== 'https:') throw new Error('not https');
        imageUrl = url.toString();
      } catch {
        return { error: 'La imagen debe ser una URL que empiece con https://.' };
      }
    }

    let segment;
    const segmentKind = $('segment').value;
    if (segmentKind === 'brand' || segmentKind === 'category') {
      const value = $('trait').value.trim().toLowerCase();
      const minimumScore = Number($('minimum-score').value);
      if (value === '') {
        return { error: segmentKind === 'brand' ? 'Escribe la marca de la audiencia.' : 'Escribe la categoría de la audiencia.' };
      }
      if (!Number.isInteger(minimumScore) || minimumScore < 1 || minimumScore > 100) {
        return { error: 'La afinidad mínima debe ser un número entre 1 y 100.' };
      }
      segment = { kind: segmentKind, value, minimumScore };
    } else {
      segment = { kind: segmentKind };
    }

    let route;
    const routeType = $('route').value;
    if (routeType === 'product') {
      const productKey = productKeyFrom($('route-product').value);
      if (productKey === null) return { error: 'Pega el ID del producto o su URL de Shopify Admin.' };
      route = { type: 'product', productKey };
    } else if (routeType === 'collection') {
      const handle = $('route-collection').value.trim();
      if (handle === '') return { error: 'Escribe el handle de la colección.' };
      route = { type: 'collection', handle };
    } else {
      route = { type: routeType };
    }

    return {
      body: {
        kind: 'manual',
        purpose: $('purpose').value,
        title,
        body,
        imageUrl,
        route,
        segment,
      },
    };
  }

  function syncConditionalFields() {
    const segmentKind = $('segment').value;
    show('trait-row', segmentKind === 'brand' || segmentKind === 'category');
    $('trait-label').textContent = segmentKind === 'category' ? 'Categoría' : 'Marca';
    $('trait').placeholder = segmentKind === 'category' ? 'bolsas' : 'coach';
    const routeType = $('route').value;
    show('route-product-field', routeType === 'product');
    show('route-collection-field', routeType === 'collection');
  }

  function syncCounters() {
    for (const counter of document.querySelectorAll('.counter')) {
      const input = $(counter.dataset.for);
      counter.textContent = `${input.value.length}/${input.maxLength}`;
    }
  }

  function setComposerLocked(locked) {
    $('compose-fields').disabled = locked;
    $('create').disabled = locked;
  }

  // ---- Review --------------------------------------------------------------

  function renderReview() {
    if (pending === null) {
      show('review', false);
      return;
    }
    $('eligible-count').textContent = String(pending.eligible);
    $('eligible-label').textContent = pending.eligible === 1 ? 'dispositivo' : 'dispositivos';
    $('review-title').textContent = pending.title;
    $('review-body').textContent = pending.body;
    $('send-now').disabled = pending.eligible === 0;
    $('send-now').title = pending.eligible === 0 ? 'Nadie lo recibiría ahora; puedes programarlo.' : '';
    show('confirm-send', false);
    show('review', true);
  }

  function clearPending() {
    pending = null;
    renderReview();
    setComposerLocked(false);
  }

  /** A 409 means the draft was sent or cancelled elsewhere; stop reviewing it. */
  async function dropStaleDraft(error) {
    if (!(error instanceof ApiError && error.status === 409)) throw error;
    clearPending();
    await refresh();
    throw error;
  }

  async function createDraft(event) {
    event.preventDefault();
    const draft = readDraft();
    if (draft.error) {
      showStatus(draft.error, 'error');
      return;
    }
    await run(async () => {
      const { campaign } = await api('/admin/notification-campaigns', { method: 'POST', body: draft.body });
      const preview = await api(`/admin/notification-campaigns/${campaign.id}/preview`, { method: 'POST' });
      pending = {
        id: campaign.id,
        title: draft.body.title,
        body: draft.body.body,
        eligible: Number(preview.eligible) || 0,
      };
      clearStatus();
      setComposerLocked(true);
      renderReview();
      await refresh();
    });
    if (pending !== null) $('review').scrollIntoView({ behavior: 'smooth', block: 'start' });
  }

  async function sendTest() {
    const deviceId = $('test-device').value.trim();
    if (deviceId === '') {
      showStatus('Escribe el Device ID del teléfono de prueba.', 'error');
      return;
    }
    try {
      localStorage.setItem(testDeviceKey, deviceId);
    } catch {
      // Remembering the device is a convenience only.
    }
    await run(async () => {
      await api(`/admin/notification-campaigns/${pending.id}/test`, { method: 'POST', body: { deviceId } });
      showStatus('Prueba en cola. Llega en cuanto el worker de avisos la procese.', 'success');
      await refresh();
    });
  }

  async function schedule(scheduledAt) {
    await run(async () => {
      await api(`/admin/notification-campaigns/${pending.id}/schedule`, {
        method: 'POST',
        body: scheduledAt === null ? {} : { scheduledAt: scheduledAt.toISOString() },
      }).catch(dropStaleDraft);
      showStatus(
        scheduledAt === null
          ? 'Aviso enviado a la cola.'
          : `Aviso programado para ${dateFormat.format(scheduledAt)}.`,
        'success',
      );
      clearPending();
      $('compose').reset();
      syncConditionalFields();
      syncCounters();
      await refresh();
    });
  }

  function scheduleLater() {
    const value = $('schedule-at').value;
    const when = value === '' ? null : new Date(value);
    if (when === null || Number.isNaN(when.getTime())) {
      showStatus('Elige la fecha y hora del envío.', 'error');
      return;
    }
    if (when.getTime() < Date.now()) {
      showStatus('Elige una hora en el futuro.', 'error');
      return;
    }
    void schedule(when);
  }

  function askToSendNow() {
    $('confirm-text').textContent = `¿Enviar “${pending.title}” a ${pending.eligible} `
      + `${pending.eligible === 1 ? 'dispositivo' : 'dispositivos'} ahora? No se puede deshacer una vez entregado.`;
    show('confirm-send', true);
    $('confirm-go').focus();
  }

  async function discard() {
    const id = pending.id;
    await run(async () => {
      await api(`/admin/notification-campaigns/${id}/cancel`, { method: 'POST' }).catch((error) => {
        // Already gone elsewhere: there is nothing left to discard.
        if (!(error instanceof ApiError && error.status === 409)) throw error;
      });
      clearPending();
      clearStatus();
      await refresh();
    });
  }

  // ---- Overview ------------------------------------------------------------

  function cell(text, className) {
    const td = document.createElement('td');
    td.textContent = text;
    if (className) td.className = className;
    return td;
  }

  function renderCampaigns(campaigns) {
    const tbody = $('campaigns').querySelector('tbody');
    tbody.replaceChildren();
    for (const campaign of campaigns) {
      const row = document.createElement('tr');
      const title = campaign.kind === 'test' ? `${campaign.title} (prueba)` : campaign.title;
      const when = new Date(campaign.scheduledAt || campaign.createdAt);
      row.append(
        cell(title, 'title'),
        cell(statusLabels[campaign.status] || campaign.status),
        cell(Number.isNaN(when.getTime()) ? '' : dateFormat.format(when)),
        cell(String(campaign.eligibleCount), 'num'),
        cell(String(campaign.acceptedCount), 'num'),
        cell(String(campaign.openedCount), 'num'),
        cell(String(campaign.failedCount), 'num'),
      );
      const actions = document.createElement('td');
      if (cancellable.has(campaign.status)) {
        const button = document.createElement('button');
        button.type = 'button';
        button.textContent = 'Cancelar';
        button.addEventListener('click', () => void cancelCampaign(campaign.id));
        actions.append(button);
      }
      row.append(actions);
      tbody.append(row);
    }
    show('campaigns', campaigns.length > 0);
    show('campaigns-empty', campaigns.length === 0);
  }

  async function cancelCampaign(id) {
    await run(async () => {
      await api(`/admin/notification-campaigns/${id}/cancel`, { method: 'POST' });
      if (pending !== null && pending.id === id) clearPending();
      showStatus('Aviso cancelado.', 'success');
      await refresh();
    });
  }

  async function refresh() {
    let overview;
    try {
      overview = await api('/admin/notifications/overview');
    } catch (error) {
      if (error instanceof ApiError && error.status === 404) {
        setComposerLocked(true);
        showStatus(
          'Las notificaciones push están apagadas en este servidor. '
          + 'Se activan con NOTIFICATIONS_ENABLED y el worker de avisos.',
          'error',
        );
        return;
      }
      throw error;
    }
    $('stat-active').textContent = String(overview.activeEndpoints);
    $('stat-granted').textContent = String(overview.grantedEndpoints);
    $('stat-profiles').textContent = String(overview.personalizedProfiles);
    $('stat-queued').textContent = String(overview.queuedDeliveries);
    renderCampaigns(Array.isArray(overview.recentCampaigns) ? overview.recentCampaigns : []);
  }

  // ---- Boot ----------------------------------------------------------------

  function staffIdFrom(actorId) {
    return typeof actorId === 'string' && actorId.startsWith('shopify_staff:')
      ? actorId.slice('shopify_staff:'.length)
      : String(actorId || '');
  }

  async function boot() {
    if (!window.shopify || typeof window.shopify.idToken !== 'function') {
      show('loading', false);
      showStatus('Abre este panel desde Shopify Admin, en Apps.', 'error');
      return;
    }

    let me;
    try {
      me = await api('/admin/me');
    } catch (error) {
      show('loading', false);
      showStatus(error instanceof ApiError ? errorMessage(error) : 'Abre este panel desde Shopify Admin, en Apps.', 'error');
      return;
    }

    show('loading', false);
    const environment = $('environment');
    environment.textContent = me.environment === 'production' ? 'Producción' : 'Staging';
    environment.className = `badge ${me.environment === 'production' ? 'production' : 'staging'}`;
    environment.hidden = false;

    if (!me.capabilities || me.capabilities.manageNotifications !== true) {
      $('staff-id').textContent = staffIdFrom(me.actor && me.actor.id);
      show('denied', true);
      return;
    }

    try {
      $('test-device').value = localStorage.getItem(testDeviceKey) || '';
    } catch {
      // Storage can be blocked inside the admin iframe; the field just starts empty.
    }
    $('compose').addEventListener('submit', createDraft);
    $('segment').addEventListener('change', syncConditionalFields);
    $('route').addEventListener('change', syncConditionalFields);
    $('title').addEventListener('input', syncCounters);
    $('body').addEventListener('input', syncCounters);
    $('send-test').addEventListener('click', () => void sendTest());
    $('schedule').addEventListener('click', scheduleLater);
    $('send-now').addEventListener('click', askToSendNow);
    $('confirm-back').addEventListener('click', () => show('confirm-send', false));
    $('confirm-go').addEventListener('click', () => void schedule(null));
    $('discard').addEventListener('click', () => void discard());
    $('refresh').addEventListener('click', () => void run(refresh));
    syncConditionalFields();
    syncCounters();
    show('panel', true);
    await run(refresh);
  }

  void boot();
})();
