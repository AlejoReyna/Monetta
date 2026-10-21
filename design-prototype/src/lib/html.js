// Tagged template that escapes every interpolation unless it is already safe
// markup. Pages build strings with it, so fixture text can never inject HTML.

class SafeHtml {
  constructor(value) {
    this.value = value;
  }

  toString() {
    return this.value;
  }
}

const ESCAPES = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };

export function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, (char) => ESCAPES[char]);
}

function render(value) {
  // `false`/null render nothing so `${cond && html`…`}` works; a bare `true`
  // is almost always a forgotten String() on an attribute, so it is an error.
  if (value === true) throw new TypeError('Boolean true interpolated into markup; use String(value) for attributes.');
  if (value === null || value === undefined || value === false) return '';
  if (value instanceof SafeHtml) return value.value;
  if (Array.isArray(value)) return value.map(render).join('');
  return escapeHtml(value);
}

export function html(strings, ...values) {
  let out = strings[0];
  for (let index = 0; index < values.length; index += 1) {
    out += render(values[index]) + strings[index + 1];
  }
  return new SafeHtml(out);
}

/** Marks trusted markup (icons, already-built fragments) as safe. */
export function raw(value) {
  return new SafeHtml(String(value));
}

/** Builds a query string from key/value pairs, skipping empty values. */
export function attrs(map) {
  return raw(
    Object.entries(map)
      .filter(([, value]) => value !== null && value !== undefined && value !== false)
      .map(([key, value]) => (value === true ? key : `${key}="${escapeHtml(value)}"`))
      .join(' '),
  );
}
