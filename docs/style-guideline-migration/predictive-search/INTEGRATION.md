# Integración del buscador predictivo — paquete D

Entrega independiente para Claude. No se modificaron la cabecera, el layout, la página de búsqueda, los tokens, los assets compartidos ni los archivos del agente de contenido. La rama sigue siendo `refactor/rf-17-tipografia`; no se hicieron commits, worktrees, publicaciones ni cambios remotos.

No se encontraron archivos `AGENTS.md` en el repositorio ni en sus directorios ascendientes durante la inspección. Se leyeron el plan de migración, las secciones actuales, `monetta-core.js`, `monetta-listing.js`, los tokens y la implementación predictiva heredada de Atelier.

## Archivos de producción

| Archivo dentro de `storefront-theme/` | Función |
| --- | --- |
| `snippets/monetta-predictive-search.liquid` | Formulario GET y estructura accesible reutilizable. |
| `snippets/monetta-predictive-copy.liquid` | Textos propios del componente: español e inglés. |
| `sections/monetta-predictive-search.liquid` | Sección autónoma configurable. |
| `sections/monetta-predictive-results.liquid` | Fragmento HTML que renderiza la API con productos reales. |
| `assets/monetta-predictive-search.js` | Peticiones, estados, teclado, historial y geometría del panel. |
| `assets/monetta-predictive-search.css` | Estilos limitados al componente y a su sección autónoma. |

Los seis archivos deben estar en el mismo tema cuando se integre. La sección de respuesta no se agrega a una plantilla ni se renderiza estáticamente: Shopify la resuelve mediante `section_id=monetta-predictive-results`.

## Cambio mínimo en la cabecera

En `sections/monetta-header.liquid`, sustituir únicamente el formulario completo con clase `header-search` por:

```liquid
<div class="header-search">
  {% render 'monetta-predictive-search',
    instance_id: 'monetta-header-search',
    input_id: 'header-search-input',
    placeholder: section.settings.search_placeholder,
    hide_label: true
  %}
</div>
```

El contenedor conserva las reglas existentes de visibilidad, ancho y posición en la cuadrícula. Los enlaces móviles hacia `routes.search_url` pueden mantenerse. No anidar el snippet en otro formulario.

## Cambio mínimo en la página de búsqueda

En `sections/monetta-search.liquid`, sustituir únicamente el formulario completo con clase `search-page__field` por:

```liquid
<div class="search-page__field">
  {% render 'monetta-predictive-search',
    instance_id: 'monetta-page-search',
    input_id: 'page-search-input',
    placeholder: section.settings.placeholder,
    search_autofocus: true
  %}
</div>
```

Conservar el resto de la sección, el h1, resultados paginados, filtros, ordenamiento y enlaces de edición. El campo se inicializa desde `search.terms`.

## Uso autónomo y parámetros

La sección **Monetta · Predictivo** aparece como preset del editor. Puede añadirse a una plantilla JSON compatible sin depender de las secciones actuales de cabecera o búsqueda. Usa los tokens que ya carga `layout/monetta.liquid`. No carga el sistema de componentes o estilos de Atelier.

```liquid
{% render 'monetta-predictive-search',
  instance_id: 'footer-discovery',
  limit: 6,
  recent_limit: 5
%}
```

`instance_id` debe ser único por render, también sin JavaScript. `input_id` permite conservar un identificador existente; por defecto se deriva de `instance_id`. El JavaScript asigna identificadores únicos por conexión al listbox, instrucciones y opciones.

| Parámetro | Predeterminado | Uso |
| --- | --- | --- |
| `instance_id` | ID de sección como respaldo | Proporcionar un prefijo único en llamadas compartidas. |
| `input_id` | `<instance_id>-input` | Conservar los IDs indicados arriba para los enlaces de edición actuales. |
| `placeholder` | Texto según idioma | El texto del comerciante se escapa y marca con el idioma de la tienda. |
| `hide_label` | `false` | Oculta visualmente la etiqueta, conservando su asociación. |
| `search_autofocus` | `false` | Emite el hook actual; no instala otro manejador de autofocus. |
| `limit` | `6` | Entre 1 y 10 productos. |
| `recent_limit` | `5` | Entre 0 y 10; 0 desactiva la lectura/escritura del historial de esa instancia. |
| `include_assets` | `true` | Usar `false` solo si estos assets ya se cargan en esa página. |

No se necesita modificar el layout para las dos sustituciones propuestas: el snippet carga CSS y módulo. Los módulos se ejecutan una vez por URL y el registro del elemento tiene otra guarda. La sección autónoma carga los assets por sí misma.

Si se usa en otro layout, ese layout debe proporcionar los tokens actuales de `monetta-tokens.css`. No se duplican ni redefinen tokens en este componente. El CSS sigue los cambios de sus valores; la adopción de nuevos roles visuales corresponde al trabajo de fundamentos.

## Contrato Shopify

GET al valor de `routes.predictive_search_url`, con:

```text
q=<consulta>
resources[type]=product
resources[limit]=<1..10>
resources[limit_scope]=each
resources[options][unavailable_products]=last
section_id=monetta-predictive-results
```

El formulario GET usa `routes.search_url`, `q`, `type=product` y `options[prefix]=last`. “Ver todos los resultados” genera la misma consulta y permite continuar durante carga, vacío o error. Enter sin selección conserva el envío nativo. Los enlaces conservan exactamente `product.url`, incluidos los parámetros de variante/búsqueda que devuelva Shopify.

Liquid genera imágenes de `product.featured_media.preview_image`, con respaldo en `product.featured_image`, y un marcador decorativo si no hay imagen. Título escapado, precio Shopify con `money_with_currency` y “Desde” si varía el precio. No se reconstruyen handles, monedas, precios ni URLs de producto en JavaScript. Con varios precios se muestra el mínimo real del producto; no se presenta como una cotización de la variante concreta sugerida.

La petición conserva credenciales de mismo origen y la ruta de idioma de Shopify. La UI admite español e inglés; otros idiomas reciben UI española marcada `lang="es"` y conservan el locale de las rutas y el contenido Shopify. Se puede ampliar el snippet de copy sin editar locales compartidos.

Referencias: [API Predictive Search: respuesta HTML](https://shopify.dev/docs/api/ajax/reference/predictive-search), [guía oficial para temas](https://shopify.dev/docs/storefronts/themes/navigation-search/search/predictive-search). Los errores de idioma, límites de peticiones y secciones ausentes mantienen disponible el GET.

## Compatibilidad con los manejadores actuales

- **Borrado:** no se usan `.search-field` ni `data-search-clear`; `watchSearchClear()` no se conecta al componente. Borrar emite un único evento `input`.
- **Edición y autofocus:** se conservan `header-search-input`, `page-search-input` y `data-search-autofocus`. `monetta-listing.js` controla edición/foco inicial. El componente detecta si ya estaba enfocado al registrarse.
- **Escritura:** los eventos de foco se propagan para `watchTyping()`.
- **Diálogos:** el primer Escape cierra sugerencias y conserva la consulta. El siguiente solicita cierre nativo con `requestClose()` o un único `cancel` de respaldo, dejando que `monetta-core.js` aplique transición, desbloqueo y foco. Se atienden `monetta:dialog-close` y `close`.
- **Editor y reemplazos:** al conectar se instalan manejadores por instancia; al desconectar se cancelan peticiones, temporizadores, listeners y observadores. No hace falta otro inicializador de secciones ni editar `Monetta`.
- **Anuncios:** cada instancia tiene su propio `role="status"`. No se llama también a `Monetta.announce`.

## Interacción y persistencia

Espera de 220 ms, cancelación inmediata al cambiar la consulta y comprobación de generación incluso si una respuesta ignora el aborto. Una petición detenida pasa a error después de 8 segundos. IME espera a terminar la composición.

Flechas arriba/abajo recorren opciones con el foco en el combobox. Enter abre solo la opción seleccionada. Tab conserva el recorrido nativo. Escape, cierre, foco exterior y puntero exterior cierran y cancelan trabajo pendiente. Borrar conserva el foco.

El historial guarda consultas confirmadas por envío o selección de un destino. La clave empieza con `monetta:predictive:recent:v1:` e incluye ruta de búsqueda, locale, país y moneda. Se deduplica, limita y renderiza como texto. Si el almacenamiento está bloqueado o lleno, funciona en memoria durante la vida del documento. “Borrar historial” borra ese ámbito, sin modificar otras claves.

El panel usa geometría del campo y viewport visual, responde a resize/scroll y puede colocarse arriba. En móvil ocupa el ancho disponible con márgenes; en tablet/desktop queda anclado y contenido en el viewport. Nombres y acciones envuelven texto; el panel puede desplazarse.

## Pendiente de integración

La entrega está lista para esas sustituciones; no se ha subido a una tienda. Revisar en un tema no publicado el render Liquid real, rutas/mercados, catálogo/variantes, moneda, Theme Editor y cabecera final. Los navegadores, dispositivos y lectores de pantalla pendientes se detallan en [VALIDATION.md](VALIDATION.md).

Evitar un ancestro con transformaciones, `contain: paint` o clipping que cree otro bloque de contención para elementos fixed. Los contenedores actuales propuestos no requieren ese tratamiento; si los fundamentos introducen uno, revisar el panel junto con ese cambio.
