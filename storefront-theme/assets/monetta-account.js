/* Display-name and photo preferences are local to this browser and scoped to a customer. */
(() => {
  'use strict';
  const readPhoto = async (file) => {
    if (!['image/jpeg', 'image/png', 'image/webp', 'image/avif'].includes(file.type)) {
      throw new Error('Elige una imagen JPG, PNG, WebP o AVIF.');
    }
    if (file.size > 10 * 1024 * 1024) throw new Error('La imagen debe pesar menos de 10 MB.');
    const url = URL.createObjectURL(file);
    try {
      const photo = new Image();
      photo.src = url;
      try { await photo.decode(); } catch { throw new Error('No pudimos leer esta imagen. Prueba con otra foto.'); }
      const size = Math.min(photo.naturalWidth, photo.naturalHeight);
      if (!size) throw new Error('No pudimos leer esta imagen. Prueba con otra foto.');
      const canvas = document.createElement('canvas');
      canvas.width = canvas.height = 512;
      const context = canvas.getContext('2d');
      if (!context) throw new Error('No pudimos preparar la imagen. Inténtalo de nuevo.');
      context.fillStyle = '#fffdf9';
      context.fillRect(0, 0, 512, 512);
      context.drawImage(photo, (photo.naturalWidth - size) / 2, (photo.naturalHeight - size) / 2, size, size, 0, 0, 512, 512);
      return canvas.toDataURL('image/jpeg', 0.86);
    } finally {
      URL.revokeObjectURL(url);
    }
  };
  const initializeProfile = (root) => {
    const dialog = root.querySelector('#account-profile-editor');
    const form = dialog?.querySelector('[data-profile-form]');
    const customer = root.dataset.accountCustomer;
    if (!form || !customer) return;
    const input = form.querySelector('[data-profile-input]');
    const fileInput = form.querySelector('[data-profile-file]');
    const save = form.querySelector('[data-profile-save]');
    const error = form.querySelector('[data-profile-error]');
    const previewPhoto = form.querySelector('[data-profile-preview-photo]');
    const previewInitial = form.querySelector('[data-profile-preview-initial]');
    const remove = form.querySelector('[data-profile-remove]');
    const key = `monetta.profile.v1.${window.location.hostname}.${customer}`;
    const originalName = root.querySelector('[data-profile-name]').textContent.trim();
    const originalInitial = root.querySelector('[data-profile-initial]').textContent.trim();
    const defaults = { name: originalName, photo: '' };
    const load = () => {
      try {
        const data = JSON.parse(localStorage.getItem(key));
        return {
          name: typeof data?.name === 'string' && data.name.trim() && data.name.length <= 80 ? data.name.trim() : originalName,
          photo: typeof data?.photo === 'string' && data.photo.length <= 1000000 && /^data:image\/jpeg;base64,[A-Za-z0-9+/=]+$/.test(data.photo) ? data.photo : '',
        };
      } catch { return { ...defaults }; }
    };
    let profile = load();
    let pendingPhoto = profile.photo;
    let imageJob = 0;
    let readingPhoto = false;
    const showError = (message = '') => { error.textContent = message; error.hidden = !message; };
    const setReading = (reading) => {
      readingPhoto = reading;
      save.disabled = reading;
      save.textContent = reading ? 'Preparando foto…' : 'Guardar cambios';
    };
    const setPhoto = (photo, value) => {
      photo.hidden = !value;
      if (value) photo.src = value;
      else photo.removeAttribute('src');
    };
    const apply = () => {
      root.querySelector('[data-profile-name]').textContent = profile.name;
      const initial = root.querySelector('[data-profile-initial]');
      initial.textContent = [...profile.name][0]?.toLocaleUpperCase('es-MX') || originalInitial;
      initial.hidden = !!profile.photo;
      setPhoto(root.querySelector('[data-profile-photo]'), profile.photo);
    };
    const preview = () => {
      setPhoto(previewPhoto, pendingPhoto);
      previewInitial.hidden = !!pendingPhoto;
      previewInitial.textContent = [...input.value.trim()][0]?.toLocaleUpperCase('es-MX') || originalInitial;
      remove.hidden = !pendingPhoto;
    };
    apply();
    dialog.addEventListener('monetta:dialog-open', () => {
      imageJob += 1;
      profile = load();
      input.value = profile.name;
      pendingPhoto = profile.photo;
      fileInput.value = '';
      setReading(false);
      showError();
      preview();
    });
    dialog.addEventListener('monetta:dialog-close', () => { imageJob += 1; setReading(false); });
    input.addEventListener('input', () => { showError(); preview(); });
    fileInput.addEventListener('change', async () => {
      const file = fileInput.files[0];
      if (!file) return;
      const job = ++imageJob;
      showError();
      setReading(true);
      try {
        const photo = await readPhoto(file);
        if (job !== imageJob || !dialog.open) return;
        pendingPhoto = photo;
        preview();
      } catch (failure) {
        if (job === imageJob) showError(failure.message);
      } finally {
        if (job === imageJob) setReading(false);
        fileInput.value = '';
      }
    });
    remove.addEventListener('click', () => { imageJob += 1; pendingPhoto = ''; setReading(false); showError(); preview(); });
    form.addEventListener('submit', (event) => {
      event.preventDefault();
      if (readingPhoto) return;
      const name = input.value.trim();
      if (!name || name.length > 80) { showError('Escribe un nombre de hasta 80 caracteres.'); input.focus(); return; }
      const next = { name, photo: pendingPhoto };
      try { localStorage.setItem(key, JSON.stringify(next)); }
      catch { showError('No pudimos guardar el perfil en este navegador. Revisa el espacio disponible e inténtalo de nuevo.'); return; }
      profile = next;
      apply();
      root.querySelector('[data-profile-status]').textContent = 'Foto y nombre guardados en este navegador.';
      window.Monetta?.closeDialog(dialog);
    });
    window.addEventListener('storage', (event) => {
      if (event.key === key && root.isConnected) { profile = load(); apply(); }
    });
  };
  const initialize = (root) => {
    if (!root || root.dataset.accountReady) return;
    root.dataset.accountReady = 'true';
    initializeProfile(root);
    const filters = root.querySelector('[data-order-filters]');
    const cards = [...root.querySelectorAll('[data-orders] > [data-order-card]')];
    const filterOrders = (value) => {
      let visible = 0;
      for (const card of cards) {
        card.hidden = value !== 'all' && card.dataset.orderGroup !== value;
        if (!card.hidden) visible += 1;
      }
      for (const button of filters?.querySelectorAll('[data-order-filter]') || []) {
        button.setAttribute('aria-pressed', String(button.dataset.orderFilter === value));
      }
      const empty = root.querySelector('[data-order-empty]');
      if (empty) empty.hidden = visible > 0;
      const count = root.querySelector('[data-order-count]');
      if (count) count.textContent = `${visible} ${visible === 1 ? 'pedido' : 'pedidos'}`;
    };
    if (filters) {
      filters.hidden = false;
      filters.addEventListener('click', (event) => {
        const button = event.target.closest('[data-order-filter]');
        if (button) filterOrders(button.dataset.orderFilter);
      });
      root.querySelector('[data-order-reset]')?.addEventListener('click', () => {
        filterOrders('all');
        filters.querySelector('[data-order-filter="all"]')?.focus();
      });
    }
    root.querySelector('[data-share-catalog]')?.addEventListener('click', async (event) => {
      const button = event.currentTarget;
      const status = root.querySelector('[data-share-status]');
      const url = button.dataset.shareUrl;
      button.disabled = true;
      try {
        if (navigator.share) {
          await navigator.share({ title: 'El catálogo de Monetta', url });
          status.textContent = 'Gracias por compartir Monetta.';
        } else if (navigator.clipboard && window.isSecureContext) {
          await navigator.clipboard.writeText(url);
          status.textContent = 'Enlace copiado. Compártelo con quien quieras.';
        } else {
          throw new Error('Share unavailable');
        }
      } catch (error) {
        if (error.name !== 'AbortError') {
          status.replaceChildren();
          const link = document.createElement('a');
          link.href = url;
          link.textContent = 'Abrir el catálogo para compartir su enlace';
          status.append(link);
        }
      } finally {
        button.disabled = false;
      }
    });
  };
  document.querySelectorAll('[data-account-root]').forEach(initialize);
  document.addEventListener('shopify:section:load', (event) => {
    event.target.querySelectorAll('[data-account-root]').forEach(initialize);
  });
})();
