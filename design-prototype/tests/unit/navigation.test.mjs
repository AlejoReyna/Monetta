// History bookkeeping behind the in-page back arrow: filters and sort push
// extra entries onto a screen (so the browser's Back restores them), and the
// arrow must leave the screen instead of stepping through them.
import assert from 'node:assert/strict';
import test, { mock } from 'node:test';
import { leaveScreen, navigate, nextHistoryState, screenBackSteps, startRouter, updateUrl } from '../../src/lib/router.js';

const first = { scrollY: 0 };

test('a visit that began on this screen has nothing to go back to', () => {
  assert.equal(screenBackSteps(undefined), 0);
  assert.equal(screenBackSteps(first), 0);
  assert.equal(screenBackSteps({ idx: 0, entry: 0 }), 0);
});

test('opening another screen makes one step back leave it', () => {
  const state = nextHistoryState(first);
  assert.deepEqual(state, { scrollY: 0, idx: 1, entry: 1 });
  assert.equal(screenBackSteps(state), 1);
});

test('filter and sort entries stay inside the screen they belong to', () => {
  let state = nextHistoryState(first); // Home → collection
  state = nextHistoryState(state, { keep: true }); // filter
  state = nextHistoryState(state, { keep: true }); // sort
  assert.deepEqual(state, { scrollY: 0, idx: 3, entry: 1 });
  // The arrow skips both extra entries and lands on Home; Back would only undo the sort.
  assert.equal(screenBackSteps(state), 3);
});

test('the next screen starts its own run after filters', () => {
  let state = nextHistoryState(first);
  state = nextHistoryState(state, { keep: true });
  state = nextHistoryState(state); // collection → product
  assert.deepEqual(state, { scrollY: 0, idx: 3, entry: 3 });
  assert.equal(screenBackSteps(state), 1);
});

test('filters applied on the first screen of a visit still have nowhere to go back to', () => {
  let state = nextHistoryState(first, { keep: true });
  state = nextHistoryState(state, { keep: true });
  assert.deepEqual(state, { scrollY: 0, idx: 2, entry: 0 });
  assert.equal(screenBackSteps(state), 0);
});

test('replacing the entry (retry, variant) never moves the counters', () => {
  const state = nextHistoryState({ idx: 4, entry: 2 }, { replace: true });
  assert.deepEqual(state, { scrollY: 0, idx: 4, entry: 2 });
  assert.equal(screenBackSteps(state), 3);
});

// ---------------------------------------------------------------------------
// leaveScreen: the arrow's fallback belongs to the operation that armed it.
// A small history that completes traversals only when the test says so.
// ---------------------------------------------------------------------------

const ORIGIN = 'http://localhost';

function createBrowser(visited) {
  const entries = visited.map(({ path, state }) => ({ url: new URL(path, ORIGIN).href, state }));
  const listeners = {};
  const record = { goCalls: [], pushes: [], renders: [] };
  let index = entries.length - 1;
  let pendingGo = null;

  globalThis.location = {
    get href() {
      return entries[index].url;
    },
    origin: ORIGIN,
  };
  globalThis.history = {
    get state() {
      return entries[index].state;
    },
    scrollRestoration: 'auto',
    pushState(state, _title, path) {
      entries.splice(index + 1);
      entries.push({ url: new URL(path, ORIGIN).href, state });
      index = entries.length - 1;
      record.pushes.push(path);
    },
    replaceState(state, _title, path) {
      entries[index] = { url: path ? new URL(path, ORIGIN).href : entries[index].url, state };
    },
    go(delta) {
      record.goCalls.push(delta);
      pendingGo = delta;
    },
  };
  globalThis.window = {
    scrollY: 0,
    scrollTo() {},
    addEventListener(type, handler) {
      (listeners[type] ??= []).push(handler);
    },
  };
  globalThis.document = { addEventListener() {} };

  const fire = (type, event = {}) => {
    for (const handler of listeners[type] ?? []) handler(event);
  };
  startRouter((options) => record.renders.push(options));
  record.renders.length = 0;

  return {
    record,
    path: () => new URL(entries[index].url).pathname,
    /** The browser finishes the last history.go(): popstate fires only when the entry exists. */
    completeGo() {
      const delta = pendingGo;
      pendingGo = null;
      const target = index + delta;
      if (target < 0 || target >= entries.length) return false;
      index = target;
      fire('popstate');
      return true;
    },
    forward() {
      index += 1;
      fire('popstate');
    },
    restoreFromCache: () => fire('pageshow', { persisted: true }),
  };
}

const visit = (path, idx, entry) => ({ path, state: { scrollY: 0, idx, entry } });
const homeCollectionProduct = () => [visit('/', 0, 0), visit('/collections/carteras-1', 1, 1), visit('/products/cartera', 2, 2)];

test('Forward right after the arrow is not undone by the arrow\'s fallback', () => {
  mock.timers.enable({ apis: ['setTimeout'] });
  try {
    const browser = createBrowser(homeCollectionProduct());
    leaveScreen('/collections/carteras-1');
    assert.deepEqual(browser.record.goCalls, [-1]);
    assert.ok(browser.completeGo());
    assert.equal(browser.path(), '/collections/carteras-1');
    browser.forward(); // before the 500 ms are up, back on the product
    mock.timers.tick(600);
    assert.equal(browser.path(), '/products/cartera');
    assert.deepEqual(browser.record.pushes, []);
  } finally {
    mock.timers.reset();
  }
});

test('a link opened after the arrow wins even when it lands on the address the arrow left', () => {
  mock.timers.enable({ apis: ['setTimeout'] });
  try {
    const browser = createBrowser(homeCollectionProduct());
    leaveScreen('/collections/carteras-1');
    browser.completeGo();
    navigate('/products/cartera'); // the same product, opened again from the restored list
    mock.timers.tick(600);
    assert.deepEqual(browser.record.pushes, ['/products/cartera']);
    assert.equal(browser.path(), '/products/cartera');
  } finally {
    mock.timers.reset();
  }
});

test('a changed address or a restore from the cache after the arrow also retires the fallback', () => {
  mock.timers.enable({ apis: ['setTimeout'] });
  try {
    const browser = createBrowser(homeCollectionProduct());
    leaveScreen('/collections/carteras-1');
    updateUrl('/products/cartera?variant=2');
    mock.timers.tick(600);
    assert.deepEqual(browser.record.pushes, []);

    leaveScreen('/collections/carteras-1');
    browser.restoreFromCache();
    mock.timers.tick(600);
    assert.deepEqual(browser.record.pushes, []);
  } finally {
    mock.timers.reset();
  }
});

test('when the earlier entries are gone the arrow still reaches its parent', () => {
  mock.timers.enable({ apis: ['setTimeout'] });
  try {
    // A restored session keeps the counters but not the entries they refer to.
    const browser = createBrowser([visit('/products/cartera', 2, 2)]);
    leaveScreen('/collections/carteras-1');
    assert.deepEqual(browser.record.goCalls, [-1]);
    assert.equal(browser.completeGo(), false);
    mock.timers.tick(499);
    assert.deepEqual(browser.record.pushes, []);
    mock.timers.tick(1);
    assert.deepEqual(browser.record.pushes, ['/collections/carteras-1']);
  } finally {
    mock.timers.reset();
  }
});

test('a visit that began on the screen goes to the parent without touching the history', () => {
  mock.timers.enable({ apis: ['setTimeout'] });
  try {
    const browser = createBrowser([visit('/products/cartera', 0, 0)]);
    leaveScreen('/collections/carteras-1');
    assert.deepEqual(browser.record.goCalls, []);
    assert.deepEqual(browser.record.pushes, ['/collections/carteras-1']);
  } finally {
    mock.timers.reset();
  }
});

test('the arrow skips the filter entries of its screen in one step; the fallback stays quiet', () => {
  mock.timers.enable({ apis: ['setTimeout'] });
  try {
    const browser = createBrowser([visit('/', 0, 0), visit('/collections/carteras-1', 1, 1), visit('/collections/carteras-1?filter.v.availability=1', 2, 1), visit('/collections/carteras-1?sort_by=price-ascending', 3, 1)]);
    leaveScreen('/');
    assert.deepEqual(browser.record.goCalls, [-3]);
    assert.ok(browser.completeGo());
    assert.equal(browser.path(), '/');
    mock.timers.tick(600);
    assert.deepEqual(browser.record.pushes, []);
  } finally {
    mock.timers.reset();
  }
});
