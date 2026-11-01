import { createRequire } from 'node:module';
import { readFileSync,writeFileSync,mkdirSync } from 'node:fs';
import path from 'node:path';
const require=createRequire(path.resolve('design-prototype/package.json'));
const {chromium}=require('playwright-core');
const phase=process.argv[2]||'before';
const dir=path.resolve('artifacts/xl-storefront-2026-10-29');
const browser=await chromium.launch({executablePath:'/Applications/Brave Browser.app/Contents/MacOS/Brave Browser',headless:true});
const context=await browser.newContext({viewport:{width:1920,height:1080},deviceScaleFactor:1,reducedMotion:'reduce'});
const sizes=[[1280,900],[1440,900],[1536,960],[1920,1080],[2560,1440],[375,812],[768,1024],[1024,768],[1279,900],[1439,900]];
const routes={home:'/',carteras:'/collections/types?q=Cartera',bolsas:'/collections/all/bolsa',relojes:'/collections/types?q=Reloj'};
const measures=[];
const scrolls=phase==='before'?{}:JSON.parse(readFileSync(`${dir}/scrolls.json`));
mkdirSync(`${dir}/${phase}`,{recursive:true});
async function ready(page){
 await page.waitForSelector('.mw');
 await page.evaluate(async()=>{
  await document.fonts.ready;
  const imgs=[...document.images]; imgs.forEach(i=>i.loading='eager');
  await Promise.race([Promise.all(imgs.map(i=>i.decode().catch(()=>{}))),new Promise(r=>setTimeout(r,15000))]);
 });
 await page.addStyleTag({content:'#preview-bar-iframe, #ShopifyPreviewBar, shopify-preview-bar {display:none!important}'});
 await page.waitForTimeout(200);
}
function geometry(){
 const box=s=>{const e=typeof s==='string'?document.querySelector(s):s;if(!e)return null;const r=e.getBoundingClientRect(),c=getComputedStyle(e);return {x:r.x,y:r.y+scrollY,w:r.width,h:r.height,cols:c.gridTemplateColumns,gap:c.gap,padding:c.padding,fontSize:c.fontSize,aspect:c.aspectRatio,position:c.position,top:c.top};};
 return {url:location.href,theme:window.Shopify?.theme,viewport:{width:innerWidth,height:innerHeight,dpr:devicePixelRatio,scale:visualViewport.scale},scrollY,overflow:document.documentElement.scrollWidth-innerWidth,container:box('.listing--collection'),layout:box('.collection-layout'),sidebar:box('.filter-sidebar'),grid:box('[data-grid]'),banner:box('.guia-collection-hero .guide-hero'),card:box('[data-grid] .card'),media:box('[data-grid] .card__media'),actions:box('[data-grid] .card__actions'),body:box('[data-grid] .card__body'),name:box('[data-grid] .card__name'),price:box('[data-grid] .card__price'),styleRow:box('.guia-styles__list'),styleIcon:box('.guia-styles__icon'),styleHeading:box('.guia-styles .section-header'),collections:box('.guia-collections__track'),collectionHeading:box('.guia-collections .section-header'),collectionCard:box('.guia-collection-card'),broken:[...document.images].filter(i=>i.getClientRects().length&&(!i.complete||!i.naturalWidth)).map(i=>i.src),cards:[...document.querySelectorAll('[data-grid] .card')].slice(0,8).map(e=>({card:box(e),name:box(e.querySelector('.card__name')),price:box(e.querySelector('.card__price')),button:box(e.querySelector('.card__view')),status:e.querySelector('.card__eyebrow')?.textContent,src:e.querySelector('img')?.currentSrc,sizes:e.querySelector('img')?.sizes}))};
}
try{
 for(const [name,route] of Object.entries(routes)){
  const page=await context.newPage();
  const u=new URL(route,'http://127.0.0.1:9292');u.searchParams.set('pb','0');
  await page.goto(u.href,{waitUntil:'domcontentloaded',timeout:60000});await ready(page);
  for(const [width,height] of sizes){
   if(name==='relojes'&&![375,1440,1920].includes(width))continue;
   await page.setViewportSize({width,height});await page.evaluate(()=>scrollTo(0,0));await ready(page);
   const key=`${name}-${width}x${height}`;const measurement=await page.evaluate(geometry);
   if(measurement.theme?.id!==192576585762)throw Error('Unexpected theme '+JSON.stringify(measurement.theme));
   measures.push({page:name,width,height,...measurement});
   await page.screenshot({path:`${dir}/${phase}/${key}-top-y0.png`});
   const views=name==='home'?['styles','collections']:['grid'];
   for(const view of views){
    const selector=view==='styles'?'.guia-styles':view==='collections'?'.guia-collections':'[data-grid]';
    const scrollkey=`${key}-${view}`;
    if(phase==='before')scrolls[scrollkey]=view==='grid'?350:Math.round(await page.locator(selector).evaluate(e=>e.getBoundingClientRect().top+scrollY)-145);
    const y=scrolls[scrollkey];await page.evaluate(y=>scrollTo(0,y),y);await page.waitForTimeout(150);
    await page.screenshot({path:`${dir}/${phase}/${key}-${view}-y${y}.png`});
   }
   console.log(`${phase} ${key} overflow=${measurement.overflow} card=${measurement.card?.w} banner=${measurement.banner?.h} broken=${measurement.broken.length}`);
  }
  await page.close();
 }
}finally{writeFileSync(`${dir}/measurements-${phase}.json`,JSON.stringify(measures,null,2));if(phase==='before')writeFileSync(`${dir}/scrolls.json`,JSON.stringify(scrolls,null,2));await browser.close();}
