import {createRequire} from 'node:module';
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import path from 'node:path';
const require=createRequire(path.resolve('design-prototype/package.json'));
const {chromium}=require('playwright-core');
const dir=path.resolve('artifacts/xl-storefront-2026-10-29');
const base='http://127.0.0.1:9292';
const browser=await chromium.launch({executablePath:'/Applications/Brave Browser.app/Contents/MacOS/Brave Browser',headless:true});
const context=await browser.newContext({viewport:{width:1920,height:1080},deviceScaleFactor:1,reducedMotion:'reduce'});
const checks=[],errors=[],mutations=[];
const check=(name,pass,detail)=>{checks.push({name,pass:!!pass,detail});console.log(`${pass?'PASS':'FAIL'} ${name} ${detail?JSON.stringify(detail):''}`)};
await context.route('**/*',async route=>{const r=route.request();if(r.method()!=='GET'&&/\/cart(?:\/|\.|\?)/.test(r.url())){mutations.push(r.url());return route.abort();}return route.continue()});
const page=await context.newPage();page.on('pageerror',e=>errors.push(e.message));
async function visit(route){await page.goto(base+route+(route.includes('?')?'&':'?')+'pb=0',{waitUntil:'domcontentloaded',timeout:60000});await page.waitForSelector('.mw');await page.evaluate(()=>document.fonts.ready);await page.waitForTimeout(250)}
async function settle(){await page.evaluate(async()=>{const imgs=[...document.querySelectorAll('img')];imgs.forEach(i=>i.loading='eager');await Promise.race([Promise.all(imgs.map(i=>i.decode().catch(()=>{}))),new Promise(r=>setTimeout(r,12000))])})}
async function media(){return page.locator('[data-grid] .card__media').first().evaluate(e=>({w:e.clientWidth,h:e.clientHeight,fit:getComputedStyle(e.querySelector('img')).objectFit}))}
try{
 const before=JSON.parse(readFileSync(`${dir}/measurements-before.json`)),after=JSON.parse(readFileSync(`${dir}/measurements-after.json`));
 for(const a of after){
  const b=before.find(x=>x.page===a.page&&x.width===a.width);
  check(`${a.page} ${a.width} no horizontal overflow or broken images`,a.overflow===0&&a.broken.length===0);
  if(a.width<1280){const fields=['container','banner','card','media','grid','styleRow','collections','collectionHeading'];check(`${a.page} ${a.width} unchanged geometry`,fields.every(k=>JSON.stringify(a[k])===JSON.stringify(b[k])))}
  else if(a.grid){
   check(`${a.page} ${a.width} columns`,a.grid.cols.split(' ').length===(a.width<1440?3:4));
   check(`${a.page} ${a.width} earlier products`,b.grid.y-a.grid.y>=120,{earlier:b.grid.y-a.grid.y});
   const cols=a.width<1440?3:4;
   for(let i=0;i<a.cards.length;i+=cols){const row=a.cards.slice(i,i+cols);for(const field of ['name','price','button'])check(`${a.page} ${a.width} row ${i/cols+1} ${field} alignment`,Math.max(...row.map(c=>c[field].y))-Math.min(...row.map(c=>c[field].y))<0.1);check(`${a.page} ${a.width} row ${i/cols+1} card bottoms`,Math.max(...row.map(c=>c.card.y+c.card.h))-Math.min(...row.map(c=>c.card.y+c.card.h))<0.1)}
  }
  if(a.width>=1280&&a.page==='home'){check(`home ${a.width} collection alignment and scale`,Math.abs(a.collectionHeading.x-a.collectionCard.x)<.1&&a.collections.w>=1120&&a.collections.w<=1200&&a.collectionCard.w>=350&&a.collectionCard.w<=380);check(`home ${a.width} styles scale and alignment`,a.styleIcon.w>=96&&a.styleIcon.w<=104&&a.styleRow.w>=900&&a.styleRow.w<=1000&&a.styleRow.x===a.styleHeading.x)}
 }
 // Before choosing a frame, compare the exact same widened cards and source images at both ratios.
 await visit('/collections/types?q=Cartera');await settle();
 const sources=await page.locator('[data-grid] img').evaluateAll(imgs=>imgs.map(i=>({src:i.src,width:i.getAttribute('width'),height:i.getAttribute('height')})));
 writeFileSync(`${dir}/carteras-source-dimensions.json`,JSON.stringify(sources,null,2));
 mkdirSync(`${dir}/media-comparison`,{recursive:true});
 for(const ratio of ['1','4 / 5']){
  const style=await page.addStyleTag({content:`@media(min-width:1280px){.listing--collection :is(.card__media,.card__actions){aspect-ratio:${ratio}!important}}`});
  for(const y of [350,850]){await page.evaluate(y=>scrollTo(0,y),y);await page.screenshot({path:`${dir}/media-comparison/carteras-1920x1080-${ratio==='1'?'square':'portrait'}-y${y}.png`})}
  await style.evaluate(e=>e.remove());
 }
 // Sort/filter/page requests use Shopify's existing forms and URLs, without cart writes.
 await page.locator('[data-sort-select]').selectOption('price-ascending');await page.waitForURL('**/*sort_by=price-ascending*');
 check('sorting retains Carteras product type',await page.locator('h1').innerText().then(t=>/CARTERAS/i.test(t)));
 await page.locator('.filter-sidebar input[type=checkbox]:not(:disabled)').first().check();await page.waitForURL('**/*filter.v.availability=1*');
 check('filter preserves sort and product type',page.url().includes('sort_by=price-ascending')&&/CARTERAS/i.test(await page.locator('h1').innerText()));
 await page.locator('.active-chips .chip--removable').first().click();await page.waitForURL(u=>!u.searchParams.has('filter.v.availability'));
 check('remove filter preserves type and sort',page.url().includes('sort_by=price-ascending')&&/CARTERAS/i.test(await page.locator('h1').innerText()));
 const count=await page.locator('[data-grid] > li').count();await page.locator('[data-more]').click();await page.waitForFunction(n=>document.querySelectorAll('[data-grid] > li').length>n,count);
 check('pagination appends and preserves sort',await page.locator('[data-grid] > li').count()>count&&page.url().includes('page=2')&&page.url().includes('sort_by=price-ascending'));
 const destination=await page.locator('[data-grid] .card__link').first().getAttribute('href');await page.locator('[data-grid] .card__link').first().click();await page.waitForURL('**/products/**');check('card destination',page.url().includes(destination.split('?')[0]));
 await visit('/collections/all/bolsa');
 await page.locator('.guia-pill').filter({hasText:'Carteras'}).click();await page.waitForURL('**/collections/types?q=Cartera*');check('category navigation',/CARTERAS/i.test(await page.locator('h1').innerText()));
 await page.setViewportSize({width:1280,height:900});await page.locator('.collection-layout--filters').evaluate(e=>e.classList.remove('collection-layout--filters'));
 check('no-sidebar listing stays four columns at 1280 (DOM simulation)',await page.locator('[data-grid]').evaluate(e=>getComputedStyle(e).gridTemplateColumns.split(' ').length===4));
 // Visible keyboard rings, action bounds, and sticky sidebar under measured header.
 await visit('/collections/all/bolsa');await page.setViewportSize({width:1440,height:900});
 await page.locator('[data-grid] .card__link').first().focus();await page.keyboard.press('Tab');
 const focus=await page.evaluate(()=>{const e=document.activeElement,r=e.getBoundingClientRect(),c=getComputedStyle(e);const y=Math.min(innerHeight-1,Math.max(0,r.top+r.height/2));return {tag:e.tagName,top:r.top,bottom:r.bottom,outline:c.outlineWidth,style:c.outlineStyle,hit:e.contains(document.elementFromPoint(r.x+r.width/2,y)),reserve:parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--pinned-top'))}});
 check('keyboard action focus visible and unobscured',focus.hit&&focus.top>=focus.reserve&&focus.bottom<=900,focus);
 await page.screenshot({path:`${dir}/keyboard-focus-1440x900.png`});
 await page.evaluate(()=>scrollTo(0,900));check('sidebar sticky below header',await page.locator('.filter-sidebar').evaluate(e=>Math.abs(e.getBoundingClientRect().top-(parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--pinned-top'))+16))<1));
 // Long price line (synthetic DOM only) must grow rather than clip; corresponding starts and buttons stay aligned.
 await page.setViewportSize({width:1920,height:1080});await page.evaluate(()=>scrollTo(0,350));
 await page.locator('[data-grid] .card').nth(0).evaluate(e=>{e.querySelector('.card__name').textContent='Una línea';e.querySelector('.price').textContent='Desde $ 12,345.67';});
 await page.locator('[data-grid] .card').nth(1).evaluate(e=>e.querySelector('.price').textContent='Desde $ 123,456,789.00');
 const mixed=await page.locator('[data-grid] .card').evaluateAll(es=>es.slice(0,4).map(e=>({price:e.querySelector('.card__price').getBoundingClientRect().top,button:e.querySelector('.card__view').getBoundingClientRect().bottom,bottom:e.getBoundingClientRect().bottom})));
 check('synthetic one/two-line titles, sale/Desde prices and delivery align',Math.max(...mixed.map(x=>x.price))-Math.min(...mixed.map(x=>x.price))<.1&&Math.max(...mixed.map(x=>x.button))-Math.min(...mixed.map(x=>x.button))<.1,mixed);
 await page.screenshot({path:`${dir}/synthetic-mixed-metadata-1920x1080.png`});
 await visit('/collections/types?q=Reloj');const trigger=page.locator('[data-grid] [data-quick-view]').first();await trigger.click();await page.waitForSelector('#quick-view[open]');check('watch quick view opens',await page.locator('#quick-view').isVisible());await page.keyboard.press('Escape');check('quick view closes and restores focus',await trigger.evaluate(e=>document.activeElement===e));
 await page.setViewportSize({width:375,height:812});await visit('/');await settle();
 const center=await page.locator('[data-guia-collections]').evaluate(e=>{const r=e.getBoundingClientRect(),c=e.children[1].getBoundingClientRect();return Math.abs(c.x+c.width/2-(r.x+r.width/2))});check('mobile collections opens centered on middle card',center<2,{center});
 const track=page.locator('[data-guia-collections]');await track.evaluate(e=>e.scrollTo({left:0,behavior:'instant'}));check('mobile collections scrolls to first card',await track.evaluate(e=>e.scrollLeft)<2);
 await track.locator('a').last().focus();check('mobile carousel keyboard focus visible',await track.locator('a').last().evaluate(e=>{const r=e.getBoundingClientRect();return r.x>=0&&r.right<=innerWidth}));
 // DPR2 fresh requests must supply the final slot, while compact rails keep the old candidates.
 const hi=await browser.newContext({viewport:{width:1439,height:900},deviceScaleFactor:2,reducedMotion:'reduce'});const hp=await hi.newPage();await hp.goto(base+'/collections/types?q=Cartera&pb=0');await hp.locator('[data-grid] img').first().waitFor();await hp.waitForTimeout(600);
 const delivery=await hp.locator('[data-grid] img').first().evaluate(e=>({url:e.currentSrc,slot:e.getBoundingClientRect().width,width:Number(new URL(e.currentSrc).searchParams.get('width')),sizes:e.sizes}));check('high density listing receives adequate candidate',delivery.width>=delivery.slot*2,delivery);await hi.close();
 await visit('/');check('compact rails keep 600px ceiling',await page.locator('.rail img').evaluateAll(es=>es.filter(e=>e.srcset).every(e=>!e.srcset.includes('720w')&&!e.srcset.includes('900w'))));
 check('no cart mutation requests',mutations.length===0,mutations);check('no page JavaScript errors',errors.length===0,errors);
}catch(e){checks.push({name:'flow harness completion',pass:false,detail:e.stack});console.log(e.stack)}finally{writeFileSync(`${dir}/verification.json`,JSON.stringify({checks,errors,mutations,passed:checks.filter(c=>c.pass).length,failed:checks.filter(c=>!c.pass).length},null,2));await browser.close()}
