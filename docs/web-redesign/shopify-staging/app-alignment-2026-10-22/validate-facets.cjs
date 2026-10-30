// Run with LiquidJS installed outside the repository: NODE_PATH=/tmp/monetta-liquid-validation/node_modules node <this file>
const {Liquid}=require('liquidjs');
const {strict:assert}=require('node:assert');
const path=require('node:path');
const fs=require('node:fs');
const root=path.resolve(__dirname,'../../../..');
const engine=new Liquid({root:path.join(root,'storefront-theme/snippets'),extname:'.liquid'});
engine.registerFilter('handleize',value=>String(value).toLowerCase().replace(/[^a-z0-9]+/g,'-').replace(/^-|-$/g,''));
const base={title:'Pieza',type:'',vendor:'Monetta ',tags:[],collections:[],metafields:{app:{},custom:{}}};
const cases=[
 ['marca desde título', {title:'Bolsa Guess Crossbody Café',vendor:'Monetta '},'brands','Guess'],
 ['etiqueta sobre título', {title:'Bolsa Guess',tags:['Coach']},'brands','Coach'],
 ['orden de etiquetas', {tags:['Coach','Guess']},'brands','Coach'],
 ['override propietario', {title:'Bolsa Guess',metafields:{app:{brand_override:{value:'michael_kors'}},custom:{}}},'brands','Michael Kors'],
 ['proveedor tienda no es marca', {},'brands',''],
 ['proveedor reconocido', {vendor:'Coach'},'brands','Coach'],
 ['marca desde colección', {collections:[{handle:'steve-madden'}]},'brands','Steve Madden'],
 ['categoría más específica entre tags', {tags:['Bolsa','Cartera']},'categories','Cartera'],
 ['tipo sobre título', {type:'Reloj',title:'Bolsa Guess'},'categories','Reloj'],
 ['forma', {title:'Bolsa Guess Hobo'},'silhouettes','Hobo'],
 ['colores con acentos', {title:'Café / Blanca'},'colors','Blanco, Café'],
 ['color tag no mezcla título', {tags:['Negro'],title:'Bolsa azul cadena dorada'},'colors','Negro'],
 ['orden de colores en etiquetas', {tags:['Azul','Blanco']},'colors','Azul, Blanco'],
 ['motivo', {title:'Bolsa Coach Monogram'},'patterns','Monograma'],
 ['sin falsos subtextos', {title:'Totemico dorado'},'silhouettes',''],
 ['sin oro dentro de dorado', {title:'Bolsa decolorada'},'colors','']
];
(async()=>{
 for(const [name,changes,kind,expected] of cases){
  const actual=(await engine.renderFile('monetta-facet',{product:{...base,...changes},kind})).trim();
  assert.equal(actual,expected,name);
 }
 const report={cases:cases.length,result:'PASS',engine:'LiquidJS',scope:'Vocabulario Liquid generado vs prioridades y etiquetas de Flutter; no emula el API comercial de Shopify.'};
 fs.writeFileSync(path.join(__dirname,'facet-validation.json'),JSON.stringify(report,null,2)+'\n');
 console.log(report);
})().catch(error=>{console.error(error);process.exitCode=1;});
