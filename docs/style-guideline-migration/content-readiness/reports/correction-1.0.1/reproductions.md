# Reproducciones de la revisión independiente

Auditor anterior: 1.0.0. Auditor corregido: 1.0.1.

Las mutaciones sólo se aplican en memoria. La baseline y los snapshots permanecen congelados.

| Reproducción | Antes: errores/avisos | Hallazgos nuevos antes | Después: errores/avisos | Hallazgos nuevos después |
| --- | --- | --- | --- | --- |
| catalog-mode-crossing | 47/196 | 0 | 49/196 | CATALOG_MODE_MISMATCH, WHOLESALE_DESTINATION_PUBLIC_SHARE |
| catalog-category-crossing | 47/196 | 0 | 48/196 | CATALOG_CATEGORY_MISMATCH |
| collection-without-route | 47/195 | 0 | 49/195 | SCHEMA_ANY_OF_MISMATCH, SELECTION_ROUTE_REQUIRED |
| module-family-crossing | 45/195 | 0 | 47/195 | HOME_MODULE_FAMILY_MISMATCH, SCHEMA_ANY_OF_MISMATCH |

## catalog-mode-crossing

Mutación: `bags-suggested.destination.routeId = catalog.bags-wholesale`.

- **CATALOG_MODE_MISMATCH** en `/content/catalogs/1/destination`: Catalog mode suggested_prices differs from destination mode wholesale.
- **WHOLESALE_DESTINATION_PUBLIC_SHARE** en `/content/catalogs/1/shareable`: A shareable catalog cannot send customers to a wholesale destination.

## catalog-category-crossing

Mutación: `bags-wholesale.destination.routeId = catalog.perfume-wholesale`.

- **CATALOG_CATEGORY_MISMATCH** en `/content/catalogs/0/destination`: Catalog category bags differs from destination category perfume.

## collection-without-route

Mutación: `todays-picks.source.kind = collection; delete source.routeId`.

- **SCHEMA_ANY_OF_MISMATCH** en `/content/productSelections/todays-picks/source`: Value must match at least one allowed schema.
- **SELECTION_ROUTE_REQUIRED** en `/content/productSelections/todays-picks/source/routeId`: A collection selection requires a non-empty collection routeId.

## module-family-crossing

Mutación: `home.moduleOrder = [{id:newest,kind:product_selection,contentRef:rewards}]`.

- **HOME_MODULE_FAMILY_MISMATCH** en `/content/home/moduleOrder/0/contentRef`: Module kind product_selection cannot reference family rewards.
- **SCHEMA_ANY_OF_MISMATCH** en `/content/home/moduleOrder/0`: Value must match at least one allowed schema.
