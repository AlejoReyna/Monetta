# Plan: cerrar los huecos del sistema de recomendaciones

**Fecha:** 2026-10-29
**Base verificada:** `origin/main` en `11b4f5f`. Todas las referencias `archivo:línea` de este documento son de esa revisión, no del checkout de `feat/client-guide-oct20`.
**Estado:** borrador para la persona. Nada de esto está implementado ni aprobado.

## 1. Resumen

El motor de `lib/reco/` funciona y aprende en el teléfono: registra vistas, galería, favoritos, bolsa y apartados por WhatsApp. Sus 8 pruebas pasan. Pero:

- **Se ve poco.** Sólo aparece en el riel «Recomendaciones» de la bolsa y en las sugerencias del buscador, y en este último sólo antes de abrir un producto. El inicio dejó de mostrarlo el 2026-08-27.
- **Aprende de la mitad de lo que debería.** No registra compras, búsquedas ni filtros.
- **Olvida lo que la clienta declaró.** Las marcas y estilos de la bienvenida y de «Personalización» se pierden al reiniciar la app y desaparecen con la primera vista.
- **Sin datos, ordena por ID.** Con un perfil vacío todas las puntuaciones valen 0, así que el orden sale del GID de Shopify.

**Meta:** que una clienta con pocas interacciones vea en el inicio una selección que refleje lo que eligió y lo que hizo, que lo comprado no se le vuelva a ofrecer, y que podamos medir si eso vende.

## 2. Estado verificado en `main`

| # | Hueco | Evidencia en `main` | Efecto para la clienta |
|---|---|---|---|
| H1 | El inicio no muestra el ranking | `home_screen.dart:328` calcula `store.feed()` sólo para el caso vacío (`:343`) y para precargar imágenes (`:179`). Ninguna sección lo pinta; «Catálogo de hoy» sale de la colección destacada de Shopify | No ve nada personalizado al abrir la app |
| H2 | No se registran compras | Ninguna llamada a `EventType.purchase`. `applyCheckoutPurchase` (`catalog_store.dart:625`) sólo ajusta la bolsa | Lo que ya compró puede reaparecer en las recomendaciones |
| H3 | No se excluye lo comprado | `feed()` (`catalog_store.dart:677`) construye `ScoringContext` sin `purchasedProductIds` | Igual que H2 |
| H4 | Búsquedas y filtros no enseñan nada | No hay ningún `EventType.searchOrFilter`. `record()` (`:466`) no acepta `facetHint`, aunque `ProfileBuilder` sí lo usa (`profile.dart:130`) | Filtrar «Guess, negro» diez veces no cambia lo que le sugerimos |
| H5 | Las preferencias declaradas no persisten | La bienvenida (`onboarding_sheet.dart:85`) y «Personalización» (`personalization_screen.dart:165`) llaman a `seedFrom` (`catalog_store.dart:447`), que sólo vive en memoria. `_rebuildProfile` (`:664`) la reemplaza entera con el primer evento | Lo que eligió dura hasta la primera vista o el siguiente arranque |
| H6 | Arranque en frío arbitrario | Con perfil vacío, `similarityTo` da 0 y el orden sale del desempate por `productId` (`scorer.dart`, sort). `isConfident` (`profile.dart:43`) no se usa fuera de `lib/reco`. El respaldo de la bolsa casi nunca se activa: `feed()` devuelve el catálogo entero aunque todas las puntuaciones valgan 0 | Recomendaciones sin criterio para quien recién instala |
| H7 | «Volvió a stock» nunca se activa | Nadie llena `recentlyRestockedIds` | Ninguno visible; el multiplicador está muerto |
| H8 | El motivo no se muestra | `Recommendation.reason` se calcula y ninguna pantalla lo pinta | Se pierde el «Porque te gustan…», que el README considera la mitad del valor |
| H9 | «Vistos recientemente» dura una sesión | `_recentIds` sólo vive en memoria (`catalog_store.dart:484`), aunque las vistas están en Drift | Tras reiniciar, la ficha y el buscador olvidan lo visto |
| H10 | El historial crece sin límite | `InteractionEventStore.all()` (`interaction_event_store.dart:35`) lee la tabla completa en cada arranque y nada borra filas. `ProfileBuilder` ya ignora lo que tiene más de unos 79 días (`profile.dart:124`) | Arranque cada vez más lento en clientas frecuentes |
| H11 | No se puede medir | `_rec_source` siempre vale `direct` (`cart_attribution.dart:46`). Ningún evento de analytics distingue los rieles | No sabemos si las recomendaciones venden |
| H12 | Documentación desfasada | `lib/reco/README.md` dice que nada sale del dispositivo, pero existe el resumen opcional para push (`notification_controller.dart:327`). Cita `profile_test.dart` y `explainer_test.dart`, que no existen. Promete una «ventana reciente acotada» que no existe | Riesgo legal y de mantenimiento |
| H13 | Ranking en cada `build` | R20 de la revisión: el inicio llama a `feed()` en `build` y cada `record()` notifica a todo el árbol | Bajo hoy; sube si el inicio muestra el riel |

También en `main`, y fuera de este plan: `mixedFeed` (`catalog_store.dart:724`) y `lib/reco/external_facets.dart` son código del catálogo externo sin llamadas en `lib/`. RF-20 los retira en la cadena del refactor; aquí no se tocan.

## 3. Dónde se hace (encaje con el refactor)

- **Recomendación: en `main`, como trabajo de producto.** Igual que el resto del trabajo de producto:
  - una rama `feat/reco-<slug>` que sale de `origin/main`;
  - un worktree propio en `.claude/worktrees/`;
  - un PR que la persona revisa y fusiona.

  La cadena del refactor integra `main` según D-06 antes de empezar RF-50.
- **Para no chocar con RF-50**, que separará `CatalogStore` en repositorios de interacción y recomendación:
  - la lógica nueva va a `lib/reco/`, que es puro y RF-50 no reescribe;
  - `catalog_store.dart` sólo recibe cambios delgados de cableado;
  - la prueba de paridad CHAR-18 de RF-50 se escribe después de integrar esto.
- **Alternativa:** abrir estos paquetes como RF-5x después de RF-50. Es más limpio para el refactor, pero RF-50 sigue pendiente detrás de RF-53, así que la función se retrasaría semanas.
- **Disciplina, en los dos casos:**
  - la prueba va primero y se comprueba que falla por la razón correcta;
  - se respetan los invariantes de `CLAUDE.md`;
  - no se cambia el esquema de la base;
  - commits sólo cuando la persona los pida.

## 4. Decisiones para la persona

| ID | Decisión | Recomendación | Bloquea |
|---|---|---|---|
| RD-1 | ¿Dónde se hace? | En `main` por ramas `feat/reco-*` (§3) | Todo |
| RD-2 | Riel «Para ti» en el inicio: ¿posición y quién la controla? | Segunda sección. Si el orden configurado en Shopify no la menciona, la app la inserta ahí; si la menciona, se respeta ese orden. Sólo aparece con un perfil confiable (RD-4) | RC-4 |
| RD-3 | ¿Dónde se muestra el motivo («Porque te gustan las bolsas crossbody de Guess»)? | Sólo en el riel «Para ti», una línea bajo el encabezado del riel o en cada tarjeta según el diseño | RC-4 |
| RD-4 | ¿Qué se muestra antes de tener datos (menos de 5 señales y sin preferencias declaradas)? | El inicio oculta «Para ti». La bolsa y el buscador usan «Catálogo de hoy» y, si no hay, lo más nuevo. Nunca el orden por GID | RC-4 |
| RD-5 | «Volvió a stock» | Quitarlo por ahora del ranking. Las alertas push de reabastecimiento ya lo cubren desde el servidor | RC-2 |
| RD-6 | ¿Cómo se mide? | Eventos de analytics por riel (RC-5), sin esperar a E8. `_rec_source` sigue en RF-67 | RC-5 |
| RD-7 | ¿Cuánto historial se conserva? | 80 días y un tope de 5 000 filas. Más allá de unos 79 días un evento ya aporta menos del 2 % y `ProfileBuilder` lo descarta, así que el perfil no cambia | RC-6 |
| RD-8 | ¿Las compras deben entrar al resumen de intereses que se sube cuando la clienta activa ofertas personalizadas? | Sí. Es el mismo resumen de marcas y categorías, sin historial. Conviene revisar el aviso de privacidad (LFPDPPP) | RC-2 |

## 5. Paquetes de trabajo

Orden: RC-1 → RC-2 → RC-3 → RC-4 → RC-5. RC-6 puede ir en cualquier momento después de RC-1. RC-2, RC-3 y RC-4 tocan `catalog_store.dart`, así que van en serie.

### RC-1 · Pruebas del motor y documentación veraz

**Objetivo:** fijar el comportamiento actual antes de cambiarlo. No cambia nada que vea la clienta.
**Tamaño:** S. **Agente:** test-engineer. **Decisiones:** ninguna.

**Cambios:**
- `test/reco/profile_test.dart`: decaimiento, permanencia, tope de impresiones, negativos recortados, normalización L2 y `facetHint`.
- `test/reco/explainer_test.dart`: prioridad de motivos (stock ▸ precio ▸ nuevo ▸ gusto ▸ tendencia) y concordancia (`las bolsas` frente a `los relojes`).
- Caracterización de `CatalogStore.feed()` sobre un catálogo fijo, para detectar después cambios de ranking no buscados.
- Prueba de que los valores de `EventType` se guardan por nombre: `byName` falla con un nombre desconocido, así que nunca se renombran ni se borran.
- `lib/reco/README.md`:
  - privacidad: el resumen opcional para push;
  - la lista real de pruebas;
  - quitar la «ventana acotada» hasta RC-6.
- Actualizar `docs/SYSTEM_IMPLEMENTATION.md` §7.

**Aceptación:** pruebas nuevas en verde sobre el código actual; formato, análisis y `flutter test --no-pub` en verde.

### RC-2 · Señales que faltan: compras, búsquedas y filtros

**Objetivo:** que el perfil aprenda de lo que la clienta compra y de lo que busca, y que lo comprado no se le vuelva a ofrecer.
**Tamaño:** M. **Agentes:** test-engineer → flutter-implementer. **Decisiones:** RD-5, RD-8.

**Compras (H2, H3):**
- En `applyCheckoutPurchase` (`catalog_store.dart:625`), tomar el producto de cada variante comprada de la bolsa antes de aplicarla y registrar un `EventType.purchase` por producto.
- **Idempotencia (invariante 4):**
  - el evento sólo se registra si el recibo es nuevo;
  - para saberlo, `BagStore` gana un método nuevo que devuelve si aplicó (`Future<bool>`). `applyPurchase` (`bag_store.dart:81`) delega en él y conserva su firma, como pide el patrón estrangulador;
  - el recibo y la bolsa se quedan en su transacción;
  - el registro del evento no puede deshacer ni bloquear la compra.
- `feed()` pasa `purchasedProductIds` a partir de los eventos de compra del registro local.
- Límite conocido: lo comprado en la web o por WhatsApp no se conoce. El apartado por WhatsApp ya se registra.

**Búsquedas y filtros (H4):**
- `record()` gana un parámetro opcional `facetHint`. Es un cambio aditivo.
- Se registra un evento por faceta en estos puntos:
  - al aplicar filtros en `catalog_browse_screen.dart` (`_CatalogFilters`: marcas, categorías, rangos de precio y colores; confirmar a qué faceta corresponde `types` o dejarlo fuera);
  - al aplicar filtros en `collection_screen.dart` (`_CollectionFilters`: marca, silueta y categoría);
  - al tocar una categoría en el buscador;
  - al enviar texto libre en el buscador, sólo si coincide exactamente con una marca o categoría.
- Se registra al aplicar, no al marcar opciones dentro de la hoja.
- `ProfileBuilder` escala `facetHint` por `facetWeights[kind]`, igual que los vectores de producto. Hoy lo suma sin peso (`profile.dart:130`). Es un cambio de comportamiento con prueba.

**«Volvió a stock» (RD-5):** si se acepta, documentar el multiplicador como inactivo y no cablearlo.

**Pruebas primero:**
- una compra duplicada (mismo `operationId`) registra un solo evento;
- un producto comprado no aparece en `feed()`;
- aplicar «Guess» en filtros sube `brand:guess`;
- un texto libre sin coincidencia no registra nada;
- un fallo al registrar el evento no rompe la compra.

**Aceptación:** lo anterior, más INV-01 (recibos y cuentas), INV-02, INV-13, INV-14 y `test/data/notifications/interest_profile_snapshot_test.dart` (resumen para push, fuera de INV-13) en verde.

### RC-3 · Preferencias declaradas como base durable

**Objetivo:** que lo que la clienta eligió en la bienvenida o en «Personalización» se conserve y se combine con su comportamiento, en lugar de borrarse.
**Tamaño:** M. **Agentes:** test-engineer → flutter-implementer. **Decisiones:** ninguna nueva.

**Cambios:**
- En `lib/reco/profile.dart`, `ProfileBuilder.build` acepta un `prior`: el vector de preferencias declaradas. Se suma antes de normalizar con un peso total igual a `minEventsForPersonalization`, como ya dice el README. No decae: vale hasta que la clienta lo edite. Con 20 vistas de otra marca, el comportamiento domina.
- El `prior` cuenta para `isConfident`. Así, una clienta que eligió marcas ve «Para ti» desde el primer día.
- Mover a una función pura la conversión de estilos a categoría y silueta que hoy está dentro de `personalization_screen.dart:165`.
- La bienvenida guarda sus elecciones en el mismo `ShopperPreferenceStore` del alcance invitado (`''`) para que sobrevivan al reinicio.
- `seedFrom` deja de sustituir el perfil y pasa a actualizar el `prior`.
- **Cambio de cuenta (invariante 9):** al cambiar de alcance se carga el `prior` de la cuenta nueva. Una lectura tardía de la cuenta A no se aplica a la B. Los eventos siguen siendo del dispositivo, como establece `tables.dart`.

**Pruebas primero:**
- reiniciar conserva las preferencias;
- la primera vista no las borra;
- muchas vistas de otra marca acaban dominando;
- cambiar de cuenta cambia el `prior`;
- una lectura tardía se descarta.

**Aceptación:** lo anterior, más INV-02, INV-13, INV-14 y la prueba del resumen para push en verde.

### RC-4 · Mostrarlo: «Para ti» en el inicio, la ficha y el arranque en frío

**Objetivo:** que la clienta vea el resultado.
**Tamaño:** L. **Agentes:** test-engineer → flutter-implementer, con aprobación visual de la persona. **Decisiones:** RD-2, RD-3, RD-4.

**Cambios:**
- **Inicio:**
  - `HomeSectionId.forYou` (`domain/home_content.dart:9`), con los nombres de cable `para_ti` y `for_you` en `fromWire`;
  - la regla de inserción de RD-2 en `_resolveSectionOrder` (`home_screen.dart:514`);
  - un riel que reutiliza el componente de novedades;
  - sólo aparece con `isConfident`, contando el `prior`;
  - el motivo según RD-3.
- **Ficha:** «Más de \<marca\>» (`product_screen.dart:273`) conserva el mismo conjunto, ordenado por la puntuación del perfil y no por el orden del catálogo.
- **Vistos recientemente (H9):** `_recentIds` se hidrata en el arranque desde los `productView` de Drift.
- **Arranque en frío (RD-4):** la bolsa y el buscador usan el respaldo acordado cuando el perfil no es confiable. El orden por GID desaparece.
- **Rendimiento (H13, R20):** `feed()` se memoriza con un contador de versión que cambia con el perfil, el catálogo, las vistas y los favoritos. El `build` del inicio deja de recalcular el ranking.
- **Diseño:** fondo blanco y barras grises, como en el resto de la app. Capturas de antes y después con el arnés de capturas; la persona aprueba la UI.

**Pruebas primero:**
- la sección aparece sólo con un perfil confiable;
- se respeta el orden de Shopify cuando la menciona;
- el motivo se pinta en español correcto;
- la escala de texto no desborda;
- `rank` se llama una sola vez en N reconstrucciones sin cambios;
- «Vistos recientemente» sobrevive al reinicio.

**Aceptación:** lo anterior, las pruebas de UI e INV-12 en verde, aprobación de la persona en el simulador y compilación Android e iOS (G6).

### RC-5 · Medición

**Objetivo:** saber si las recomendaciones venden, sin esperar a E8.
**Tamaño:** S. **Agente:** flutter-implementer. **Decisiones:** RD-6.

**Cambios:**
- En `product_telemetry.dart`, `ProductEvent.viewItemList` (`view_item_list`) y `ProductEvent.selectItem` (`select_item`) con:
  - `item_list_id`: `para_ti`, `bag_reco`, `search_discovery` o `more_from_brand`;
  - la posición.

  Sin datos personales ni tokens (invariante 3). Respeta `TELEMETRY_ENABLED`. Si `logProductEvent` no acepta parámetros, se amplía de forma aditiva.
- `_rec_source` no se toca: sigue en RF-67, que depende de E8. Nota para E8: el atributo es del carrito entero, así que un carrito con productos de varios orígenes necesita una regla, por ejemplo el último toque.

**Pruebas primero:** se envía el evento con su `item_list_id`; con la telemetría apagada no se envía nada.

### RC-6 · Higiene del historial

**Objetivo:** que el arranque no crezca con el uso.
**Tamaño:** S. **Agente:** flutter-implementer. **Decisiones:** RD-7.

**Cambios:**
- Al hidratar, borrar los eventos con más de 80 días y aplicar el tope de filas.
- `all()` lee sólo la ventana.
- Sin cambio de esquema (invariante 2). Actualizar el README.
- Efecto conocido: una vista de hace más de 80 días deja de contar como «ya visto».

**Pruebas primero:** con el mismo `now`, el perfil antes y después de podar es idéntico; el tope conserva los eventos más recientes.

## 6. Filas propuestas para la matriz

Son propuestas. Si el trabajo pasa a la cadena del refactor, el orquestador asigna los IDs definitivos.

| ID propuesto | Qué verifica | Paquete |
|---|---|---|
| RECO-01 | Perfil: decaimiento, permanencia, tope, negativos, normalización, `facetHint` ponderado | RC-1, RC-2 |
| RECO-02 | Explicador: prioridad y concordancia | RC-1 |
| RECO-03 | Compra: un evento por recibo y exclusión del feed | RC-2 |
| RECO-04 | Filtros y búsqueda enseñan facetas | RC-2 |
| RECO-05 | Preferencias declaradas: persistencia, mezcla y alcance por cuenta | RC-3 |
| RECO-06 | Inicio «Para ti»: visibilidad, orden y motivo | RC-4 |
| RECO-07 | `feed()` memorizado (PERF) | RC-4 |
| RECO-08 | Poda sin cambio de perfil | RC-6 |

## 7. Invariantes que toca

| Invariante | Paquete | Cómo se protege |
|---|---|---|
| 2 · Base local | RC-2, RC-6 | Sin cambio de esquema. `EventType` sólo crece, nunca se renombra (RC-1) |
| 3 · Credenciales | RC-5 | Analytics sin datos personales ni tokens |
| 4 · Bolsa | RC-2 | `applyPurchase` sigue idempotente dentro de su transacción. El evento depende del recibo nuevo. INV-01 |
| 9 · Cambio de cuenta | RC-3 | El `prior` se reasigna por alcance y se descarta una lectura tardía |
| 10 · Catálogo externo | — | `mixedFeed` no se usa ni se revive |
| 11 · Atribución | RC-5 | No cambia; `_rec_source` sigue en RF-67 |
| 13 · Pureza | RC-1, RC-2, RC-3 | La lógica nueva va en `lib/reco` sin importar Flutter. INV-12 |

## 8. Fuera de alcance

- Filtrado colaborativo o ranking en el servidor. Es la fase 2 del README.
- Sincronizar eventos entre dispositivos. `ACCOUNTS_AND_SYNC_PLAN.md` §4 lo pospone a propósito.
- Registrar impresiones al hacer scroll.
- `_rec_source` y `_campaign` (E8, RF-67).
- Retirar el catálogo externo de `main` (RF-20).

## 9. Riesgos

- **Choque con RF-50.** Se mitiga con la lógica en `lib/reco`, el cableado delgado y la integración de `main` antes de RF-50.
- **Burbuja de gustos.** El tope de dos productos seguidos de la misma marca se queda, y RC-1 lo fija con una prueba.
- **Privacidad.** Las compras pasan a influir en el resumen opcional para push (RD-8). El aviso de privacidad debe decirlo.
- **Lo que sólo puede verificar la persona:** la aprobación visual de RC-4, la prueba en simulador o dispositivo y la decisión de fusionar cada PR.
