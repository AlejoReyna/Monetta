// What the pinned chrome covers (lib/chrome.js) and where a horizontal scroller moves to
// show a focused item (lib/scrollers.js): the arithmetic behind scroll-padding and keyboard focus.
import assert from 'node:assert/strict';
import test from 'node:test';
import { pinnedReserve } from '../../src/lib/chrome.js';
import { scrollerTarget } from '../../src/lib/scrollers.js';

const sticky = (offset, size, extra = {}) => ({ display: 'block', position: 'sticky', offset, size, ...extra });

test('the page bar is reserved at its real height, not at its minimum', () => {
  // 28px strip, then a bar that wrapped its title to two lines (97.31px).
  assert.equal(pinnedReserve([sticky(0, 28), sticky(28, 97.3125)]), 125.31);
  assert.equal(pinnedReserve([sticky(0, 28), sticky(28, 76)]), 104);
});

test('bars that are hidden, static or without an offset cover nothing', () => {
  assert.equal(pinnedReserve([sticky(0, 28, { display: 'none' })]), 0);
  assert.equal(pinnedReserve([sticky(0, 28, { position: 'static' })]), 0);
  assert.equal(pinnedReserve([sticky(Number.NaN, 60)]), 0);
  assert.equal(pinnedReserve([]), 0);
});

test('fixed bottom controls reserve their offset plus their height', () => {
  const dock = { display: 'block', position: 'fixed', offset: 0, size: 88 };
  assert.equal(pinnedReserve([dock]), 88);
  assert.equal(pinnedReserve([{ ...dock, size: 109 }]), 109); // home indicator: 88 + 21
  assert.equal(pinnedReserve([{ ...dock, offset: 12, size: 64 }]), 76);
});

test('the largest reserve wins when several bars are pinned to the same edge', () => {
  assert.equal(pinnedReserve([sticky(0, 89), sticky(28, 97)]), 125);
});

// Rail: 20px padding, 140px cards, 12px gap, a 390px viewport, snapping to item starts.
// Card n starts at 20 + 152n.
const rail = { viewWidth: 390, padStart: 20, padEnd: 20, maxScroll: 700, snap: true };
const card = (n) => ({ itemStart: 20 + 152 * n, itemEnd: 160 + 152 * n });

test('a card that is already inside the rail leaves it alone', () => {
  assert.equal(scrollerTarget({ ...rail, ...card(0), scrollLeft: 0 }), null);
  assert.equal(scrollerTarget({ ...rail, ...card(1), scrollLeft: 0 }), null);
});

test('a snapping rail takes the focused card to its own snap position', () => {
  // Third card: 324…464 of a 390px view. Snapping happens by start edge, so the target is 304.
  assert.equal(scrollerTarget({ ...rail, ...card(2), scrollLeft: 0 }), 304);
});

test('going back to a card scrolled out on the left aligns it to the start padding', () => {
  assert.equal(scrollerTarget({ ...rail, ...card(1), scrollLeft: 304 }), 152);
  assert.equal(scrollerTarget({ ...rail, ...card(0), scrollLeft: 304 }), 0);
});

test('the target never leaves the scrollable range', () => {
  assert.equal(scrollerTarget({ ...rail, itemStart: 900, itemEnd: 1040, scrollLeft: 0, maxScroll: 650 }), 650);
  assert.equal(scrollerTarget({ ...rail, itemStart: 5, itemEnd: 145, scrollLeft: 100 }), 0);
});

// Chip row without snapping: 20px padding, chips 100–144px wide, 8px gap, 390px viewport, 178px of overflow.
const chips = { viewWidth: 390, padStart: 20, padEnd: 20, maxScroll: 178, snap: false };

test('a chip half outside the row moves the least that clears the padding', () => {
  // "Crossbodys" at 280…423: 33px too far right, plus the 20px padding.
  assert.equal(scrollerTarget({ ...chips, itemStart: 280, itemEnd: 423, scrollLeft: 0 }), 53);
});

test('a chip hidden on the left comes back to the start padding', () => {
  assert.equal(scrollerTarget({ ...chips, itemStart: 100, itemEnd: 244, scrollLeft: 150 }), 80);
});

test('a percentage end padding keeps a faded edge clear', () => {
  // Tablet nav row: 700px wide with the last 12% faded (84px).
  assert.equal(scrollerTarget({ viewWidth: 700, padStart: 12, padEnd: 84, maxScroll: 400, snap: false, itemStart: 560, itemEnd: 660, scrollLeft: 0 }), 44);
});

test('an item wider than the visible band aligns by its start', () => {
  assert.equal(scrollerTarget({ viewWidth: 100, padStart: 10, padEnd: 10, maxScroll: 500, snap: false, itemStart: 300, itemEnd: 450, scrollLeft: 0 }), 290);
});

// The tablet category row at 768px: 12px of scroll padding at the start and 12% (92.16px) at the end, because the
// row fades over its last 12%. Its last link spans 867.27…997.42 in the row's own scrolling coordinates.
const tabletRow = { viewWidth: 768, padStart: 12, padEnd: 92.16, snap: false };
const lastLink = { itemStart: 867.27, itemEnd: 997.42 };

test('scroll-padding alone cannot take the last link out of the fade: the clamp to the scrollable room wins', () => {
  // The row before the correction: 20px of end padding, 249px of room.
  const target = scrollerTarget({ ...tabletRow, ...lastLink, scrollLeft: 0, maxScroll: 249 });
  assert.equal(target, 249);
  assert.ok(lastLink.itemEnd - target > tabletRow.viewWidth - tabletRow.padEnd, 'the link still ends inside the fade');
});

test('with end padding as wide as the fade the last link scrolls out of it', () => {
  // The corrected row: 12% + 8px of end padding (100.16px), 330px of room.
  const target = scrollerTarget({ ...tabletRow, ...lastLink, scrollLeft: 0, maxScroll: 330 });
  assert.ok(Math.abs(target - 321.58) < 0.01, `target ${target}`);
  assert.ok(lastLink.itemEnd - target <= tabletRow.viewWidth - tabletRow.padEnd + 0.01, 'the link ends before the fade starts');
});

test('a link that already ends before the fade is left where it is', () => {
  assert.equal(scrollerTarget({ ...tabletRow, itemStart: 400, itemEnd: 530, scrollLeft: 0, maxScroll: 330 }), null);
  assert.equal(scrollerTarget({ ...tabletRow, ...lastLink, scrollLeft: 321.58, maxScroll: 330 }), null);
});
