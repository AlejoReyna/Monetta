import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '..');
const outDir = path.join(root, 'docs', 'figma-current-ui');
fs.mkdirSync(outDir, { recursive: true });

const C = {
  ink: '#111111', muted: '#737373', gold: '#AA7D44', mist: '#F5F5F5',
  search: '#F1F1F1', sale: '#A3342B', line: '#DCDCDC', white: '#FFFFFF',
  success: '#5C7E08', coral: '#B95C43', olive: '#655F3B', paper: '#F3EFE9',
};

const asset = (name, mime) => {
  const bytes = fs.readFileSync(path.join(root, 'assets/images', name));
  return `data:${mime};base64,${bytes.toString('base64')}`;
};

const assets = {
  logo: asset('logo_monetta.png', 'image/png'),
  hero: asset('hero_poster.jpg', 'image/jpeg'),
  coral: asset('campaign_coral.jpg', 'image/jpeg'),
  olive: asset('campaign_olive.jpg', 'image/jpeg'),
  terra: asset('campaign_terracotta.jpg', 'image/jpeg'),
};

const esc = (v) => String(v)
  .replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;')
  .replaceAll('"', '&quot;').replaceAll("'", '&apos;');

const t = (x, y, value, size = 13, weight = 400, fill = C.ink, extra = '') =>
  `<text x="${x}" y="${y}" font-family="Inter, Arial, sans-serif" font-size="${size}" font-weight="${weight}" fill="${fill}" ${extra}>${esc(value)}</text>`;
const line = (x1, y1, x2, y2, stroke = C.line, width = 1) =>
  `<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="${stroke}" stroke-width="${width}"/>`;
const rect = (x, y, w, h, fill = 'none', stroke = 'none', radius = 0, extra = '') =>
  `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="${fill}" stroke="${stroke}" rx="${radius}" ${extra}/>`;
const circle = (cx, cy, r, fill = 'none', stroke = C.ink, width = 1.5) =>
  `<circle cx="${cx}" cy="${cy}" r="${r}" fill="${fill}" stroke="${stroke}" stroke-width="${width}"/>`;
const useImg = (id, x, y, w, h, fit = 'xMidYMid slice', opacity = 1) =>
  `<svg x="${x}" y="${y}" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}" preserveAspectRatio="none" overflow="hidden"><use href="#${id}" width="${w}" height="${h}" preserveAspectRatio="${fit}" opacity="${opacity}"/></svg>`;

function defs() {
  return `<defs>
    <filter id="shadow" x="-30%" y="-30%" width="160%" height="160%"><feDropShadow dx="0" dy="8" stdDeviation="16" flood-color="#111111" flood-opacity="0.14"/></filter>
    <filter id="ctaShadow" x="-30%" y="-30%" width="160%" height="160%"><feDropShadow dx="0" dy="0" stdDeviation="5" flood-color="#000000" flood-opacity="0.4"/></filter>
    <symbol id="logo" viewBox="0 0 132 38"><image href="${assets.logo}" width="132" height="38"/></symbol>
    <symbol id="hero" viewBox="0 0 1280 720"><image href="${assets.hero}" width="1280" height="720"/></symbol>
    <symbol id="coral" viewBox="0 0 1122 1402"><image href="${assets.coral}" width="1122" height="1402"/></symbol>
    <symbol id="olive" viewBox="0 0 1122 1402"><image href="${assets.olive}" width="1122" height="1402"/></symbol>
    <symbol id="terra" viewBox="0 0 1122 1402"><image href="${assets.terra}" width="1122" height="1402"/></symbol>
  </defs>`;
}

function icon(kind, x, y, color = C.ink) {
  if (kind === 'search') return `<g transform="translate(${x} ${y})" stroke="${color}" stroke-width="1.8" fill="none"><circle cx="8" cy="8" r="5.5"/><line x1="12" y1="12" x2="17" y2="17"/></g>`;
  if (kind === 'user') return `<g transform="translate(${x} ${y})" stroke="${color}" stroke-width="1.6" fill="none"><circle cx="9" cy="6" r="3.5"/><path d="M2 18c.8-5 3.1-7 7-7s6.2 2 7 7"/></g>`;
  if (kind === 'bag') return `<g transform="translate(${x} ${y})" stroke="${color}" stroke-width="1.6" fill="none"><rect x="2" y="6" width="15" height="13"/><path d="M6 7V5a3.5 3.5 0 0 1 7 0v2"/></g>`;
  if (kind === 'menu') return `<g transform="translate(${x} ${y})" stroke="${color}" stroke-width="1.8"><line x1="1" y1="4" x2="18" y2="4"/><line x1="1" y1="10" x2="18" y2="10"/><line x1="1" y1="16" x2="18" y2="16"/></g>`;
  if (kind === 'back') return `<g transform="translate(${x} ${y})" stroke="${color}" stroke-width="1.8" fill="none"><path d="M16 2L4 10l12 8"/><line x1="4" y1="10" x2="20" y2="10"/></g>`;
  if (kind === 'check') return `<path d="M${x} ${y + 6}l5 5 10-12" stroke="${color}" stroke-width="2" fill="none"/>`;
  return '';
}

function statusBar(w = 390, dark = false) {
  const color = dark ? C.white : C.ink;
  return `${rect(0, 0, w, 24, dark ? C.ink : C.white)}${t(18, 17, '9:41', 11, 600, color)}${t(w - 62, 17, '●  ◒  ▰', 9, 600, color)}`;
}

function appHeader({ w = 390, title = '', back = false, actions = true, announcement = false } = {}) {
  let s = `${statusBar(w)}${rect(0, 24, w, 62, C.white)}${line(0, 86, w, 86)}`;
  if (back) s += icon('back', 18, 46);
  if (title) s += t(back ? 54 : 20, 64, title, 16, 500);
  else s += `<use href="#logo" x="18" y="42" width="104" height="30"/>`;
  if (actions) {
    s += icon('search', w - 104, 46) + icon('user', w - 76, 45) + icon('bag', w - 48, 44) + icon('menu', w - 23, 45);
  }
  if (announcement) s += `${rect(0, 86, w, 31, C.ink)}${t(w / 2, 106, 'ENVÍO GRATIS DESDE $1,499', 9.5, 700, C.white, 'text-anchor="middle" letter-spacing="1.35"')}`;
  return s;
}

function button(x, y, w, label, { dark = true, h = 48, disabled = false, gold = false } = {}) {
  const bg = disabled ? '#C9C9C9' : gold ? C.gold : dark ? C.ink : C.white;
  const fg = dark || gold || disabled ? C.white : C.ink;
  const stroke = dark || gold || disabled ? bg : C.ink;
  return `${rect(x, y, w, h, bg, stroke)}${t(x + w / 2, y + h / 2 + 4, label, 11, 700, fg, 'text-anchor="middle" letter-spacing="1.2"')}`;
}

function field(x, y, w, label, value = '', h = 52) {
  return `${rect(x, y, w, h, C.white, C.line)}${t(x + 12, y + 15, label.toUpperCase(), 8, 600, C.muted, 'letter-spacing="1"')}${value ? t(x + 12, y + 37, value, 12.5, 400) : ''}`;
}

function chip(x, y, label, active = false, w = 72) {
  return `${rect(x, y, w, 30, active ? C.ink : C.white, active ? C.ink : C.line, 15)}${t(x + w / 2, y + 19, label, 9.5, 600, active ? C.white : C.ink, 'text-anchor="middle"')}`;
}

function productCard(x, y, w, imgId, brand, title, price, sold = false, sale = '') {
  const imgH = w * 1.18;
  let s = `${useImg(imgId, x, y, w, imgH)}${t(x, y + imgH + 17, brand.toUpperCase(), 8.5, 700, C.muted, 'letter-spacing="1.2"')}`;
  s += t(x, y + imgH + 36, title, 11.5, 400);
  s += t(x, y + imgH + 54, price, 12.5, 600, sold ? C.muted : C.ink);
  if (sale) s += t(x + w - 4, y + imgH + 54, sale, 9, 600, C.sale, 'text-anchor="end"');
  if (sold) s += `${rect(x, y + imgH / 2 - 15, w, 30, C.white, 'none', 0, 'opacity="0.9"')}${t(x + w / 2, y + imgH / 2 + 4, 'AGOTADO', 9, 700, C.ink, 'text-anchor="middle" letter-spacing="1.4"')}`;
  return s;
}

function phone(x, y, name, content, { w = 390, h = 844 } = {}) {
  const id = `clip-${name.toLowerCase().replace(/[^a-z0-9]+/g, '-')}`;
  return `<g id="${esc(name)}" transform="translate(${x} ${y})">
    ${t(0, -22, name, 14, 700, C.ink, 'letter-spacing="0.3"')}
    <defs><clipPath id="${id}"><rect width="${w}" height="${h}"/></clipPath></defs>
    ${rect(0, 0, w, h, C.white, '#CFCFCF', 22, 'filter="url(#shadow)"')}
    <g clip-path="url(#${id})">${content}</g>
  </g>`;
}

function homeScreen() {
  let s = appHeader({ announcement: true });
  s += useImg('terra', 0, 117, 390, 232);
  s += `${rect(120, 284, 150, 42, C.ink, C.white, 0, 'filter="url(#ctaShadow)"')}${t(195, 310, 'VER CATÁLOGOS', 10, 700, C.white, 'text-anchor="middle" letter-spacing="1.4"')}`;
  s += t(18, 389, 'Novedades', 24, 400);
  s += productCard(18, 414, 171, 'coral', 'Steve Madden', 'Bolsa Tote Crossbody', '$1,589', false, '-9%');
  s += productCard(201, 414, 171, 'olive', 'Guess', 'Bolsa Hobo Oliva', '$1,449');
  return s;
}

function splashScreen(error = false) {
  let s = statusBar();
  s += `<use href="#logo" x="109" y="360" width="172" height="50"/>`;
  s += error ? `${t(195, 452, 'No pudimos cargar la tienda', 16, 500, C.ink, 'text-anchor="middle"')}${t(195, 478, 'Revisa tu conexión e intenta de nuevo.', 12, 400, C.muted, 'text-anchor="middle"')}${button(105, 510, 180, 'REINTENTAR')}` : `${circle(195, 446, 12, 'none', C.gold, 2)}${t(195, 487, 'Preparando la colección', 10, 600, C.muted, 'text-anchor="middle" letter-spacing="1.2"')}`;
  return s;
}

function drawerScreen() {
  let s = homeScreen();
  s += rect(0, 0, 390, 844, '#000000', 'none', 0, 'opacity="0.34"');
  s += rect(0, 0, 312, 844, C.white);
  s += `<use href="#logo" x="24" y="54" width="126" height="36"/>${t(274, 73, '×', 25, 300)}`;
  const links = ['Inicio', 'Bolsas', 'Carteras', 'Relojes', 'Ver todo', 'Elige marcas', 'Mi cuenta', 'WhatsApp', 'Mayoreo'];
  links.forEach((v, i) => { s += t(24, 145 + i * 52, v, i < 5 ? 18 : 14, i === 0 ? 600 : 400); s += line(24, 162 + i * 52, 288, 162 + i * 52); });
  s += t(24, 790, 'MONETTA · MÉXICO', 8.5, 700, C.muted, 'letter-spacing="1.5"');
  return s;
}

function searchScreen() {
  let s = appHeader({ title: 'Buscar', back: true, actions: false });
  s += `${rect(18, 106, 354, 46, C.search)}${icon('search', 32, 119, C.muted)}${t(62, 134, 'Buscar bolsas, marcas o estilos', 12.5, 400, C.muted)}${t(350, 135, '×', 17, 400, C.muted)}`;
  s += t(18, 191, 'RESULTADOS', 9, 700, C.muted, 'letter-spacing="1.5"');
  s += productCard(18, 216, 171, 'coral', 'Steve Madden', 'Bolsa Tote Crossbody', '$1,589');
  s += productCard(201, 216, 171, 'terra', 'Guess', 'Bolsa Crossbody Café', '$1,499', true);
  return s;
}

function onboarding(selected = false) {
  let s = statusBar();
  s += t(24, 75, 'Personaliza tu experiencia', 26, 400);
  s += t(24, 104, 'Elige lo que quieres descubrir primero.', 12.5, 400, C.muted);
  s += line(24, 126, 366, 126);
  s += t(24, 160, 'CATEGORÍAS', 9, 700, C.muted, 'letter-spacing="1.7"');
  ['Bolsas', 'Carteras', 'Relojes'].forEach((v, i) => {
    const active = selected && i < 2;
    s += circle(344, 205 + i * 58, 10, active ? C.ink : C.white, active ? C.ink : C.line, 1.5);
    if (active) s += icon('check', 338, 199 + i * 58, C.white);
    s += t(24, 211 + i * 58, v, 18, 400) + line(24, 229 + i * 58, 366, 229 + i * 58);
  });
  s += t(24, 386, 'MARCAS', 9, 700, C.muted, 'letter-spacing="1.7"');
  ['Coach', 'Guess', 'Steve Madden', 'Michael Kors'].forEach((v, i) => { const a = selected && (i === 1 || i === 2); s += chip(24 + (i % 2) * 174, 408 + Math.floor(i / 2) * 44, v, a, 158); });
  s += selected ? button(24, 748, 342, 'CONTINUAR') : button(24, 748, 342, 'ELIGE AL MENOS UNA OPCIÓN', { disabled: true });
  s += t(195, 822, 'Omitir por ahora', 11, 500, C.ink, 'text-anchor="middle" text-decoration="underline"');
  return s;
}

function collectionScreen(filtered = false, empty = false) {
  let s = appHeader({ title: filtered ? 'Bolsas' : 'El catálogo', back: true, actions: false });
  s += chip(18, 108, filtered ? 'En stock' : 'Todo', filtered, 68);
  s += chip(94, 108, filtered ? 'Guess' : 'Marca', filtered, 76);
  s += chip(178, 108, filtered ? 'Crossbody' : 'Forma', filtered, 88);
  s += chip(274, 108, filtered ? 'Precio ↑' : 'Recientes', false, 98);
  s += t(18, 169, empty ? '0 ARTÍCULOS' : filtered ? '3 ARTÍCULOS' : '24 ARTÍCULOS', 8.5, 700, C.muted, 'letter-spacing="1.35"');
  if (empty) {
    s += t(195, 390, 'Sin resultados', 18, 500, C.ink, 'text-anchor="middle"');
    s += t(195, 420, 'Prueba quitando algún filtro.', 12.5, 400, C.muted, 'text-anchor="middle"');
    s += button(105, 456, 180, 'LIMPIAR FILTROS', { dark: false });
  } else {
    s += productCard(18, 190, 171, filtered ? 'terra' : 'coral', filtered ? 'Guess' : 'Steve Madden', filtered ? 'Bolsa Crossbody Café' : 'Bolsa Tote Crossbody', filtered ? '$1,499' : '$1,589');
    s += productCard(201, 190, 171, 'olive', 'Guess', 'Bolsa Hobo Oliva', '$1,449', filtered);
  }
  return s;
}

function browseScreen() {
  let s = appHeader({ title: 'Productos', back: true, actions: true });
  s += `${rect(0, 86, 390, 60, C.ink)}`;
  s += chip(16, 101, 'Colección', true, 80);
  s += chip(104, 101, 'Monetta', false, 76);
  s += chip(188, 101, 'Bolsas', false, 68);
  s += chip(264, 101, 'Perfumes', false, 80);
  
  s += t(18, 180, 'MONETTA', 10, 700, C.muted, 'letter-spacing="1.4"');
  s += t(18, 205, 'Selección Monetta', 24, 400);
  
  [['coral','Bolsa Steve Madden Tote','$1,589'], ['olive','Bolsa Guess Hobo','$1,449']].forEach((v,i)=>{
    const y=230+i*142; s += useImg(v[0],18,y,102,126)+t(136,y+20,'MONETTA',8.5,700,C.muted,'letter-spacing="1.2"')+t(136,y+46,v[1],13,500)+t(136,y+72,v[2],12.5,600)+t(354,y+72,'›',22,300,C.muted);
  });
  s += line(18, 525, 372, 525)+t(18, 566, 'TAMBIÉN EN MARCAS DE ESTADOS UNIDOS', 9.5, 700, C.muted, 'letter-spacing="1.1"');
  s += useImg('terra',18,590,102,126)+t(136,610,'COACH · USD',8.5,700,C.muted,'letter-spacing="1.1"')+t(136,638,'Tabby Shoulder Bag',13,500)+t(136,666,'$395 USD',12.5,600)+t(136,695,'VER EN COACH',9.5,700,C.gold,'letter-spacing="1.2"');
  return s;
}

function productScreen({ sold = false, external = false } = {}) {
  let s = appHeader({ back: true, actions: true });
  s += useImg(external ? 'terra' : sold ? 'olive' : 'coral', 0, 86, 390, 390);
  s += t(20, 510, external ? 'COACH' : sold ? 'GUESS' : 'STEVE MADDEN', 9, 700, C.muted, 'letter-spacing="1.5"');
  s += t(20, 543, external ? 'Tabby Shoulder Bag' : sold ? 'Bolsa Hobo Oliva' : 'Bolsa Tote Crossbody', 24, 400);
  s += t(20, 578, external ? '$395 USD' : sold ? '$1,449' : '$1,589', 17, 600, sold ? C.muted : C.ink);
  if (!external && !sold) s += `${t(92,578,'$1,749',12,400,C.muted,'text-decoration="line-through"')}${rect(150,559,38,23,C.sale)}${t(169,575,'-9%',9,700,C.white,'text-anchor="middle"')}`;
  if (external) s += `${t(20, 613, 'DISPONIBLE EN SITIO EXTERNO', 8.5, 700, C.success, 'letter-spacing="1.2"')}${t(20, 650, 'COLOR', 9, 700, C.muted, 'letter-spacing="1.5"')}${chip(20,667,'Café',true,66)}${chip(94,667,'Negro',false,66)}${button(20,756,350,'VER EN COACH',{gold:true})}`;
  else s += `${t(20, 621, 'OPCIÓN', 9, 700, C.muted, 'letter-spacing="1.5"')}${chip(20,638,'Única',true,70)}${line(20,700,370,700)}${t(20,730,'DETALLES',9,700,C.ink,'letter-spacing="1.4"')}${t(350,730,'+',18,400)}${button(20,768,350,sold?'AGOTADO':'AGREGAR A LA BOLSA',{disabled:sold})}`;
  return s;
}

function miniCartScreen() {
  let s = homeScreen();
  s += rect(0, 0, 390, 844, '#000000', 'none', 0, 'opacity="0.32"');
  s += rect(0, 390, 390, 454, C.white);
  s += t(20, 430, 'En tu bolsa', 24, 400) + t(366, 430, '×', 22, 300, C.muted, 'text-anchor="end"');
  s += t(20, 455, '1 artículo', 11.5, 400, C.muted);
  s += useImg('coral', 20, 488, 92, 116) + t(130, 505, 'STEVE MADDEN', 8.5, 700, C.muted, 'letter-spacing="1.2"') + t(130, 533, 'Bolsa Tote Crossbody', 13, 500) + t(130, 560, '$1,589', 12.5, 600);
  s += line(20, 633, 370, 633) + t(20, 662, 'Subtotal', 12.5, 400) + t(370, 662, '$1,589', 13, 600, C.ink, 'text-anchor="end"');
  s += button(20, 692, 350, 'VER BOLSA') + t(195, 777, 'Seguir viendo', 11, 500, C.ink, 'text-anchor="middle" text-decoration="underline"');
  return s;
}

function summaryBox(y, cta = 'CONTINUAR') {
  return `${rect(18,y,354,188,C.mist)}${t(36,y+35,'Resumen',22,400)}${t(36,y+67,'Subtotal',12,400,C.muted)}${t(354,y+67,'$1,589',12.5,600,C.ink,'text-anchor="end"')}${t(36,y+94,'Envío estándar',12,400,C.muted)}${t(354,y+94,'Gratis',12.5,600,C.success,'text-anchor="end"')}${line(36,y+112,354,y+112)}${t(36,y+140,'Total estimado',13,600)}${t(354,y+140,'$1,589 MXN',14,700,C.ink,'text-anchor="end"')}${button(36,y+151,318,cta,{h:44})}`;
}

function bagScreen(empty = false) {
  let s = appHeader({ back: true, actions: false });
  if (empty) {
    s += t(195, 350, 'Tu bolsa está vacía', 26, 400, C.ink, 'text-anchor="middle"');
    s += t(195, 384, 'Explora las piezas disponibles.', 12.5, 400, C.muted, 'text-anchor="middle"');
    s += button(95, 428, 200, 'VOLVER A LA TIENDA');
  } else {
    s += t(18, 132, 'Tu bolsa', 30, 400) + t(18, 157, '1 artículo', 11.5, 400, C.muted);
    s += useImg('coral', 18, 188, 112, 140) + t(148, 207, 'STEVE MADDEN', 8.5, 700, C.muted, 'letter-spacing="1.2"') + t(148, 236, 'Bolsa Tote Crossbody', 13, 500) + t(148, 264, '$1,589', 13, 600);
    s += `${rect(148,286,104,34,C.white,C.line)}${t(166,308,'−',16,400)}${t(200,308,'1',12,600,'#111','text-anchor="middle"')}${t(235,308,'+',16,400)}${t(360,309,'Eliminar',9.5,500,C.ink,'text-anchor="end" text-decoration="underline"')}`;
    s += summaryBox(380, 'CONTINUAR AL ENVÍO');
  }
  return s;
}

function progress(active = 1) {
  const labels = ['Bolsa','Entrega','Pago'];
  let s = line(55,127,335,127,C.line,2);
  labels.forEach((v,i)=>{ const x=55+i*140; s += circle(x,127,13,i<=active?C.ink:C.white,i<=active?C.ink:C.line,1.5)+t(x,131,String(i+1),9,700,i<=active?C.white:C.muted,'text-anchor="middle"')+t(x,154,v,8.5,600,i===active?C.ink:C.muted,'text-anchor="middle" letter-spacing="0.7"'); });
  return s;
}

function deliveryScreen() {
  let s = appHeader({ back: true, actions: false }) + progress(1);
  s += t(18, 211, '¿Dónde lo enviamos?', 30, 400) + t(18, 238, 'Usaremos estos datos para tu entrega.', 12.5, 400, C.muted);
  s += t(18, 278, 'CONTACTO', 9, 700, C.muted, 'letter-spacing="1.5"');
  s += field(18,292,354,'Correo electrónico','alexis@ejemplo.com') + field(18,352,354,'Teléfono','81 1234 5678');
  s += t(18, 437, 'DIRECCIÓN DE ENTREGA', 9, 700, C.muted, 'letter-spacing="1.5"');
  s += field(18,451,354,'Nombre completo','Alexis Martínez') + field(18,511,354,'Calle y número','Av. Constitución 100') + field(18,571,354,'Colonia','Centro');
  s += field(18,631,169,'Código postal','64000') + field(203,631,169,'Ciudad','Monterrey');
  s += field(18,691,354,'Estado','Nuevo León') + button(18,765,354,'REVISAR PEDIDO');
  return s;
}

function reviewScreen() {
  let s = appHeader({ back: true, actions: false }) + progress(2);
  s += t(18, 211, 'Todo listo', 30, 400) + t(18, 239, 'Revisa tu información antes de pagar.', 12.5, 400, C.muted);
  const rows=[['CONTACTO','alexis@ejemplo.com'],['ENTREGA','Av. Constitución 100, Monterrey'],['MÉTODO','Envío estándar · Gratis']];
  rows.forEach((r,i)=>{ const y=283+i*66; s+=t(18,y,r[0],8.5,700,C.muted,'letter-spacing="1.3"')+t(112,y,r[1],11.5,400)+t(370,y,'Editar',9.5,500,C.ink,'text-anchor="end" text-decoration="underline"')+line(18,y+22,372,y+22); });
  s += summaryBox(500,'CONTINUAR AL PAGO SEGURO');
  s += t(195, 818, 'Serás dirigido a un pago protegido.', 9.5, 400, C.muted, 'text-anchor="middle"');
  return s;
}

function secureScreen() {
  let s = appHeader({ back: true, actions: false });
  s += `${circle(195,286,44,C.mist,'none')}${t(195,299,'✓',34,500,C.success,'text-anchor="middle"')}`;
  s += t(195, 372, 'Pago protegido', 25, 400, C.ink, 'text-anchor="middle"');
  s += t(195, 405, 'Continuarás en una ventana segura para', 12.5, 400, C.muted, 'text-anchor="middle"');
  s += t(195, 425, 'completar tu compra.', 12.5, 400, C.muted, 'text-anchor="middle"');
  s += button(95, 477, 200, 'ENTENDIDO');
  return s;
}

function accountScreen(mode = 'login') {
  let s = appHeader({ title: 'Mi cuenta', back: true, actions: false });
  if (mode === 'signed') {
    s += t(18, 138, 'Sesión iniciada', 20, 400)+t(18,164,'alexis@ejemplo.com',12.5,400,C.muted)+button(18,190,170,'CERRAR SESIÓN',{dark:false});
    s += t(18, 284, 'MIS PEDIDOS', 9, 700, C.muted, 'letter-spacing="1.5"');
    [['#MON-1048','12 ago 2026','$1,589'],['#MON-0992','21 jul 2026','$2,178']].forEach((r,i)=>{const y=310+i*84;s+=t(18,y,r[0],11.5,600)+t(18,y+24,r[1],10.5,400,C.muted)+t(370,y+12,r[2],13,600,C.ink,'text-anchor="end"')+line(18,y+47,372,y+47);});
    return s;
  }
  s += t(18, 142, mode === 'register' ? 'Crea tu cuenta' : 'Qué gusto verte', 26, 400);
  s += t(18, 171, mode === 'register' ? 'Guarda tus datos y consulta tus pedidos.' : 'Entra para consultar tus pedidos.', 12.5, 400, C.muted);
  s += `${rect(18,210,354,42,C.mist)}${rect(mode==='register'?195:18,210,177,42,C.ink)}${t(106,236,'INICIAR SESIÓN',9.5,700,mode==='login'?C.white:C.ink,'text-anchor="middle" letter-spacing="0.9"')}${t(283,236,'REGISTRARME',9.5,700,mode==='register'?C.white:C.ink,'text-anchor="middle" letter-spacing="0.9"')}`;
  let y=282;
  if (mode==='register') { s += field(18,y,354,'Nombre','Alexis'); y+=62; }
  s += field(18,y,354,'Correo electrónico','alexis@ejemplo.com'); y+=62;
  s += field(18,y,354,'Contraseña','••••••••'); y+=78;
  s += button(18,y,354,mode==='register'?'CREAR CUENTA':'ENTRAR');
  s += t(195,y+78,mode==='register'?'Al crear una cuenta aceptas los términos.':'¿Olvidaste tu contraseña?',10.5,400,C.muted,'text-anchor="middle"');
  return s;
}

function wideHome(w = 1000, h = 720) {
  let s = appHeader({ w, announcement: true });
  s += useImg('terra', 0, 117, w, 300);
  s += `${rect(w/2-80,350,160,44,C.ink,C.white)}${t(w/2,377,'VER CATÁLOGOS',10,700,C.white,'text-anchor="middle" letter-spacing="1.3"')}`;
  s += t(34, 466, 'Novedades', 30, 400);
  const cardW=(w-34*2-24*3)/4;
  [['coral','Steve Madden','Tote Crossbody','$1,589'],['olive','Guess','Hobo Oliva','$1,449'],['terra','Guess','Crossbody Café','$1,499'],['coral','Coach','Top Handle','$395 USD']].forEach((v,i)=>{s+=productCard(34+i*(cardW+24),495,cardW,v[0],v[1],v[2],v[3],i===2);});
  return s;
}

function wideCheckout(w = 1000, h = 720) {
  let s = appHeader({ w, back: true, actions: false });
  s += t(46, 150, 'Entrega', 34, 400) + t(46, 182, 'Completa tus datos de contacto y entrega.', 13, 400, C.muted);
  s += t(46, 226, 'CONTACTO', 9, 700, C.muted, 'letter-spacing="1.4"') + field(46,240,430,'Correo electrónico','alexis@ejemplo.com') + field(46,302,430,'Teléfono','81 1234 5678');
  s += t(46, 396, 'DIRECCIÓN DE ENTREGA', 9, 700, C.muted, 'letter-spacing="1.4"') + field(46,410,430,'Nombre completo','Alexis Martínez') + field(46,472,430,'Calle y número','Av. Constitución 100') + field(46,534,205,'Código postal','64000') + field(271,534,205,'Ciudad','Monterrey');
  s += `${rect(550,150,404,480,C.mist)}${t(582,195,'Resumen',24,400)}${useImg('coral',582,226,92,116)}${t(694,244,'STEVE MADDEN',8.5,700,C.muted,'letter-spacing="1.1"')}${t(694,272,'Bolsa Tote Crossbody',13,500)}${t(922,308,'$1,589',13,600,C.ink,'text-anchor="end"')}${line(582,370,922,370)}${t(582,405,'Subtotal',12.5,400,C.muted)}${t(922,405,'$1,589',13,600,C.ink,'text-anchor="end"')}${t(582,438,'Envío',12.5,400,C.muted)}${t(922,438,'Gratis',13,600,C.success,'text-anchor="end"')}${line(582,468,922,468)}${t(582,505,'Total',14,600)}${t(922,505,'$1,589 MXN',15,700,C.ink,'text-anchor="end"')}${button(582,548,340,'REVISAR PEDIDO')}`;
  return s;
}

function sheetHeader(title, subtitle, width) {
  return `${rect(0,0,width,2050,C.paper)}${t(80,82,'MONETTA · UI ACTUAL',11,700,C.gold,'letter-spacing="2"')}${t(80,128,title,36,400)}${t(80,159,subtitle,13,400,C.muted)}${line(80,184,width-80,184,'#D8D0C5')}`;
}

function makeSheet(name, title, subtitle, screens, options = {}) {
  const width = options.width ?? 1944;
  const height = options.height ?? 2100;
  let body = `${rect(0,0,width,height,C.paper)}${t(80,82,'MONETTA · UI ACTUAL',11,700,C.gold,'letter-spacing="2"')}${t(80,128,title,36,400)}${t(80,159,subtitle,13,400,C.muted)}${line(80,184,width-80,184,'#D8D0C5')}`;
  for (const item of screens) body += phone(item.x, item.y, item.name, item.content, item.size ?? {});
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">${defs()}<g id="${esc(name)}">${body}</g></svg>`;
  const target = path.join(outDir, `${name}.svg`);
  fs.writeFileSync(target, svg);
  return target;
}

const grid = [
  [80,250],[534,250],[988,250],[1442,250],
  [80,1160],[534,1160],[988,1160],[1442,1160],
];

const storefront = [
  ['01 · Splash', splashScreen(false)],
  ['02 · Home', homeScreen()],
  ['03 · Menú lateral', drawerScreen()],
  ['04 · Búsqueda', searchScreen()],
  ['05 · Onboarding vacío', onboarding(false)],
  ['06 · Onboarding seleccionado', onboarding(true)],
  ['07 · Colección', collectionScreen(false,false)],
  ['08 · Colección filtrada', collectionScreen(true,false)],
].map((v,i)=>({x:grid[i][0],y:grid[i][1],name:v[0],content:v[1]}));

const commerce = [
  ['09 · Colección vacía', collectionScreen(true,true)],
  ['10 · Todo el catálogo', browseScreen()],
  ['11 · Producto Monetta', productScreen()],
  ['12 · Producto agotado', productScreen({sold:true})],
  ['13 · Producto externo', productScreen({external:true})],
  ['14 · Mini bolsa', miniCartScreen()],
  ['15 · Bolsa completa', bagScreen(false)],
  ['16 · Bolsa vacía', bagScreen(true)],
].map((v,i)=>({x:grid[i][0],y:grid[i][1],name:v[0],content:v[1]}));

function checkoutProductsScreen() {
  let s = appHeader({ back: true, actions: false }) + progress(2);
  s += t(18, 211, 'Productos seleccionados', 30, 400) + t(18, 239, 'Revisa los artículos de tu compra.', 12.5, 400, C.muted);
  s += useImg('coral', 18, 280, 112, 140) + t(148, 299, 'STEVE MADDEN', 8.5, 700, C.muted, 'letter-spacing="1.2"') + t(148, 328, 'Bolsa Tote Crossbody', 13, 500) + t(148, 356, '$1,589', 13, 600);
  s += useImg('olive', 18, 440, 112, 140) + t(148, 459, 'GUESS', 8.5, 700, C.muted, 'letter-spacing="1.2"') + t(148, 488, 'Bolsa Hobo Oliva', 13, 500) + t(148, 516, '$1,449', 13, 600);
  s += summaryBox(620,'CONTINUAR AL PAGO SEGURO');
  return s;
}

function checkoutSuccessScreen() {
  let s = statusBar();
  s += `<use href="#logo" x="18" y="42" width="104" height="30"/>`;
  s += `${circle(195,300,44,C.mist,'none')}${t(195,313,'✓',34,500,C.success,'text-anchor="middle"')}`;
  s += t(195, 386, '¡Compra exitosa!', 25, 400, C.ink, 'text-anchor="middle"');
  s += t(195, 419, 'Tu pedido #MON-1284 ha sido confirmado.', 12.5, 400, C.muted, 'text-anchor="middle"');
  s += t(195, 439, 'Enviamos los detalles a tu correo.', 12.5, 400, C.muted, 'text-anchor="middle"');
  s += button(95, 491, 200, 'VER MIS PEDIDOS');
  s += t(195, 570, 'Seguir comprando', 11, 500, C.ink, 'text-anchor="middle" text-decoration="underline"');
  return s;
}

function checkoutFailureScreen() {
  let s = statusBar();
  s += `<use href="#logo" x="18" y="42" width="104" height="30"/>`;
  s += `${circle(195,300,44,C.mist,'none')}${t(195,313,'×',34,400,C.sale,'text-anchor="middle"')}`;
  s += t(195, 386, 'Pago rechazado', 25, 400, C.ink, 'text-anchor="middle"');
  s += t(195, 419, 'Tuvimos un problema al procesar tu tarjeta.', 12.5, 400, C.muted, 'text-anchor="middle"');
  s += t(195, 439, 'Por favor, intenta con otro método de pago.', 12.5, 400, C.muted, 'text-anchor="middle"');
  s += button(95, 491, 200, 'REINTENTAR PAGO');
  s += t(195, 570, 'Volver a la bolsa', 11, 500, C.ink, 'text-anchor="middle" text-decoration="underline"');
  return s;
}

const flowGrid = [
  [80,250],[534,250],[988,250],[1442,250],[1896,250],
  [80,1160],[534,1160],[988,1160],[1442,1160],
];
const flows = [
  ['17 · Checkout · Entrega', deliveryScreen()],
  ['18 · Checkout · Productos', checkoutProductsScreen()],
  ['19 · Checkout · Revisión', reviewScreen()],
  ['20 · Pago seguro', secureScreen()],
  ['21 · Pago exitoso', checkoutSuccessScreen()],
  ['22 · Pago rechazado', checkoutFailureScreen()],
  ['23 · Cuenta · Login', accountScreen('login')],
  ['24 · Cuenta · Registro', accountScreen('register')],
  ['25 · Cuenta · Pedidos', accountScreen('signed')],
].map((v,i)=>({x:flowGrid[i][0],y:flowGrid[i][1],name:v[0],content:v[1]}));
flows.push({x:988,y:1160,name:'23 · Home · Tablet',content:wideHome(),size:{w:1000,h:720}});
flows.push({x:2052,y:1160,name:'24 · Checkout · Desktop',content:wideCheckout(),size:{w:1000,h:720}});

const files = [
  makeSheet('01-storefront', 'Storefront y descubrimiento', 'Pantallas móviles, overlays, búsqueda, onboarding y filtros.', storefront),
  makeSheet('02-commerce', 'Catálogo, producto y bolsa', 'Estados propios, externos, agotados y contenido de la bolsa.', commerce),
  makeSheet('03-checkout-account-responsive', 'Checkout, cuenta y responsive', 'Flujo de compra, autenticación y layouts amplios.', flows, {width:3132,height:2000}),
];

const combinedWidth = 3132;
const combinedHeight = 6300;
const section = (offsetY, title, subtitle, screens, sectionHeight) => {
  let content = `${rect(0,0,combinedWidth,sectionHeight,C.paper)}${t(80,82,'MONETTA · UI ACTUAL',11,700,C.gold,'letter-spacing="2"')}${t(80,128,title,36,400)}${t(80,159,subtitle,13,400,C.muted)}${line(80,184,combinedWidth-80,184,'#D8D0C5')}`;
  for (const item of screens) content += phone(item.x, item.y, item.name, item.content, item.size ?? {});
  return `<g id="${esc(title)}" transform="translate(0 ${offsetY})">${content}</g>`;
};
const combinedSvg = `<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="${combinedWidth}" height="${combinedHeight}" viewBox="0 0 ${combinedWidth} ${combinedHeight}">${defs()}<g id="Monetta — Toda la UI actual">${section(0,'Storefront y descubrimiento','Pantallas móviles, overlays, búsqueda, onboarding y filtros.',storefront,2100)}${section(2100,'Catálogo, producto y bolsa','Estados propios, externos, agotados y contenido de la bolsa.',commerce,2100)}${section(4200,'Checkout, cuenta y responsive','Flujo de compra, autenticación y layouts amplios.',flows,2100)}</g></svg>`;
const combinedTarget = path.join(outDir, '00-monetta-toda-la-ui.svg');
fs.writeFileSync(combinedTarget, combinedSvg);
files.unshift(combinedTarget);

console.log(JSON.stringify(files.map(file => ({ file, bytes: fs.statSync(file).size })), null, 2));
