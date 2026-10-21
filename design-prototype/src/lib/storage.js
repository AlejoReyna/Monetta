// Browser storage that never throws. Private windows, blocked site data and
// quota errors fall back to memory, and callers can ask which one is in use.

const PREFIX = 'monetta-proto:v1:';
const memory = new Map();
let usable = probe(globalThis.localStorage);
let forcedOff = readSessionFlag('storage-blocked');

function probe(area) {
  try {
    const key = `${PREFIX}probe`;
    area.setItem(key, '1');
    area.removeItem(key);
    return true;
  } catch {
    return false;
  }
}

function readSessionFlag(name) {
  try {
    return globalThis.sessionStorage?.getItem(`${PREFIX}${name}`) === '1';
  } catch {
    return false;
  }
}

export function storageAvailable() {
  return usable && !forcedOff;
}

/** Demo control: behave as if the browser blocked storage (kept for the tab). */
export function setStorageBlocked(blocked) {
  forcedOff = blocked;
  try {
    if (blocked) globalThis.sessionStorage.setItem(`${PREFIX}storage-blocked`, '1');
    else globalThis.sessionStorage.removeItem(`${PREFIX}storage-blocked`);
  } catch {
    // The flag then lasts until reload, which is acceptable for a demo toggle.
  }
}

export function readJson(key, fallback) {
  if (memory.has(key)) return memory.get(key);
  if (!storageAvailable()) return fallback;
  try {
    const value = globalThis.localStorage.getItem(PREFIX + key);
    return value === null ? fallback : JSON.parse(value);
  } catch {
    return fallback;
  }
}

export function writeJson(key, value) {
  memory.set(key, value);
  if (!storageAvailable()) return false;
  try {
    globalThis.localStorage.setItem(PREFIX + key, JSON.stringify(value));
    return true;
  } catch {
    usable = false;
    return false;
  }
}

export function readSession(key, fallback) {
  try {
    const value = globalThis.sessionStorage.getItem(PREFIX + key);
    return value === null ? fallback : JSON.parse(value);
  } catch {
    return fallback;
  }
}

export function writeSession(key, value) {
  try {
    globalThis.sessionStorage.setItem(PREFIX + key, JSON.stringify(value));
  } catch {
    // Demo switches simply reset on reload when session storage is blocked.
  }
}

export function clearAll() {
  memory.clear();
  try {
    for (const key of Object.keys(globalThis.localStorage)) {
      if (key.startsWith(PREFIX)) globalThis.localStorage.removeItem(key);
    }
  } catch {
    // Nothing persisted, nothing to clear.
  }
}
