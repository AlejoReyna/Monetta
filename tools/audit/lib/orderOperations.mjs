/** Explicit lifecycle operations on this run's verified test orders only.
 * No operation here applies to an order lacking both run ownership and test=true.
 * Caller persists the returned actual mutation result before proceeding.
 */
export async function operateTestOrder(adapter, resource, action, {fulfillmentOrderId, transactionId, amount} = {}) {
  await adapter.verify();
  if (resource.kind !== 'order' || !resource.remote_id || await adapter.find(resource) !== resource.remote_id) throw new Error('Run order ownership required');
  const {order} = await adapter.query('query AuditTestOrder($id: ID!) { order(id: $id) { id test } }', {id:resource.remote_id});
  if (order?.test !== true) throw new Error('Only test orders can be operated');
  if (action === 'cancel') {
    return adapter.query('mutation AuditCancel($id: ID!) { orderCancel(orderId: $id, reason: OTHER, notifyCustomer: false, refund: false, restock: false) { job { id done } orderCancelUserErrors { field message } } }', {id:order.id});
  }
  if (action === 'fulfill') {
    if (!fulfillmentOrderId) throw new Error('Actual fulfillment order ID required');
    const data = await adapter.query('query AuditFulfillmentOwner($id: ID!) { fulfillmentOrder(id: $id) { order { id } } }', {id:fulfillmentOrderId});
    if (data.fulfillmentOrder?.order?.id !== order.id) throw new Error('Fulfillment order belongs to another order');
    return adapter.query('mutation AuditFulfill($input: FulfillmentInput!) { fulfillmentCreate(fulfillment: $input) { fulfillment { id status } userErrors { field message } } }', {
      input:{notifyCustomer:false,lineItemsByFulfillmentOrder:[{fulfillmentOrderId}]},
    });
  }
  if (action === 'refund') {
    if (!transactionId || !/^\d+(\.\d{1,2})?$/.test(amount ?? '')) throw new Error('Test transaction ID and decimal amount required');
    const data = await adapter.query('query AuditRefundTransaction($id: ID!) { order(id: $id) { transactions { id test gateway status kind } } }', {id:order.id});
    const transaction = data.order.transactions.find(t => t.id === transactionId && t.test && t.status === 'SUCCESS' && ['SALE','CAPTURE'].includes(t.kind));
    if (!transaction) throw new Error('Confirmed test payment transaction required');
    return adapter.query('mutation AuditRefund($input: RefundInput!) { refundCreate(input: $input) { refund { id } userErrors { field message } } }', {
      input:{orderId:order.id,notify:false,transactions:[{orderId:order.id,parentId:transactionId,kind:'REFUND',amount,gateway:transaction.gateway}]},
    });
  }
  throw new Error('Unsupported test order action');
}

export async function operateTestProduct(adapter, resource, action) {
  await adapter.verify();
  if (adapter.kind(resource) !== 'product' || !resource.remote_id || await adapter.find(resource) !== resource.remote_id) throw new Error('Run product ownership required');
  if (!['publish','unpublish'].includes(action)) throw new Error('Unsupported product operation');
  const publicationId = adapter.env.AUDIT_PUBLICATION_ID;
  if (!publicationId) throw new Error('AUDIT_PUBLICATION_ID required');
  const {node} = await adapter.query('query AuditPublication($id: ID!) { node(id: $id) { ... on Publication { id } } }', {id:publicationId});
  if (node?.id !== publicationId) throw new Error('Publication is not on verified development shop');
  const mutation = action === 'publish' ? 'publishablePublish' : 'publishableUnpublish';
  await adapter.query(`mutation AuditPublish($id: ID!, $publicationId: ID!) { ${mutation}(id: $id, input: {publicationId: $publicationId}) { userErrors { field message } } }`, {id:resource.remote_id,publicationId});
  return {publicationId,published:action === 'publish'};
}
