// Merge the account implementation into a downloaded active theme, preserving
// that theme's current predictive search, navigation, branding and product UI.
// This builds a reviewable directory only; it does not upload or publish anything.
// node .../port-account-to-active-theme.mjs --base=/tmp/before --out=/tmp/merged
import { cp, mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../..');
const args = Object.fromEntries(process.argv.slice(2).map(arg => {
  const at = arg.indexOf('=');
  return [arg.slice(2, at), arg.slice(at + 1)];
}));
assert.ok(args.base && args.out, '--base and --out are required');
const base = path.resolve(args.base);
const out = path.resolve(args.out);
assert.notEqual(base, out);
assert.notEqual(out, path.join(root, 'storefront-theme'));
await mkdir(out, { recursive: true });
await cp(path.join(root, 'storefront-theme'), out, { recursive: true });
await cp(base, out, { recursive: true });

export const accountFiles = [
  'assets/monetta-account.css', 'assets/monetta-account.js',
  'sections/monetta-account.liquid',
  'snippets/monetta-account-link.liquid', 'snippets/monetta-account-icon.liquid',
  'snippets/monetta-account-menu.liquid', 'snippets/monetta-account-order.liquid',
  'snippets/monetta-account-dialogs.liquid',
  'templates/index.account.json', 'templates/index.orders.json',
];
for (const file of accountFiles) await cp(path.join(root, 'storefront-theme', file), path.join(out, file));

const replaceOnce = (source, before, after) => {
  assert.equal(source.split(before).length, 2, `Expected one anchor: ${before}`);
  return source.replace(before, after);
};
async function patch(file, edit) {
  const source = await readFile(path.join(base, file), 'utf8');
  await writeFile(path.join(out, file), edit(source));
}
await patch('sections/monetta-header.liquid', source => {
  let result = replaceOnce(source, '  assign search_hidden = false', '  assign search_hidden = false\n  assign is_account = false');
  result = replaceOnce(result, "  if template.name == 'search'\n    assign search_hidden = true\n  endif", "  if template.name == 'search'\n    assign search_hidden = true\n  endif\n  if template.suffix == 'account' or template.suffix == 'orders'\n    assign search_hidden = false\n    assign is_account = true\n  endif");
  result = result.replaceAll('{{ routes.account_url }}', "{% render 'monetta-account-link' %}")
    .replaceAll('{{ routes.account_login_url }}', "{% render 'monetta-account-link' %}");
  result = replaceOnce(result, 'aria-label="Cuenta">', 'aria-label="Cuenta"{% if is_account %} aria-current="page"{% endif %}>');
  return replaceOnce(result, "unless template.name == 'collection'", "unless template.name == 'collection' or is_account");
});
await patch('snippets/monetta-dock.liquid', source => replaceOnce(source,
  'href="{{ routes.account_url }}" data-dock="account">',
  'href="{% render \'monetta-account-link\' %}" data-dock="account"{% if dock_active == \'account\' %} aria-current="page"{% endif %}>'));
await patch('layout/monetta.liquid', source => {
  let result = replaceOnce(source, '  assign t = template.name', "  assign t = template.name\n  if template.suffix == 'account' or template.suffix == 'orders'\n    assign t = template.suffix\n  endif");
  result = replaceOnce(result, "    when 'cart'\n      assign dock_active = 'cart'", "    when 'cart'\n      assign dock_active = 'cart'\n    when 'account', 'orders'\n      assign dock_active = 'account'");
  return replaceOnce(result, '{% if has_page_bar %} has-page-bar{% endif %}"', '{% if has_page_bar %} has-page-bar{% endif %}{% if customer and dock_active == \'account\' %} has-account-sidebar{% endif %}"');
});
await patch('snippets/monetta-head.liquid', source => {
  let result = replaceOnce(source, '  assign t = template.name', "  assign t = template.name\n  if template.suffix == 'account' or template.suffix == 'orders'\n    assign t = template.suffix\n  endif");
  result = replaceOnce(result, '  endcase\n-%}', "  endcase\n  if template.suffix == 'account'\n    assign doc_title = 'Mi cuenta'\n  elsif template.suffix == 'orders'\n    assign doc_title = 'Mis pedidos'\n  endif\n-%}");
  return replaceOnce(result, '<meta name="theme-color" content="#fbf8f2">', '<meta name="theme-color" content="#fbf8f2">\n{%- if template.suffix == \'account\' or template.suffix == \'orders\' -%}\n  <meta name="robots" content="noindex, nofollow">\n{%- endif -%}');
});
await patch('sections/monetta-guia-home.liquid', source => replaceOnce(source, '{{ routes.account_url }}', "{% render 'monetta-account-link' %}"));
console.log(JSON.stringify({ out, uploadFiles: [...accountFiles, 'sections/monetta-header.liquid', 'snippets/monetta-dock.liquid', 'layout/monetta.liquid', 'snippets/monetta-head.liquid', 'sections/monetta-guia-home.liquid'] }, null, 2));
