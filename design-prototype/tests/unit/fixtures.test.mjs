// The demo catalog is consistent with its sources and its documented states.
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { test } from 'node:test';
import { parseDescription } from '../../scripts/build-fixtures.mjs';

const root = new URL('../../', import.meta.url);
const catalog = JSON.parse(readFileSync(new URL('src/data/catalog.json', root), 'utf8'));
const manifest = JSON.parse(readFileSync(new URL('fixtures/manifest.json', root), 'utf8'));

test('every product image exists locally and every image has a recorded source', () => {
  const sources = new Map(manifest.images.map((image) => [image.file, image.source]));
  for (const product of catalog.products) {
    assert.ok(product.images.length > 0, product.handle);
    for (const path of product.images) {
      const file = `public${path}`;
      assert.ok(existsSync(new URL(file, root)), `${file} missing`);
      assert.match(sources.get(file) ?? '', /^https:\/\/cdn\.shopify\.com\//, `${file} has no CDN source`);
    }
    for (const variant of product.variants) assert.ok(variant.image >= 0 && variant.image < product.images.length, `${product.handle} variant image`);
  }
});

test('default variants are buyable whenever any variant is', () => {
  for (const product of catalog.products) {
    const fallback = product.variants.find((variant) => variant.id === product.defaultVariantId);
    assert.ok(fallback, product.handle);
    if (product.variants.some((variant) => variant.available)) assert.equal(fallback.available, true, product.handle);
  }
});

test('collections reference catalog products only and keep their live counts', () => {
  const ids = new Set(catalog.products.map((product) => product.id));
  for (const collection of catalog.collections) {
    assert.ok(collection.productIds.every((id) => ids.has(id)), collection.handle);
    assert.ok(collection.liveCount >= collection.productIds.length, collection.handle);
  }
});

test('sale flags match genuine compare-at prices', () => {
  for (const product of catalog.products) {
    const genuine = product.variants.some((variant) => variant.compareAtPrice && Number(variant.compareAtPrice) > Number(variant.price));
    assert.equal(product.flags.onSale, genuine, product.handle);
  }
});

test('synthetic states are labelled in the data and in the manifest', () => {
  const synthetic = catalog.products.filter((product) => product.synthetic);
  assert.deepEqual(
    synthetic.map((product) => product.handle).sort(),
    manifest.synthetic.map((entry) => entry.handle).sort(),
  );
  const soldOut = synthetic.find((product) => product.synthetic.soldOut);
  assert.ok(soldOut.variants.every((variant) => !variant.available));
  assert.match(soldOut.synthetic.note, /demostración/);
});

test('real merchandising states exist in the snapshot', () => {
  assert.ok(catalog.products.some((product) => product.flags.sobrePedido), 'sobre pedido');
  assert.ok(catalog.products.some((product) => product.flags.envioInmediato), 'envío inmediato');
  assert.ok(catalog.products.some((product) => product.flags.onSale), 'sale');
  assert.ok(catalog.products.some((product) => product.variants.length > 1 && product.variants.some((variant) => !variant.available)), 'partly sold out');
});

test('descriptions split facts from copy and turn "sobre pedido" into a state', () => {
  const parsed = parseDescription(
    '<p>• 🏷️ Marca: Coach<br>• 👜 Tipo: Bolsa Shoulder<br>• 🔗 Incluye correa crossbody: No</p><p>📏 Medidas:<br>• Ancho: 5 cm<br>• Largo: 19 cm</p><p><em><strong>ESTE MODELO ES SOBRE PEDIDO, si deseas adquirirlo…</strong></em></p>',
  );
  assert.equal(parsed.sobrePedido, true);
  assert.deepEqual(parsed.paragraphs, []);
  assert.deepEqual(parsed.facts.find((fact) => fact.label === 'Marca'), { label: 'Marca', value: 'Coach' });
  assert.deepEqual(parsed.facts.find((fact) => fact.label === 'Medidas'), { label: 'Medidas', value: 'Ancho 5 cm × Largo 19 cm' });
  const copy = parseDescription('<p>Bolsa Juicy Couture en color rosa.</p><ul><li>Color: Rosa</li></ul>');
  assert.deepEqual(copy.paragraphs, ['Bolsa Juicy Couture en color rosa.']);
  assert.equal(copy.sobrePedido, false);
});
