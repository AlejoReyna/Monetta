Corrige la primera entrega del tema Shopify de Monetta a partir de la auditoría independiente de Codex. Implementa las correcciones, compruébalas y documenta el resultado; no te detengas en un plan.

Repositorio: `/Users/alexis_reyna/MyCode/Monetta`.

Lee primero:

- `docs/web-redesign/shopify-staging/audit-codex-2026-10-19/AUDITORIA.md`
- `docs/web-redesign/shopify-staging/audit-codex-2026-10-19/browser-evidence.json`
- `docs/web-redesign/shopify-staging/audit-codex-2026-10-19/reproduce.mjs`
- `docs/web-redesign/shopify-staging/ENTREGA.md`, `RUNS.md` y `THEME.env`.

El árbol auditado tenía 610 archivos y SHA-256 `a962cd92f8a480e199bf880714c3c85addf9e8e5c4eb179aaf7550cf10e5f0bf`. Es una referencia histórica: registra el estado actual y conserva cualquier cambio posterior de otra sesión.

Trabaja exclusivamente sobre `storefront-theme/`, los verificadores y la documentación de esta entrega. El único destino remoto es `monetta-staging.myshopify.com`, tema `192125304866`, nombre «Monetta Web F1 borrador sin publicar 2026-10-19», rol `unpublished`. Verifica el destino antes de editar: un proxy `theme dev` puede estar sincronizando los archivos. Usa el guardián existente para las subidas. No publiques, crees otro tema, cambies `THEME.env`, escribas en producción ni modifiques productos, inventario, descuentos, menús, aplicaciones o ajustes globales de la tienda. Conserva Flutter, backend, secretos y cambios ajenos. Sin commits ni push de Git.

Resuelve estos hallazgos en orden:

1. **P1: variante incorrecta durante una consulta pendiente o fallida.** En `monetta-product.js`, seleccionar Café y agregar antes de recibir la sección envía Rosa Blush; después de un 503, Café queda marcado y se sigue enviando Rosa Blush. Impide agregar o pagar mientras la selección no esté validada. Mantén coherentes opción, ID, precio, disponibilidad, URL y botones. Ante error, restaura un estado válido o exige reintento explícito. No basta con `aria-busy`, opacidad o bloqueo del puntero. Comprueba ambos botones de agregar y el pago acelerado. Prueba respuesta lenta, 503, desconexión, HTML inválido con estado 200 y cambios rápidos A→B→C con respuestas fuera de orden. Ninguna respuesta antigua debe sobrescribir la selección vigente.

2. **Checkout durante cambios de carrito.** Coordina incremento, decremento, eliminación y deshacer con las salidas a checkout. No debe enviarse checkout mientras una mutación esté pendiente o el estado resultante siga sin confirmar. Cubre botones de escritorio y móvil, envío por teclado y métodos acelerados cuando estén presentes. Libera el bloqueo tras éxito o recuperación comprobada. La auditoría confirmó el envío prematuro en un documento de prueba; no demostró qué operación procesaría primero Shopify en un checkout real. Mantén esa distinción en el informe.

3. **Selección sin JavaScript.** Actualmente los radios cambian visualmente, pero `name="id"` conserva la variante inicial. Implementa un selector o navegación nativa que permita comprar exactamente la variante elegida. Evita controles que aparenten cambiar una opción sin cambiar lo que se envía. Verifica con JavaScript realmente deshabilitado: variante inicial, cambio a otra disponible y variante agotada.

4. **Datos estructurados.** Restaura en la ficha el marcado que emitía Atelier usando los datos y el filtro nativo de Shopify. Comprueba que el JSON-LD renderizado sea válido y corresponda al producto, sus variantes y ofertas; acepta la estructura nativa pertinente, incluido `ProductGroup`. Conserva canonical y metadatos. No escribas precios, disponibilidad ni IDs comerciales fijos.

5. **Recuperación de paginación.** Tras fallar «Ver más piezas», el mensaje invita a usar el enlace, pero el manejador vuelve a interceptarlo. Ofrece navegación normal funcional o acciones distintas de reintento y navegación. Valida el HTML recibido antes de añadir productos o cambiar la URL. Prueba error, recuperación y navegación nativa; conserva filtros y orden.

6. **Editar búsqueda en móvil.** El enlace apunta a `#header-search-input`, oculto en teléfono. Dirígelo al campo visible y comprueba el foco real y su visibilidad en una búsqueda sin resultados, con ratón y teclado, en móvil y escritorio.

7. **Identidad de línea al deshacer.** Conserva cantidad, propiedades públicas y privadas y `selling_plan` cuando exista. No restaures una línea personalizada como otra compra de la misma variante. Usa datos controlados para propiedades y planes que no existan en staging; no crees configuraciones comerciales para probarlo ni afirmes haber probado suscripciones reales. Si Shopify rechaza restaurar la línea, presenta el error sin sustituirla silenciosamente.

8. **Idioma declarado.** Alinea el idioma principal declarado con la interfaz española sin cambiar la configuración global de la tienda ni ampliar el alcance a una plataforma multilingüe. Comprueba el HTML de las páginas portadas. Un resultado positivo de axe no demuestra que `lang` coincida con el contenido.

9. **Verificadores y clasificación de fallos.** Elimina la atribución automática de todos los errores a infraestructura en `runs-index.mjs`. Registra causa y evidencia por fallo; si no está determinada, indícalo. Enlaza los reintentos con lo que realmente repiten. Un control negativo solo cuenta como detectado cuando falla la aserción específica esperada; un timeout, una página de error o una ejecución incompleta no bastan. Corrige también `busy || adds.length === 1`: el estado de espera y la ausencia de peticiones duplicadas deben comprobarse por separado, reteniendo la respuesta para observar el estado pendiente.

Además, `baseline/themes-before.json` contiene una etiqueta de herramienta antes del JSON. Conserva el original y genera una copia normalizada validada, con procedencia documentada. No reemplaces el «antes» histórico por una consulta actual.

La verificación debe demostrar las correcciones:

- Guarda reproducciones previas y posteriores en una carpeta nueva. Conserva intacta la auditoría de Codex y los resultados originales. Puedes adaptar selectores en pruebas nuevas, pero no debilitar las aserciones para obtener resultados verdes.
- Añade regresiones de las causas anteriores y controles normales de éxito. Usa intercepción de red para latencia, errores y respuestas fuera de orden. No reintentes a ciegas un `POST /cart/add.js` cuyo resultado sea incierto.
- Conserva pruebas con datos reales en staging: recorrido, variante, cantidades e importes. Las escrituras de prueba deben limitarse a carritos anónimos; detente en la entrada al checkout, sin pedidos ni pagos. Distingue estos resultados de los obtenidos con documentos y respuestas controlados.
- Repite los recorridos de compra en 375×812, 440×956, 768×1024, 1024×768, 1440×900 y 812×375. Ejecuta las comprobaciones afectadas de maquetación, teclado, axe, movimiento y capturas, incluidos los insets. Revisa visualmente los estados modificados. Documenta la cobertura exacta; no atribuyas al código nuevo las pruebas históricas.
- Usa un solo proxy sano y comprobaciones de salud con esperas acotadas. Antes de emitir resultados verifica que se sirve el tema esperado. Clasifica los incidentes del proxy y conserva sus registros.
- Ejecuta Theme Check y compara los hallazgos individuales con la base, no solo los totales. La referencia heredada es 187 errores y 64 avisos; no debe haber hallazgos introducidos.
- Identifica cada ejecución nueva con comando, fecha, tienda, tema y hashes del tema y los verificadores. Descarga el borrador al terminar y compara su contenido con el local, separando las diferencias de formato JSON.

Actualiza `ENTREGA.md` y el índice generado con cifras verificadas, sin duplicar comprobaciones por los reintentos. No amplíes el trabajo a favoritos, quick view, páginas pendientes o sincronización app↔web. Avanza con las correcciones rutinarias sin pedir confirmaciones adicionales; si falta un acceso externo, completa lo independiente y deja explícitamente pendiente solo la comprobación que dependa de él.

Entrega una relación hallazgo→corrección→prueba→resultado, los archivos cambiados, las limitaciones reales y la equivalencia local/remoto. No declares cerrada la entrega si todavía puede enviarse una variante distinta de la seleccionada o continuar al checkout con una mutación sin resolver.
