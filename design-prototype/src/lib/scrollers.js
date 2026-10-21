// Keyboard focus inside horizontal scrollers: product rails, chip rows, gallery thumbnails
// and the tablet category row. The browser leaves a focused item half outside its scroller
// (a rail with mandatory snapping even pulls itself back), so the focus ring and the item
// stay clipped at the screen edge. The item brings itself into view instead.

/**
 * The scroll offset that brings a focused item fully into the scrollport, or null when it
 * already is. [snap] means the scroller snaps to item starts, where only the item's own snap
 * position is stable; otherwise the item moves the least that clears the padded edges.
 * Offsets are in the scroller's own scrolling coordinates.
 *
 * The target is clamped to [maxScroll]: scroll-padding frames the item but adds no scrollable
 * room, so a last item that must clear a fade or a bar needs real end padding in the CSS (the
 * tablet category row has it). Without it the clamp wins and the item stays under the fade.
 */
export function scrollerTarget({ itemStart, itemEnd, scrollLeft, viewWidth, padStart, padEnd, maxScroll, snap = false }) {
  const visibleStart = scrollLeft + padStart;
  const visibleEnd = scrollLeft + viewWidth - padEnd;
  if (itemStart >= visibleStart - 0.5 && itemEnd <= visibleEnd + 0.5) return null;
  const clamp = (value) => Math.min(Math.max(value, 0), Math.max(maxScroll, 0));
  if (snap || itemEnd - itemStart > visibleEnd - visibleStart) return clamp(itemStart - padStart);
  return clamp(itemStart < visibleStart ? itemStart - padStart : itemEnd + padEnd - viewWidth);
}

function horizontalScroller(element) {
  for (let node = element.parentElement; node && node !== document.body; node = node.parentElement) {
    const { overflowX } = getComputedStyle(node);
    if ((overflowX === 'auto' || overflowX === 'scroll') && node.scrollWidth > node.clientWidth + 1) return node;
  }
  return null;
}

/** scroll-padding computes to a length or, when written as a percentage, stays one. */
function paddingPx(value, basis) {
  const number = Number.parseFloat(value);
  if (Number.isNaN(number)) return 0;
  return value.endsWith('%') ? (basis * number) / 100 : number;
}

/** `focusin` handler: keyboard focus brings its item into view. Pointer focus never moves a scroller. */
export function revealFocusedScrollerItem(event) {
  const target = event.target;
  if (!(target instanceof Element) || !target.matches(':focus-visible')) return;
  const scroller = horizontalScroller(target);
  if (!scroller) return;
  // The unit that moves is the scroller's own child holding the focus: a card, a chip, a thumbnail.
  let item = target;
  while (item.parentElement !== scroller) item = item.parentElement;
  const box = scroller.getBoundingClientRect();
  const rect = item.getBoundingClientRect();
  const style = getComputedStyle(scroller);
  const origin = box.left + scroller.clientLeft - scroller.scrollLeft;
  const next = scrollerTarget({
    itemStart: rect.left - origin,
    itemEnd: rect.right - origin,
    scrollLeft: scroller.scrollLeft,
    viewWidth: scroller.clientWidth,
    padStart: paddingPx(style.scrollPaddingLeft, scroller.clientWidth),
    padEnd: paddingPx(style.scrollPaddingRight, scroller.clientWidth),
    maxScroll: scroller.scrollWidth - scroller.clientWidth,
    snap: style.scrollSnapType !== 'none',
  });
  if (next !== null) scroller.scrollTo({ left: next, behavior: 'auto' });
}
