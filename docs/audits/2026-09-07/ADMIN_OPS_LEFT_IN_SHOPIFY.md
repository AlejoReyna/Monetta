# Operations intentionally left in Shopify Admin

Phase F / WP-06 documents work the Monetta in-app owner panel does **not**
perform. Operators should use Shopify Admin (or the Partner app) for these.

| Area | Why it stays in Shopify Admin |
|------|-------------------------------|
| Stock / inventory by location | Panel edits title, single-variant price, and Headless publication only. Multi-location inventory, transfers, and adjustments remain Shopify-native. |
| Product media (images/video) | No media upload/reorder API in the panel. |
| Product create / delete / duplicate | Panel lists and patches existing products; creation and archival are merchant ops in Shopify. |
| Collections other than Today's Picks | Featured/Today's Picks membership + order are supported; other collection merchandising stays in Shopify. |
| Fulfillment, shipping labels, tracking | Order mirror is read-oriented; fulfillment is not driven from the app. |
| Refunds, returns, chargebacks | Payment capture and refunds stay in Shopify Checkout / Admin. |
| Payment methods, Markets, taxes, shipping rates | Shop commercial configuration is not exposed in-app. |
| Customer PII edits / account deletion fulfillment | Compliance webhooks open durable tasks; operator completes export/redaction in Shopify + internal process. |
| App uninstall cleanup | `app/uninstalled` webhook is intentionally omitted until a durable handler exists. |
| Theme / Online Store presentation | Native app + metaobject storefront config; Online Store theme edits remain in Shopify. |

When the panel reports a Shopify upstream or permission error, resolve scopes,
publication, and metaobject access in the Partner Dashboard / Admin before
retrying from the app.
