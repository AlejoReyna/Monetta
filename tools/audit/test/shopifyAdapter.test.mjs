import {test} from 'node:test';
import assert from 'node:assert/strict';
import {ShopifyAuditAdapter} from '../lib/shopifyAdapter.mjs';
const env = {AUDIT_SHOP_DOMAIN:'audit-test.myshopify.com',AUDIT_ADMIN_ACCESS_TOKEN:'local-contract-test',
  AUDIT_ENVIRONMENT:'development',EXPECTED_SHOP_ID:'123',AUDIT_SHOP_ALLOWLIST:'123',AUDIT_ALLOW_REMOTE_WRITES:'1',AUDIT_DRY_RUN:'0'};
const shop = {id:'gid://shopify/Shop/123',myshopifyDomain:env.AUDIT_SHOP_DOMAIN,primaryDomain:{host:env.AUDIT_SHOP_DOMAIN},plan:{partnerDevelopment:true}};
function adapter(replies, config = env) {
  const calls = [];
  const instance = new ShopifyAuditAdapter({env:config,fetchImpl:async (_url,options) => {
    calls.push(JSON.parse(options.body));
    const data = replies.shift();
    if (!data) throw new Error('Unexpected API call');
    return {ok:true,json:async () => ({data})};
  }});
  return {instance,calls};
}
const product = {id:'product:two-variants',kind:'product',status:'planned',meta:{tag:'monetta-qa-run-product'}};
test('requires live API identity, allowlist and development plan before mutation', async () => {
  for (const identity of [{...shop,id:'gid://shopify/Shop/999'}, {...shop,plan:{partnerDevelopment:false}}, {...shop,primaryDomain:{host:'monetta.mx'}}]) {
    const {instance,calls} = adapter([{shop:identity}]);
    await assert.rejects(instance.verify());
    assert.equal(calls.length,1);
    assert.ok(!calls[0].query.includes('mutation'));
  }
});
test('product creates actual ID and exact variants; retry discovers existing run resource', async () => {
  const {instance,calls} = adapter([{shop}, {products:{nodes:[]}}, {productSet:{product:{id:'gid://shopify/Product/1',variants:{nodes:[{id:'vA'},{id:'vB'}]}},userErrors:[]}}, {products:{nodes:[{id:'gid://shopify/Product/1',tags:[product.meta.tag]}]}}]);
  await instance.verify();
  const created = await instance.create(structuredClone(product),{resource_prefix:'monetta-qa-run'});
  assert.equal(created.remote_id,'gid://shopify/Product/1');
  assert.equal(calls[2].variables.input.variants.length,2);
  const recovered = await instance.create({...product,status:'creating'},{});
  assert.equal(recovered.remote_id,created.remote_id);
  assert.equal(calls.filter(c => c.query.startsWith('mutation')).length,1);
});
test('uncertain creation cannot blindly duplicate', async () => {
  const {instance,calls} = adapter([{shop},{products:{nodes:[]}}]);
  await instance.verify();
  await assert.rejects(instance.create({...product,status:'creating'},{}),/outcome unknown/);
  assert.equal(calls.length,2);
});
test('cleanup refuses resource whose actual run ownership differs', async () => {
  const {instance,calls} = adapter([{shop},{node:{id:'gid://shopify/Product/2',tags:[product.meta.tag]}}]);
  await instance.verify();
  await assert.rejects(instance.remove({...product,remote_id:'gid://shopify/Product/1'}),/ownership mismatch/);
  assert.equal(calls.length,2);
});
test('order fixtures are test-only, no receipts, inventory changes or real payment transactions', async () => {
  const {instance,calls} = adapter([{shop},{orders:{nodes:[]}},{orderCreate:{order:{id:'gid://shopify/Order/1',test:true},userErrors:[]}}]);
  await instance.verify();
  const result = await instance.create({id:'order:paid',kind:'order',meta:{tag:'monetta-qa-order'}},{resource_prefix:'monetta-qa-run'});
  const input = calls[2].variables;
  assert.equal(input.order.test,true); assert.equal(input.order.transactions,undefined);
  assert.deepEqual(input.options,{sendReceipt:false,sendFulfillmentReceipt:false,inventoryBehaviour:'BYPASS'});
  assert.equal(result.status,'created');
});
test('hosted personas remain blocked instead of falsely reporting customer creation/login', async () => {
  const {instance,calls} = adapter([{shop}]); await instance.verify();
  const result = await instance.create({id:'persona:A',kind:'persona',meta:{code:'A'}},{});
  assert.equal(result.status,'blocked'); assert.equal(result.remote_id,undefined); assert.equal(calls.length,1);
});

test('order cleanup uses official deletedId result', async () => {
  const tag = 'monetta-qa-order';
  const {instance,calls} = adapter([{shop},{node:{id:'gid://shopify/Order/1',tags:[tag],test:true}},{orderDelete:{deletedId:'gid://shopify/Order/1',userErrors:[]}}]);
  await instance.verify();
  assert.equal(await instance.remove({kind:'order',remote_id:'gid://shopify/Order/1',meta:{tag}}),true);
  assert.match(calls[2].query,/deletedId/);
});

test('refund and fulfillment cannot operate on an unowned or non-test order', async () => {
  const {operateTestOrder} = await import('../lib/orderOperations.mjs');
  const resource = {kind:'order',remote_id:'gid://shopify/Order/1',meta:{tag:'monetta-qa-order'}};
  const {instance,calls} = adapter([{shop},{orders:{nodes:[{id:resource.remote_id,tags:[resource.meta.tag]}]}},{order:{id:resource.remote_id,test:false}}]);
  await assert.rejects(operateTestOrder(instance,resource,'refund',{transactionId:'tx',amount:'1.00'}),/Only test orders/);
  assert.equal(calls.filter(c => c.query.startsWith('mutation')).length,0);
});
