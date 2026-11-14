# MONETTA · Documento maestro de UI v4.1

05/11/2026. Fuente editable completa. Diseño especificado; no implementación publicada.


# Lectura y decisiones


## 001. MONETTA · documento maestro de UI

Una sola especificación vigente para construir el sitio adaptable y la futura app iOS/Android. Corrección 5 final aplicada sobre los activos y pantallas existentes.

Esta versión sustituye v4.0 en diseño. No es un sitio publicado ni acredita servicios de pago o cuenta.


## 002. Índice navegable

Capítulos, marcadores y fichas con IDs estables. Las vistas son páginas, tramos de desplazamiento, paneles o estados del mismo recorrido.

- Lectura y decisiones: 1–5

- Sistema y componentes: 6–11

- Pantallas · distribución y conducta: 12–64

- Adaptación por dispositivo: 65–70

- Banners y fotografías · catálogo de activos: 71–90

- Datos, accesibilidad y aceptación: 91–110

- Auditoría y entrega a desarrollo: 111–117


## 003. Alcance y autoridad

El diseño solicitado está definido aquí. Los datos y servicios necesarios se conectan al implementar; una maqueta no demuestra operación.

### CONFIRMADO

Instrucciones expresas del usuario: identidad, orden de páginas, oro #A58248, halo C, envío gratis con cuenta, corazones vigentes y agotado compacto negro/blanco, retiro de ajustes de accesibilidad. Se conservan las decisiones previas no sustituidas.

### PROPUESTO

Geometrías, tiempos y adaptación de la composición a cada ancho. Se especifican como punto de implementación; requieren medición en pantallas reales. No equivalen a nueva política o integración.

### PENDIENTE

Bindings de rutas, grupos y redes; reglas de cashback/bonos y apartados; modalidad de cuenta/proveedores; fecha comercial de Nuevo. Ocultar capacidades sin respaldo, sin botones inertes.

### OBSERVADO · 05/11/2026

Corrección5 de113páginas:122 marcas revisadas en17páginas; se reutilizan las32composiciones de banner y los activos vigentes de la entrega4.0. Esta revisión observa archivos locales.

### Prioridad vigente

Nueva instrucción y Corrección 5 → v4.0 donde no cambia → materiales originales vigentes. Staging refleja implementación, no aprueba por sí solo una intención de diseño. No se modificó producción ni se probó checkout.

### Cómo usar la entrega

Leer este PDF y el catálogo JSON; abrir la presentación navegable para comparar modelos. Elegir activos por ID y manifiesto, no por nombres ambiguos. La IA recibe un inicio único con alcance y condiciones.


## 004. Decisiones que no deben reinterpretarse

Base vigente; elimina contradicciones de revisiones históricas.

| Tema | Decisión final | Consecuencia de UI |
| --- | --- | --- |
| Navegación | Inicio / Categorías / Carrito / Cuenta; invitado puede comprar. | Categorías y Marcas separadas; sin Modo Mayoreo, Compartir catálogo o Pausar visible. |
| Envío | Gratis requiere cuenta autenticada reconocida por checkout. | Invitado conserva compra con tarifa real. Retirar la nota marcada en producto no cambia esta condición. |
| Inicio | Nueva colección → Lo más buscado → Para ti → Mayoreo único → servicios → registro → pie. | Tres banners arriba, luego Categorías y Marcas. Agregar pequeño solo dentro del feed Para ti. |
| Activos | 32 composiciones de banner; fotos de categorías solo en Inicio. | Otras páginas conservan iconos dorados. Logo y productos no se reconstruyen ni retocan. |
| Accesibilidad | Se retira la pantalla propia de ajustes, se conserva la accesibilidad base. | Respetar movimiento del sistema, foco/teclado, lectura, zoom y superficie opaca de respaldo. |
| Autoplay | 3 s de producto y 4 s de historias solicitados; control externo aún pendiente. | Modo manual hasta resolver control persistente accesible fuera de la tarjeta; nunca botón Pausar en el producto. |


## 005. Mapa de recorridos y accesos

Los IDs identifican contratos. Resolver rutas y enlaces por entorno; no crear URLs a partir del nombre de un archivo.


# Sistema y componentes


## 006. Identidad y material · Glass ligero

Colores y dirección confirmados. Medidas y capas numéricas propuestas; no sustituyen contraste, foco ni validación en el build.

### Superficies

Fondo blanco puro. Producto, formularios y texto sobre superficies estables. Glass en barra, controles y paneles; sombra corta y tenue, sin resplandor constante.

### Efecto confirmado

Halo C: oro al 18%, difusión 10 px y extensión 2 px como referencia recibida. Contorno interior se desvanece hacia centro transparente; no relleno dorado sólido.

### Tokens propuestos

Espaciado 4/8/12/16/24/32/48. Radios campo/botón 24–28; panel 20–26. Sombra 0 2px 8px negro 5%; material de respaldo opaco blanco.

### Tipos y activos

Logotipo oficial intacto. Cormorant 400/700 editorial; DM Sans 400/600/700 UI. La tipografía de los banners se conserva delineada desde el PDF; no se simula con otra fuente.


## 007. Botones, campos, iconos y foco

Una acción clara por control. Icono pequeño y área táctil amplia son propiedades diferentes; no añadir contenedores por inferencia.

### Botón primario

Halo C según jerarquía, etiqueta concreta y respuesta real. Presionado/carga/error/éxito accesibles. No usar brillo para indicar por sí solo un estado.

### Campo

Etiqueta persistente programática, ayuda/error junto al campo. Sin línea interior decorativa. Teclado correcto y retorno conservan el valor; contenido largo no corta el control.

### Iconografía

Categorías doradas en superficies internas. Redes del sidebar en círculos Glass con texto debajo. WhatsApp verde reconocible y libre junto al botón; mismo vector en todas las instancias.

### Teclado y tamaño

Objetivo interno 48×48 CSS px en acciones principales. Foco oscuro 2 px y separación 3 px propuestos; sin solaparse con controles vecinos ni quedar bajo barra o teclado.


## 008. Tarjeta común · corazón y agotado corregidos

Las nuevas apariencias sustituyen las versiones anteriores en todos los modelos. La disponibilidad continúa definida por variante.

### Favorito sin contenedor

Corazón más ancho y firme; 24 px y trazo 2.6 px propuestos. Guardado: contorno y relleno oro dentro de la silueta. Área transparente 48 px, foco visible y estado aria-pressed.

### AGOTADO

Etiqueta mucho más pequeña, fondo negro y texto blanco, situada más abajo junto al borde inferior de la foto. Sin brillo ni animación. Es estado, no botón; reposición solo en PDP de esa variante.

### Datos consistentes

Foto, precio y disponibilidad corresponden a la variante activa. Galería cambia fotos de la misma variante; color cambia variante sin navegar. Sin círculos falsos si no hay opciones.

### Rutas de la tarjeta

Común → vista rápida → imagen/PDP; destacado Nueva colección → PDP directo. Corazón y color son acciones independientes. Comparación/precio/% solo con valores válidos.


## 009. Carruseles, filtros y capas

Patrones comunes para Inicio, producto, marcas y colecciones; no duplicar elementos para simular catálogo.

### Carrusel

Al menos 40 productos únicos si existen; carga progresiva. Flecha Glass libre al final y nombre del destino debajo. Título/Ver todo da acceso textual inmediato sin recorrer 40.

### Chip aplicado

Muestra a izquierda y X más próxima a la orilla; márgenes equilibrados. Toda la cápsula puede ser un botón Quitar filtro X, evitando botones anidados; si se separa la X, objetivos disjuntos.

### Modal / drawer

Título y X, Escape/atrás, fondo inerte, foco contenido y devuelto al disparador. La capa superior cierra primero. Si origen desaparece, foco al encabezado de su lista.

### Vacío y error

Mensaje y acción centrados en área útil. Error de red conserva consulta; no equivale a cero resultados. No forzar alturas que corten texto al ampliar o abrir el teclado.


## 010. Barra y carrito · oro sin relleno

El contador suma unidades; el oro depende de elegibilidad real de mayoreo, no del número dibujado en el ejemplo.

### Estado confirmado

Tres piezas elegibles: icono oro y aro interior tenue; centro transparente. Badge oro con número negro. Aviso mayoreo durante 4 s. Al bajar del umbral, recalcular y retirar oro.

### Movimiento propuesto

Agregado confirmado → gota → transición de color 320 ms + asentamiento 360 ms/2 px. Solo una vez por nueva operación; no en carga, regreso o recarga. Movimiento reducido: estado final y anuncio textual.

### Iniciar sesión

En invitado, Iniciar sesión recibe el halo. Continuar como invitado neutral. Autenticar conserva líneas y vuelve al carrito/entrega con envío/total recalculados.

### Regla real

Catálogo conserva precio público. Descuento en carrito mediante regla autoritativa; no simularlo en JavaScript. No duplicar agregado por pulsaciones rápidas ni abrir carrito automáticamente.


## 011. Pago y Rewards · lenguaje del movimiento

Especificación de animación, no prueba de pago. Se distingue espera, rechazo, resultado desconocido y confirmación.

### Círculo abierto

Arco de 290°, apertura visible permanente y giro 900 ms lineal propuesto. Solo mientras se verifica. No termina por temporizador; error o resultado detiene el giro. Reduced motion: símbolo quieto + texto.

### X roja y check

X de extremos redondeados #A63535; dibujar dos trazos 180+180 ms y asentamiento 180 ms propuestos. Rechazo solo confirmado. Check verde de pago verificado; no por redirección/pedido creado. Al recargar, estático.

### Arco Rewards

270°, 18 px propuestos, extremos suaves y sombra exterior/interior ligera. Oro translúcido; destellos fríos muy breves solo durante progreso nuevo confirmado. Nunca brillo continuo ni aguja.

### Lectura persistente

Diez compras, 10 puntos por compra según propuesta recibida. Nivel actual/siguiente y conteo textual antes de ÉLITE. Al final solo ÉLITE/100% dentro, saldo y acciones suben; total real accesible programáticamente.


# Pantallas · distribución y conducta


## 012. Inicio

UI:G01 · Presentar la boutique y dirigir al catálogo sin obligar a registrarse.

### Entrada
Logo, Inicio en navegación o entrada directa a la tienda.

### Elementos
1. Registro: Regístrate en MONETTA REWARDS en negro; ENVÍO GRATIS en oro + para siempre negro; GANA CASHBACK verde + con cada compra negro. Cada texto en una línea al tamaño base; botón con halo oro. A zoom/reflow se permite crecer sin cortar. Pie gris muy tenue: Contacto, Envíos, Cambios y devoluciones, Mayoreo, Privacidad y Términos vigentes. Retirar Buscar del pie.
2. Cabecera y tres banners, en orden: todos los productos (B01), todas las marcas (B02), todas las categorías (B03).
3. Carrusel de Categorías y carrusel separado de Marcas; títulos enlazados y cierre Glass para su conjunto real.
4. Nueva colección: tarjeta de producto grande y carrusel inferior de al menos 40 productos únicos si existen.
5. Lo más buscado → Para ti (feed de productos) → un único banner Mayoreo B04 con CTA superpuesto Comenzar a vender.
6. Servicios → registro con correo → pie mínimo; conservar copy recibido y su regla real.
7. Barra móvil Inicio / Categorías / Carrito / Cuenta; espacio inferior y safe areas reservados.

### Acciones
- Banner 1 / 2 / 3; Categorías / Marcas → Abrir respectivamente catálogo / marcas / categorías, con binding válido → UI:G05 / UI:G04 / UI:G03 según acceso
- Miniatura / destacado de Nueva colección → Cambiar destacado sin navegar / abrir PDP con variante seleccionada → Mismo bloque / UI:G10
- Comenzar a vender / Registrarme → Abrir Mayoreo / iniciar el acceso real con correo validado → UI:G13 / UI:G17

### Estados
Carga de imágenes con dimensiones reservadas · Visitante sin historial: selección editorial · Contenido ausente: conservar los bloques válidos · Registro: carga / error con correo conservado / éxito real

### Adaptación
Móvil: Una columna; hero a lo ancho; carruseles horizontales y barra inferior.; Tablet: Mismo orden; redistribuir tarjetas según ancho, sin escalar todo.; Escritorio: Cabecera; secciones más anchas con lectura controlada, sin duplicar barra móvil.; css_320: Una columna; hero a lo ancho; carruseles horizontales y barra inferior. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Mismo orden; redistribuir tarjetas según ancho, sin escalar todo. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Cabecera; secciones más anchas con lectura controlada, sin duplicar barra móvil. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- Los tres banners abren productos, marcas y categorías, respectivamente.
- El orden Nueva colección → Lo más buscado → Para ti → Mayoreo → servicios → registro → pie es idéntico en 320, 768 y 1440 CSS px.
- Solo hay un banner Mayoreo inferior, con Comenzar a vender; registro valida y conserva el correo ante fallo.
- Sin historial no se afirma personalización; no se duplican productos ni se insertan imágenes de relleno.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.
- Cotejar Corrección5: Registro: Regístrate en MONETTA REWARDS en negro; ENVÍO GRATIS en oro + para siempre negro; GANA CASHBACK verde + con cada compra negro. Cada texto en una línea al tamaño base; botón con halo oro. A zoom/reflow se permite crecer sin cortar. Pie gris muy tenue: Contacto, Envíos, Cambios y devoluciones, Mayoreo, Privacidad y Términos vigentes. Retirar Buscar del pie.

### Dependencias
Envío gratis con cuenta confirmado; activar cashback solo con reglas e integración; Autoplay accesible; CMS y cuenta compatibles

### Precisiones
- Orden completo obligatorio; Para ti no reemplaza el título Lo más buscado.
- Servicios recibidos: ENVÍO GRATIS / 5 - 7 días hábiles; Producto Original / Importado desde E.U.A.; MSI solo donde esté vigente. Conservar su procedencia; no convertirlos en nuevas garantías.
- Sin historial: selección editorial. Imágenes vinculadas a contenido social: selección manual inicial; automatización solo con integración verificada.
- Rotación solicitada de 3 s (productos) / 4 s (historias) pendiente de un control accesible aprobado fuera de la tarjeta. No botón de pausa en la tarjeta. Mientras se resuelve, navegación manual; movimiento reducido del sistema siempre respetado.
- Envío gratis requiere cuenta autenticada reconocida por checkout. Invitado puede comprar con tarifa real según dirección; nunca inventar importe ni sustituir un cargo por cero visual.
- CONFIRMADO C5 salvo las interpretaciones marcadas PROPUESTO: Registro: Regístrate en MONETTA REWARDS en negro; ENVÍO GRATIS en oro + para siempre negro; GANA CASHBACK verde + con cada compra negro. Cada texto en una línea al tamaño base; botón con halo oro. A zoom/reflow se permite crecer sin cortar. Pie gris muy tenue: Contacto, Envíos, Cambios y devoluciones, Mayoreo, Privacidad y Términos vigentes. Retirar Buscar del pie.

### Datos
Activos y destinos editoriales; Productos/variantes reales; Selección social manual; Registro compatible

### App futura
Mismos bloques y destinos; adaptar navegación del sistema y áreas seguras.


## 013. Inicio · Nueva colección

UI:G01-A · Seleccionar un producto del carrusel y abrir su ficha completa.

### Entrada
Desde UI:G01; conservar disparador, consulta, variante y posición aplicables.

### Elementos
1. PROPUESTO por los dos trazos laterales de p13: controles Anterior/Siguiente sobre el área libre del destacado; no Pausar ni reactivar autoplay.
2. Título y acceso textual a toda Nueva colección.
3. Tarjeta grande: fotografía y favorito sin contenedor. Recién llegado lleva halo C y sigue siendo etiqueta condicional.
4. Marca/nombre a la izquierda; precio actual, comparación válida y porcentaje a la derecha.
5. Carrusel inferior con 40 productos únicos si existen; selección visible.
6. Al final: flecha Glass libre y Ver Nueva colección debajo, sin tarjeta grande.

### Acciones
- Miniatura → Cambiar producto destacado y todos sus datos; conservar contexto → Mismo bloque
- Tarjeta grande → Abrir PDP de la variante activa directamente → UI:G10
- Título / cierre Ver Nueva colección → Abrir colección configurada sin recorrer todas las miniaturas → UI:G05

### Estados
Sin duplicados para completar cantidad. · Sin fecha válida, ocultar Recién llegado. · Manual hasta resolver rotación accesible de 3 s.

### Adaptación
Móvil: Una columna; mantener orden y áreas seguras.; Tablet: Redistribuir con espacio real, sin duplicar controles.; Escritorio: Redistribuir con espacio real, sin duplicar controles.; css_320: Una columna; mantener orden y áreas seguras. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Redistribuir con espacio real, sin duplicar controles. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Redistribuir con espacio real, sin duplicar controles. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- La tarjeta grande es una tarjeta de producto completa, sin botón de pausa ni imagen adicional de relleno.
- Las miniaturas muestran hasta el conjunto real con al menos 40 únicos si existen; su selección y el destacado comparten variante/precio/fotos.
- El cierre es flecha Glass libre con Ver Nueva colección debajo, un solo enlace.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.
- Cotejar Corrección5: PROPUESTO por los dos trazos laterales de p13: controles Anterior/Siguiente sobre el área libre del destacado; no Pausar ni reactivar autoplay.

### Dependencias
Fecha de alta definida; Colección real

### Precisiones
- Corazón libre sin contenedor visible, geometría de 24 px y trazo 2.6; guardado con contorno e interior de la silueta dorados #A58248. Área transparente de 48 px, foco y estado accesibles; acción independiente.
- Rotación solicitada de 3 s (productos) / 4 s (historias) pendiente de un control accesible aprobado fuera de la tarjeta. No botón de pausa en la tarjeta. Mientras se resuelve, navegación manual; movimiento reducido del sistema siempre respetado.
- CONFIRMADO C5 salvo las interpretaciones marcadas PROPUESTO: PROPUESTO por los dos trazos laterales de p13: controles Anterior/Siguiente sobre el área libre del destacado; no Pausar ni reactivar autoplay.


## 014. Inicio · Lo más buscado, Para ti y Mayoreo

UI:G01-B · Continuar el recorrido editorial sin imágenes ni textos de relleno.

### Entrada
Desde UI:G01; conservar disparador, consulta, variante y posición aplicables.

### Elementos
1. Lo más buscado continúa inmediatamente después de Nueva colección, conservando su título propio.
2. Para ti: feed/acordeón horizontal de productos después de Lo más buscado, editorial si no existe historial autorizado.
3. Panel activo: foto completa; marca centrada con mayor jerarquía que el nombre; nombre y precio centrados.
4. Corazón libre arriba; solo en este feed, Agregar pequeño Glass abajo a la derecha de la foto sin tapar el producto.
5. Precio anterior y porcentaje verde solo con comparación válida; Comprar ahora usa la variante activa. Historias de tres imágenes si existe contenido editorial real.
6. Debajo de Para ti: único banner Mayoreo B04 con Comenzar a vender; siguen servicios, registro y pie.

### Acciones
- Panel / gesto / avance manual → Expandir panel elegido sin mezclar datos; las historias son de la variante/contenido definido → Misma sección
- Comprar ahora / Agregar pequeño → Comprar con variante válida / validar selección y esperar agregado real, gota y contador sin abrir carrito → UI:G15 / misma sección; UI:G35 si falta opción
- Comenzar a vender → Abrir Mayoreo conservando origen → UI:G13

### Estados
Cambio de panel no mezcla datos. · Sin autoplay de historias 4 s hasta alternativa accesible.

### Adaptación
Móvil: Una columna; mantener orden y áreas seguras.; Tablet: Redistribuir con espacio real, sin duplicar controles.; Escritorio: Redistribuir con espacio real, sin duplicar controles.; css_320: Una columna; mantener orden y áreas seguras. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Redistribuir con espacio real, sin duplicar controles. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Redistribuir con espacio real, sin duplicar controles. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- El feed se titula Para ti; Lo más buscado permanece anterior y no se renombra.
- Agregar superpuesto solo existe en el feed indicado y no tapa producto/favorito.
- El banner Mayoreo queda después de Para ti y antes de servicios, una sola vez.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.

### Dependencias
Selección editorial y activos; Datos de variante

### Precisiones
- Corazón libre sin contenedor visible, geometría de 24 px y trazo 2.6; guardado con contorno e interior de la silueta dorados #A58248. Área transparente de 48 px, foco y estado accesibles; acción independiente.
- Rotación solicitada de 3 s (productos) / 4 s (historias) pendiente de un control accesible aprobado fuera de la tarjeta. No botón de pausa en la tarjeta. Mientras se resuelve, navegación manual; movimiento reducido del sistema siempre respetado.


## 015. Menú lateral

UI:G02 · Reunir categorías, marcas y contacto sin introducir navegación alternativa de mayoreo.

### Entrada
Botón de menú en cabecera.

### Elementos
1. Cabecera invitado: acceso a cuenta y X. Autenticado: avatar Glass con primera letra real, nombre y Miembro + nivel real; no fila Iniciar sesión.
2. Saldo en dos líneas: Saldo pequeño alineado al inicio del importe real verde, sin ejemplo monetario hardcodeado.
3. Categorías en jerarquía vigente; Marcas en agrupación separada.
4. Después de todas las marcas: Mayoreo con icono y etiqueta, sin flecha.
5. Instagram, TikTok y Facebook: conjunto centrado; iconos oro tenue dentro de círculos Glass y nombres fuera debajo.
6. Contacto WhatsApp inferior: logo reconocible verde libre junto al control Glass, sin círculo externo nuevo.

### Acciones
- Avatar / acceso de invitado → Abrir Perfil autenticado / iniciar acceso sin perder página → UI:G26 / UI:G17
- Categoría / marca / Mayoreo → Expandir familia o abrir destino configurado → Mismo panel / UI:G05 / UI:G05-A / UI:G13
- WhatsApp / red social → Abrir canal autorizado sin enviar mensaje ni seguir automáticamente → EXT:whatsapp_direct / EXT:social_profile

### Estados
Abierto / cerrado · Familia expandida · Sesión invitada / autenticada · Destino no disponible

### Adaptación
Móvil: Panel desplazable; cierre y contacto alcanzables, sin tapar filas.; Tablet: Ancho moderado y mismo orden.; Escritorio: Panel de menú cuando corresponda; no duplicar todos sus controles en cabecera.; css_320: Panel desplazable; cierre y contacto alcanzables, sin tapar filas. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Ancho moderado y mismo orden. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Panel de menú cuando corresponda; no duplicar todos sus controles en cabecera. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- Última marca, Mayoreo y contacto alcanzables con teclado y 320 px.
- Invitado no ve nombre/saldo de una sesión anterior. Autenticado muestra el nivel real junto a Miembro.
- Cerrar conserva scroll/contexto y devuelve foco; redes forman un grupo centrado.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.

### Dependencias


### Precisiones
- Redes centradas según ancho útil del panel; no centrar todas las filas de categorías.
- Identidad, nivel y saldo solo desde servicio autorizado; carga o error no se convierten en PRO, saldo cero ni inicial desde correo.
- Si es modal: fondo inerte, foco contenido, X/Escape y retorno al botón de menú.

### Datos
Árbol de colecciones; Marcas; URLs sociales verificadas; Identidad autorizada

### App futura
Adaptar presentación modal y retroceso del sistema.


## 016. Categorías

UI:G03 · Mostrar las cinco familias con sus niveles, sin convertir estilos en familias.

### Entrada
Barra Categorías, banner de categorías, título/cierre del carrusel o menú.

### Elementos
1. Título Categorías
2. Bolsos → Carteras → Perfumes → Calzado → Accesorios
3. Subgrupos jerárquicos dentro de su familia, insertados en el flujo
4. Marcas separada de familias, continuando debajo según original

### Acciones
- Cabecera de familia → Expandir/cerrar en el flujo de la página → Misma pantalla
- Nodo de destino → Abrir su colección por ID configurado → UI:G05
- Marca → Abrir colección de marca → UI:G05

### Estados
Familias cerradas / expandida · Carga · Error de destinos con reintento

### Adaptación
Móvil: Filas verticales; subgrupos desplazan a las familias siguientes.; Tablet: Mismo árbol y orden; ampliar espacios sin apilar paneles.; Escritorio: Usar ancho de lectura cómodo; conservar jerarquía visual.; css_320: Filas verticales; subgrupos desplazan a las familias siguientes. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Mismo árbol y orden; ampliar espacios sin apilar paneles. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Usar ancho de lectura cómodo; conservar jerarquía visual. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- Todos los niveles abren el contenido correspondiente.
- Expandir no superpone contenido; texto 200% conserva nombres completos.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.

### Dependencias


### Precisiones
- Conservar árbol exacto y agrupación separada de marcas; no añadir Ver todas en la zona previamente eliminada.
- Una familia abierta a la vez es PROPUESTO; cualquiera que sea el patrón, subgrupos crecen en flujo sin superponer.
- Carteras de Hombre debe apuntar a carteras de hombre: corrección de errata PROPUESTA, binding final PENDIENTE.

### Datos
category_tree incluido en este archivo; IDs de colección y marcas

### App futura
Mismos nombres/IDs, retroceso conserva expansión.


## 017. Todas las marcas

UI:G04 · Explorar marcas como agrupación independiente.

### Entrada
Banner de marcas, título/cierre de carrusel o acceso de menú.

### Elementos
1. Título de marcas
2. Tarjetas blancas anchas con logos originales centrados
3. Continuación de marcas hasta la última configurada

### Acciones
- Tarjeta de marca → Abrir colección correspondiente → UI:G05

### Estados
Carga · Listado disponible · Sin marcas configuradas · Error / reintento

### Adaptación
Móvil: Lista vertical; apilado solo si mantiene acceso a todas las tarjetas.; Tablet: Tarjetas con tamaño legible; no recortar logos.; Escritorio: Ajustar ancho del conjunto sin deformar logos.; css_320: Lista vertical; apilado solo si mantiene acceso a todas las tarjetas. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Tarjetas con tamaño legible; no recortar logos. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Ajustar ancho del conjunto sin deformar logos. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- La tarjeta enfocada no queda oculta por otra.
- Todas las marcas configuradas son alcanzables y tienen nombre accesible.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.

### Dependencias


### Precisiones
- Marcas configuradas: Coach, Michael Kors, Guess, Steve Madden; añadir Kate Spade, Tory Burch y Marc Jacobs mediante la misma plantilla UI:G05-A cuando existan IDs/datos reales.
- No inventar orden de popularidad ni catálogo por disponer de un banner. Apilado al scroll es PROPUESTO y debe degradar a lista sin solapes con movimiento reducido.

### Datos
Logo oficial por marca; Nombre accesible; Orden editorial y destino

### App futura
Mismo catálogo; adaptar scroll y foco.


## 018. Colección y catálogo

UI:G05 · Listar todos los productos o una colección de familia, estilo o marca con el mismo patrón.

### Entrada
Banner productos, nodo de categoría/estilo, marca o cierre de carrusel.

### Elementos
1. Título contextual de categoría/marca pequeño y secundario; banner con sombra superior/inferior muy tenue, sin distorsionar la fotografía.
2. Título contextual
3. Banner/imagen vigente de la colección
4. Cápsula Buscar producto… con Ordenar y Filtros integrados
5. Conteo y selección aplicada cuando corresponda
6. Grilla de tarjetas comunes
7. Carga progresiva o paginación compatible

### Acciones
- Búsqueda / Filtros / Ordenar → Buscar dentro de colección / abrir su panel → UI:G05 / UI:G07 / UI:G08
- Cuerpo de tarjeta → Abrir vista rápida de variante activa → UI:G09
- Color / corazón → Actualizar variante / favorito sin navegar → Misma pantalla

### Estados
Carga con espacios reservados · Resultados · Cero resultados con limpiar · Error con consulta conservada · Carga adicional sin duplicados

### Adaptación
Móvil: Dos columnas si mantienen legibilidad; reducir antes de comprimir.; Tablet: Dos o tres columnas según contenido.; Escritorio: Tres o cuatro columnas; filtros laterales o panel con mismo contrato.; css_320: Dos columnas si mantienen legibilidad; reducir antes de comprimir. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Dos o tres columnas según contenido. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Tres o cuatro columnas; filtros laterales o panel con mismo contrato. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- Cada tarjeta muestra datos de una misma variante y conserva acciones independientes.
- La búsqueda local no incorpora productos ajenos a la colección.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.
- Cotejar Corrección5: Título contextual de categoría/marca pequeño y secundario; banner con sombra superior/inferior muy tenue, sin distorsionar la fotografía.

### Dependencias


### Precisiones
- No líneas bajo búsqueda antes, durante ni después de escribir.
- Ordenar y Filtros: trazos algo más gruesos y cercanos sin solaparse. Filtros son tres rayas horizontales centradas, de mayor a menor; Ordenar usa flechas más gruesas.
- Conservar consulta, filtros, orden y posición al volver.
- CONFIRMADO C5 salvo las interpretaciones marcadas PROPUESTO: Título contextual de categoría/marca pequeño y secundario; banner con sombra superior/inferior muy tenue, sin distorsionar la fotografía.

### Datos
Colección por ID; Productos y variantes; Opciones normalizadas de filtros; Orden disponible

### App futura
Mismo alcance de consulta y retorno de contexto.


## 019. Búsqueda global

UI:G06 · Buscar en todo el catálogo con un alcance diferente a la búsqueda local.

### Entrada
Lupa/búsqueda global en cabecera o Buscar del pie.

### Elementos
1. Cabecera o panel de búsqueda y cierre/retorno según contenedor
2. Campo Buscar productos… con etiqueta accesible
3. Conteo real de resultados
4. Tarjetas comunes de producto

### Acciones
- Escribir y confirmar búsqueda → Consultar catálogo global; ignorar respuestas antiguas → Misma pantalla
- Tarjeta / color / corazón → Vista rápida / selección / favorito según contrato común → UI:G09 / mismo resultado / misma tarjeta (guardar sin navegar)
- Volver de producto → Restituir consulta y posición → UI:G06

### Estados
Campo vacío · Buscando · Resultados · Sin resultados · Error conservando texto

### Adaptación
Móvil: Campo y resultados en una superficie que respete teclado y safe areas.; Tablet: Aprovechar espacio conservando alcance y orden.; Escritorio: Campo en cabecera y resultados con grilla común.; css_320: Campo y resultados en una superficie que respete teclado y safe areas. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Aprovechar espacio conservando alcance y orden. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Campo en cabecera y resultados con grilla común. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- Una búsqueda global y la misma búsqueda local tienen alcance correcto.
- Enter busca; fallo conserva la consulta y no se presenta como cero resultados.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.

### Dependencias


### Precisiones
- Sin subrayado ni línea de escritura; cápsula Glass reconocible y foco visible.
- No dibujar sugerencias personalizadas ni términos populares sin fuente.
- El tipo de contenedor se adapta al storefront: esta ficha no exige una ruta nueva.

### Datos
Consulta; Resultados globales; Precios/variantes reales

### App futura
Teclado y retroceso del sistema sin borrar consulta.


## 020. Filtros

UI:G07 · Elegir opciones reales y poder aplicarlas o cancelarlas sin ambigüedad.

### Entrada
Icono Filtros del listado de origen.

### Elementos
1. Título Filtros, contexto y cierre X.
2. Nombre y Marca dentro del alcance.
3. Categoría/Estilo con nodos aplicables.
4. Color: muestra de 20 px con contorno 1.5 px a la izquierda, separación 15 px al nombre (medidas propuestas) y marca de selección.
5. Recién llegados y Ofertas; Disponibles propuesto, apagados inicialmente.
6. Limpiar y Aplicar; grupos largos desplazables.

### Acciones
- Elegir opción / Limpiar → Modificar o vaciar borrador con selección accesible → Mismo panel
- Aplicar filtros → Confirmar selección y actualizar conteo → Listado de origen: UI:G05 / UI:G06 / UI:G05-A, conservando contexto
- X / Escape → Descartar borrador y devolver foco → Listado de origen: UI:G05 / UI:G06 / UI:G05-A, conservando contexto

### Estados
Selección vacía / aplicada / en edición · Opciones no disponibles · Consulta con cero resultados · Error

### Adaptación
Móvil: Panel modal con contenido desplazable y acciones alcanzables.; Tablet: Panel de ancho cómodo.; Escritorio: Panel o lateral; documentar el mismo momento de aplicación.; css_320: Panel modal con contenido desplazable y acciones alcanzables. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Panel de ancho cómodo. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Panel o lateral; documentar el mismo momento de aplicación. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- Cerrar sin aplicar conserva listado anterior.
- Aplicar anuncia conteo sin mover foco; selección puede retirarse y limpiarse.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.

### Dependencias


### Precisiones
- Mostrar solo valores presentes en todo el alcance, no deducir opciones de fotografías.
- Nombre es búsqueda local, no una categoría; Marca y Color son facetas independientes.
- Categoría cambia de nodo; Estilo usa metadatos reales del tipo de producto. No repetir todos los nombres como primer nivel.
- Seleccionado: aro interior oro tenue sin subrayado; estado programático. Muestra de color y nombre constituyen una opción.
- Recién llegados usa la misma fecha comercial y un mes; Ofertas requiere comparación válida por variante. Disponibles es PROPUESTO, apagado hasta decisión/datos.

### Datos
Opciones reales de marca/estilo/color; Selección aplicada y borrador; Conteo

### App futura
Retroceso cancela borrador de forma equivalente.


## 021. Filtros · nuevos, ofertas y disponibilidad

UI:G07-A · Continuación desplazable del mismo panel; opciones apagadas inicialmente.

### Entrada
Desde UI:G07; conservar disparador, consulta, variante y posición aplicables.

### Elementos
1. Color con muestra y nombre; un solo objetivo por opción.
2. Recién llegados: misma fecha comercial y regla de un mes que Nuevo.
3. Ofertas: comparación válida de la variante; no descuento de mayoreo supuesto.
4. Disponibles: filtro adicional PROPUESTO, apagado inicialmente; comprable no equivale a existencia física inmediata.
5. Seleccionar Nuevo y Ofertas significa la intersección, no alternar OR en silencio.
6. Limpiar y Aplicar siguen accesibles al final o en pie del panel.

### Acciones
- Cambiar control → editar borrador con estado programático → Mismo contexto según respuesta
- Aplicar → consultar todo el alcance y conservar contexto → Mismo contexto según respuesta
- X/Escape → descartar borrador y volver al origen → Mismo contexto según respuesta

### Estados
Fechas o datos faltantes no crean resultados. · Color+disponibilidad deben corresponder a una variante compatible.

### Adaptación
Móvil: Una columna; mantener orden y áreas seguras.; Tablet: Redistribuir con espacio real, sin duplicar controles.; Escritorio: Redistribuir con espacio real, sin duplicar controles.; css_320: Una columna; mantener orden y áreas seguras. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Redistribuir con espacio real, sin duplicar controles. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Redistribuir con espacio real, sin duplicar controles. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- Recién llegados y Nuevo comparten una fecha definida; Ofertas no incluye mayoreo visual.
- Color se reconoce por muestra y nombre; selección con estado accesible y aro tenue, sin subrayado.
- Intersección de filtros, limpieza y cancelación se comportan igual en el catálogo completo, no solo en página visible.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.

### Dependencias
Datos booleanos/indexación reales; Fecha comercial definida; Disponibles usa disponibilidad de venta; no promete stock físico ni entrega inmediata


## 022. Ordenar

UI:G08 · Cambiar el orden con opciones soportadas por la fuente de datos.

### Entrada
Icono Ordenar del listado de origen.

### Elementos
1. Título Ordenar y cierre.
2. Colección: más nuevos, más antiguos, los dos precios; Nombre A-Z propuesto.
3. Búsqueda global: relevancia y precios si usa Storefront search.
4. Selección única y Aplicar.

### Acciones
- Elegir orden → Aplicar o confirmar según patrón implementado, conservar filtros y consulta → UI:G05 / UI:G06
- Cerrar → Regresar al listado y devolver foco → Listado de origen

### Estados
Orden seleccionado · Cargando nuevo listado · Error con orden confirmado conservado

### Adaptación
Móvil: Panel compacto, sin tapar salida.; Tablet: Mismo contrato.; Escritorio: Popover o selector accesible junto a búsqueda local.; css_320: Panel compacto, sin tapar salida. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Mismo contrato. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Popover o selector accesible junto a búsqueda local. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- Más nuevos y Más antiguos usan campo de orden real compatible con el alcance; si el motor global no lo admite, no fingirlo.
- Nombre A-Z es PROPUESTO; Más vendidos requiere datos y decisión. Precios y relevancia solo donde soportados.
- Cambiar orden preserva consulta/filtros; paginación no duplica ni pierde resultados.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.

### Dependencias


### Precisiones
- No fingir que search admite CREATED/TITLE; motor alternativo requiere validación global y paginación.
- Más vendidos no se añade por defecto sin datos y decisión.
- Fecha de creación técnica puede diferir del alta comercial de Recién llegados.

### Datos
Opciones de orden del storefront; Orden activo

### App futura
Selector equivalente del sistema si corresponde.


## 023. Colección de una marca

UI:G05-A · Reutilizar el listado con pertenencia real a una marca.

### Entrada
Desde UI:G05; conservar disparador, consulta, variante y posición aplicables.

### Elementos
1. Hereda título contextual discreto y banner flotante de categoría; conserva marca y pertenencia reales.
2. Cabecera y nombre de marca real.
3. Banner correspondiente y logo original: B24 Guess; B25 Tory Burch; B26 Marc Jacobs; B27 Kate Spade; B28 Coach; B29 Michael Kors; B30 Steve Madden.
4. Buscar producto, Ordenar y Filtros como acciones independientes; sin líneas bajo campos.
5. Conteo real, chips aplicados y grilla de tarjeta común.
6. Solo productos de la marca consultada, con paginación/carga progresiva sin duplicados.

### Acciones
- Marca configurada → Consultar colección de esa marca por binding real → Misma plantilla
- Buscar / filtrar / ordenar → Consultar el alcance completo de la marca conservando contexto → UI:G07 / UI:G08 / mismo listado
- Tarjeta / color / corazón → Vista rápida / cambiar variante / guardar sin navegación → UI:G09 / misma tarjeta

### Estados
Vacío conserva consulta. · Error permite reintento. · Volver recupera contexto.

### Adaptación
Móvil: Una columna; mantener orden y áreas seguras.; Tablet: Redistribuir con espacio real, sin duplicar controles.; Escritorio: Redistribuir con espacio real, sin duplicar controles.; css_320: Una columna; mantener orden y áreas seguras. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Redistribuir con espacio real, sin duplicar controles. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Redistribuir con espacio real, sin duplicar controles. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- B26 es Marc Jacobs aunque el archivo original contenga TORY BURCH en el nombre; Tory usa B25.
- No se muestra inventario de otra marca como fallback ni se fabrican slugs.
- Vuelta de PDP restaura marca, consulta, filtros, orden y posición.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.
- Cotejar Corrección5: Hereda título contextual discreto y banner flotante de categoría; conserva marca y pertenencia reales.

### Dependencias
ID de marca/colección configurado

### Precisiones
- CONFIRMADO C5 salvo las interpretaciones marcadas PROPUESTO: Hereda título contextual discreto y banner flotante de categoría; conserva marca y pertenencia reales.


## 024. Información de mayoreo

UI:G13 · Presentar la guía de mayoreo con los activos y la distribución recibidos, distinguiendo contenido comercial de capacidad comprobada.

### Entrada
Banner Comenzar a vender de Inicio/Cuenta, menú Mayoreo o acceso configurado.

### Elementos
1. Título y descripción superpuestos en el banner también en móvil. Tres pasos uno al lado de otro en una única fila; en móvil se desplaza horizontalmente para conservar lectura, no se apilan. Mantener comunidad, botones, beneficios y continuación de las dos referencias.
2. Cabecera y hero Mayoreo B32 con copy exacto recibido.
3. ¿Cómo comprar?: tres pasos Elige tus productos → Agrega mínimo3 piezas → Liquida o aparta; iconos minimalistas coherentes, sin reproducir el peso/saturación de la referencia.
4. Comienza a vender: comunidad de emprendedores, contenido recibido y Grupo1 / Grupo2 solo con invitaciones reales.
5. Beneficios, con tres iconos y textos exactos recibidos.
6. ¿Tienes dudas? / Escríbenos por WhatsApp → Productos que te pueden interesar con tarjetas comunes y cierre.
7. Registro vigente de envío con cuenta → pie mínimo → barra móvil.

### Acciones
- Elegir productos / recomendación → Abrir catálogo / vista rápida con variante; no activar Modo Mayoreo → UI:G05 / UI:G09
- Grupo 1 / Grupo 2 → Abrir invitación configurada; confirmar unión dentro de WhatsApp → EXT:whatsapp_group_1 / EXT:whatsapp_group_2
- Escríbenos por WhatsApp / registro → Abrir canal sin enviar mensaje / acceso compatible → EXT:whatsapp_direct / UI:G17

### Estados
Contenido disponible · Carga · Error o enlace no disponible

### Adaptación
Móvil: Adaptar contenido vigente a lectura y tacto.; Tablet: Ancho legible.; Escritorio: Conservar contenido real sin prometer layout ajeno.; css_320: Adaptar contenido vigente a lectura y tacto. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Ancho legible. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Conservar contenido real sin prometer layout ajeno. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- Usa B32 y orden de secciones recibido; Inicio/Cuenta/menú llevan al mismo contenido.
- No se publican $800/20días/descuento automático u otras promesas sin confirmación y servicio; no se ejecutan descuentos en JS visual.
- Grupos sin invitación validada no aparecen como botones funcionales; WhatsApp no envía mensaje ni reserva.
- No precios ficticios de productos, catálogo compartido nuevo ni gratuidad universal.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.
- Cotejar Corrección5: Título y descripción superpuestos en el banner también en móvil. Tres pasos uno al lado de otro en una única fila; en móvil se desplaza horizontalmente para conservar lectura, no se apilan. Mantener comunidad, botones, beneficios y continuación de las dos referencias.

### Dependencias
IDs/ruta real de la página; Regla real de tres piezas y elegibilidad; porcentaje no facilitado; Confirmación comercial de anticipo/plazo/textos de ingresos y garantías recibidos; URLs oficiales de grupos y redes; Contenido de registro y cuenta compatible

### Precisiones
- La fuente visual distribuye hero, pasos, comunidad, beneficios, contacto, recomendaciones, registro y pie. Adoptar blanco puro y Glass discreto; no copiar fondos rosados, brillos pesados ni precios ilustrativos.
- Copy recibido íntegro en received_copy.Mayoreo. $800,20días, descuento automático, ingresos y garantías son contenido de referencia; no se convierten en nuevas reglas aprobadas o probadas por esta entrega.
- Antes de producción validar los bloques comerciales con responsables y capacidad real; si siguen pendientes, ocultar el bloque afectado sin inventar una redacción sustitutiva.
- La frase de referencia sobre recibir catálogos no crea un botón Compartir catálogo ni una función nueva.
- Envío gratis requiere cuenta autenticada reconocida por checkout. Invitado puede comprar con tarifa real según dirección; nunca inventar importe ni sustituir un cargo por cero visual.
- PROPUESTO: convertir el encabezado recibido Comienza a vender en CTA al catálogo general con retorno. El CTA del banner Inicio Comenzar a vender hacia Mayoreo sí está confirmado; son controles distintos.
- CONFIRMADO C5 salvo las interpretaciones marcadas PROPUESTO: Título y descripción superpuestos en el banner también en móvil. Tres pasos uno al lado de otro en una única fila; en móvil se desplaza horizontalmente para conservar lectura, no se apilan. Mantener comunidad, botones, beneficios y continuación de las dos referencias.

### Datos
Página vigente; URL de entorno

### App futura
Abrir destino compatible y conservar retorno.


## 025. Vista rápida

UI:G09 · Consultar y agregar una variante sin perder el listado.

### Entrada
Cuerpo de tarjeta común en listado, carrusel o favoritos.

### Elementos
1. X accesible sin flecha de regreso
2. Galería de la variante activa
3. Favorito sin contenedor, trazo más grueso, debajo de imagen a la derecha
4. Variantes
5. Marca, nombre y precio
6. Agregar al carrito y Ver producto

### Acciones
- Deslizar / elegir variante → Cambiar foto de variante / actualizar todos sus datos → Mismo modal
- Foto / Ver producto → Abrir PDP de variante elegida; arrastrar no navega → UI:G10
- Agregar / X o Escape → Confirmar agregado sin abrir carrito / cerrar y devolver foco → Mismo modal / tarjeta de origen

### Estados
Carga · Disponible · Variante agotada con compra indisponible · Agregando / éxito / error

### Adaptación
Móvil: Modal alto con scroll interno y salida visible.; Tablet: Panel centrado; dos zonas si caben.; Escritorio: Modal de ancho de lectura cómodo.; css_320: Modal alto con scroll interno y salida visible. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Panel centrado; dos zonas si caben. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Modal de ancho de lectura cómodo. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- Foto abre PDP de la variante elegida; color y favorito no navegan.
- Cerrar restaura posición y foco de origen.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.

### Dependencias


### Precisiones
- Fondo blanco; sin flecha Atrás redundante y con X accesible.
- Foto o Ver producto abre PDP con variante elegida; arrastre de galería no navega ni mezcla variantes.
- Ver producto usa halo C · Amplia.
- Corazón libre sin contenedor visible, geometría de 24 px y trazo 2.6; guardado con contorno e interior de la silueta dorados #A58248. Área transparente de 48 px, foco y estado accesibles; acción independiente.
- No repetir en esta superficie la microfrase de envío eliminada; la regla permanece en carrito/checkout.

### Datos
Producto y variante activa; Fotos asociadas; Precio/stock; Favorito

### App futura
Adaptar capa/modal y retorno al listado.


## 026. Página de producto

UI:G10 · Mostrar producto, variante, compra, detalles y recomendaciones en un recorrido coherente.

### Entrada
Foto/Ver producto desde vista rápida, destacado de Nueva colección, enlace de pedido o entrada directa válida.

### Elementos
1. Cabecera y fotografía grande; progreso solo si hay varias fotos
2. Marca, título, precio; miniaturas de variantes, color textual y disponibilidad
3. Agregar al carrito y Comprar ahora; debajo beneficios con iconos libres y texto
4. Acordeones: Descripción → Otras formas de comprar → Envíos → Cambios y devoluciones
5. Carruseles: Relacionados → Más de la marca → Vistos hace un momento
6. Registro y pie vigentes; barra móvil con espacio reservado

### Acciones
- Imagen / miniatura de variante → Abrir zoom / actualizar fotos, precio y stock → UI:G11 / misma PDP
- Agregar / Comprar ahora → Confirmar sin salir / usar variante y conservar otras líneas al iniciar compra → Misma PDP / UI:G15
- Acordeón Apartado / Avisarme cuando vuelva → Mostrar contacto contextual / registrar variante agotada con servicio real → WhatsApp autorizado / UI:G12

### Estados
Carga · Variante disponible · Variante agotada · Error de producto/foto · Agregando / éxito / error · Producto retirado con salida al catálogo

### Adaptación
Móvil: Una columna; compra y beneficios libres de barra flotante.; Tablet: Dos columnas solo si caben; si no, una.; Escritorio: Galería y datos en columnas; acordeones/recomendaciones después.; css_320: Una columna; compra y beneficios libres de barra flotante. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Dos columnas solo si caben; si no, una. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Galería y datos en columnas; acordeones/recomendaciones después. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- Variante de entrada, datos visibles y artículo añadido coinciden.
- Comprar ahora no pierde otros productos del carrito.
- Foto no abre pestaña; acordeones crecen y WhatsApp solo aparece en el correspondiente.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.

### Dependencias
Halo C confirmado; Servicio reposición; Reglas de beneficios/políticas

### Precisiones
- Agotado: etiqueta compacta negra con texto blanco, más pequeña y más abajo, junto al borde inferior de la foto. Sin brillo/animación; disponibilidad por variante.
- Corazón libre sin contenedor visible, geometría de 24 px y trazo 2.6; guardado con contorno e interior de la silueta dorados #A58248. Área transparente de 48 px, foco y estado accesibles; acción independiente.
- Se retira Sobre pedido de la presentación sin redefinir disponibilidad.
- Comprar ahora usa halo C · Amplia; Agregar conserva PDP y espera éxito real.
- Recomendaciones comparten tarjeta/cierre; Vistos se oculta sin historial; no duplicar productos para completar 40.
- Retirar únicamente la microfrase verde bajo beneficios; conservar contenido recibido de servicios sujeto a datos/políticas vigentes.
- Zoom dentro de página, no pestaña nueva; apartado WhatsApp aparece solo al abrir el acordeón Otras formas de comprar.

### Datos
Producto/variantes/imágenes; Precios/comparación/stock; Descripción/medidas confirmadas; Políticas vigentes; Recomendaciones reales

### App futura
Adaptar safe areas, back y zoom; mismo contrato de variante.


## 027. Producto · detalles y recomendaciones

UI:G10-A · Completar la lectura debajo de compra, dentro de la misma PDP.

### Entrada
Desde UI:G10; conservar disparador, consulta, variante y posición aplicables.

### Elementos
1. Descripción con información confirmada del producto; barras grises del boceto representan su texto CMS, sin atributos físicos de muestra.
2. Otras formas de comprar: apartado WhatsApp solo al abrir.
3. Envíos y Cambios/devoluciones con textos vigentes.
4. Relacionados → Más de la marca → Vistos hace un momento.
5. Carruseles con tarjetas consistentes y cierre libre; registro y pie al terminar.

### Acciones
- Acordeón → expandir dentro del flujo, sin recortes → Mismo contexto según respuesta
- Solicitar apartado → abrir WhatsApp con producto/variante; no reserva automática → Mismo contexto según respuesta
- Recomendación → vista rápida; volver conserva selección → Mismo contexto según respuesta

### Estados
Ocultar Vistos sin historial. · No inventar asociación, marca o producto para llenar. · X/Escape y foco según componente.

### Adaptación
Móvil: Una columna; mantener orden y áreas seguras.; Tablet: Redistribuir con espacio real, sin duplicar controles.; Escritorio: Redistribuir con espacio real, sin duplicar controles.; css_320: Una columna; mantener orden y áreas seguras. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Redistribuir con espacio real, sin duplicar controles. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Redistribuir con espacio real, sin duplicar controles. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- Acordeones crecen en el flujo y muestran contenido CMS vigente, sin inventar descripción física.
- WhatsApp se muestra solo al abrir el acordeón correspondiente; no crea reserva ni bloqueo de stock.
- Relacionados → Más de la marca → Vistos hace un momento; sin historial se omite Vistos, y cada carrusel conserva cierre y tarjetas comunes.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.

### Dependencias
Contenido vigente; Recomendaciones reales


## 028. Zoom de producto

UI:G11 · Examinar la fotografía disponible sin salir de la PDP.

### Entrada
Fotografía de la PDP.

### Elementos
1. Título accesible y X
2. Fotografía de variante activa
3. Ampliar, reducir y restablecer
4. Navegación entre fotos solo si existen

### Acciones
- Ampliar / reducir / restablecer → Modificar escala de imagen sin reconstruirla → Mismo modal
- X / Escape → Cerrar, conservar variante/foto y devolver foco → UI:G10

### Estados
Cargando foto · Imagen disponible · Error con reintento

### Adaptación
Móvil: Área amplia y controles alcanzables; gesto complementario.; Tablet: Misma imagen sin deformar.; Escritorio: Modal amplio con controles por teclado.; css_320: Área amplia y controles alcanzables; gesto complementario. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Misma imagen sin deformar. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Modal amplio con controles por teclado. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- Se amplía/cierra con teclado; al salir se conserva posición de PDP.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.

### Dependencias


### Precisiones
- No bloquea zoom del navegador; no aumenta detalle inexistente.
- No pestaña nueva; fondo inerte y retorno de foco.

### Datos
Fotografía original y resolución disponible; Índice de foto

### App futura
Pinch complementa botones; salida respeta sistema.


## 029. Aviso de reposición

UI:G12 · Registrar una solicitud vinculada a la variante agotada.

### Entrada
Avisarme cuando vuelva en PDP de variante agotada, con servicio conectado.

### Elementos
1. Agotado: etiqueta compacta negra con texto blanco, más pequeña y más abajo, junto al borde inferior de la foto. Sin brillo/animación; disponibilidad por variante.
2. Título, X y referencia de producto/variante
3. Miniatura del mismo producto y variante agotada, con nombre y color; no imagen genérica.
4. Campo de correo con etiqueta persistente
5. Información/consentimiento del canal realmente utilizado
6. Enviar solicitud y respuesta

### Acciones
- Enviar → Validar, consultar servicio y confirmar alta real o registro existente → Mismo modal
- Cancelar / X / Escape → Cerrar sin registrar y devolver foco → UI:G10

### Estados
Vacío · Correo inválido · Enviando · Registrado / ya registrado · Error con correo conservado

### Adaptación
Móvil: Teclado email; enviar y X no quedan tapados.; Tablet: Modal centrado.; Escritorio: Modal breve con foco controlado.; css_320: Teclado email; enviar y X no quedan tapados. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Modal centrado. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Modal breve con foco controlado. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- Solo aparece para variante agotada en PDP y con servicio activo.
- Repetir registro no duplica suscripción; cancelar no registra.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.
- Cotejar Corrección5: Agotado: etiqueta compacta negra con texto blanco, más pequeña y más abajo, junto al borde inferior de la foto. Sin brillo/animación; disponibilidad por variante.

### Dependencias
Proveedor/canal/consentimiento y disparador real de stock

### Precisiones
- Entrada en PDP: botón de aro interior dorado tenue. Campos sin línea inferior.
- Canal email y deduplicación son PROPUESTOS; no suscribir a campañas.
- No promete fecha, reserva ni entrega del aviso antes de respuesta del proveedor.
- CONFIRMADO C5 salvo las interpretaciones marcadas PROPUESTO: Agotado: etiqueta compacta negra con texto blanco, más pequeña y más abajo, junto al borde inferior de la foto. Sin brillo/animación; disponibilidad por variante.

### Datos
ID de variante; Correo autorizado; Respuesta de servicio de reposición

### App futura
Canal y permisos solo si están integrados.


## 030. Carrito

UI:G14 · Revisar unidades, corregir líneas e iniciar checkout con importes consistentes.

### Entrada
Carrito en navegación; no se abre automáticamente al agregar.

### Elementos
1. Cuenta en barra puede mostrar contador de notificaciones: badge oro/número negro sin modificar el icono. PROPUESTO contar no leídas, ocultar en cero y 99+ visual; fuente real, no sumar anuncios.
2. Título Carrito
3. Líneas: foto, producto, variante, precio unitario, cantidad y Eliminar
4. Disponibilidad o incidencias junto a cada línea
5. Resumen: subtotal, descuentos reales, ahorro verificable y envío
6. Envío gratis con cuenta; saldo opcional con integración compatible
7. Importe correspondiente y Continuar al pago; vacío usa Explorar productos

### Acciones
- Foto / nombre → Abrir PDP de la variante → UI:G10
- Más / menos / Eliminar → Esperar y actualizar línea, contador y resumen juntos → UI:G14
- Continuar al pago / Explorar en vacío → Revalidar y abrir checkout / abrir catálogo → UI:G15 / UI:G05

### Estados
Carga / error de recuperación · Vacío confirmado · Una / varias líneas · Actualizando cantidad · Stock insuficiente / retirado · Mayoreo elegible activo / inactivo · Crédito disponible / no aplicable

### Adaptación
Móvil: Una columna, resumen después de líneas; barra no tapa CTA.; Tablet: Una o dos columnas según espacio real.; Escritorio: Líneas y resumen en columnas, sin tapar última línea.; css_320: Una columna, resumen después de líneas; barra no tapa CTA. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Una o dos columnas según espacio real. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Líneas y resumen en columnas, sin tapar última línea. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- 2→3→4→2 refleja elegibilidad real; contador suma unidades.
- Doble toque o respuesta incierta no duplica productos.
- Eliminar última línea muestra vacío confirmado, no resumen de cero ni compra inerte.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.
- Cotejar Corrección5: Cuenta en barra puede mostrar contador de notificaciones: badge oro/número negro sin modificar el icono. PROPUESTO contar no leídas, ocultar en cero y 99+ visual; fuente real, no sumar anuncios.

### Dependencias
Porcentaje/elegibilidad/combinación reales de mayoreo; Crédito y envío integrados

### Precisiones
- Número central de cantidad es texto sin foco; menos indisponible en 1, Eliminar independiente.
- Tres piezas elegibles: icono oro, badge oro con número negro; aro interior tenue con centro transparente, sin relleno dorado.
- Solo llegada de una adición confirmada anima suavemente el icono; no en recarga ni bucle. Bajar del umbral recalcula/retira oro.
- Aviso mayoreo 4 s al cruzar umbral confirmado; no activa descuentos por sí mismo.
- No libre selector parcial de saldo ni doble resta de crédito/descuento.
- CONFIRMADO05/11/2026: envío gratis requiere cuenta. Invitado puede comprar con tarifa real; revalidar identidad/tarifa/total antes de pago.
- CONFIRMADO C5 salvo las interpretaciones marcadas PROPUESTO: Cuenta en barra puede mostrar contador de notificaciones: badge oro/número negro sin modificar el icono. PROPUESTO contar no leídas, ocultar en cero y 99+ visual; fuente real, no sumar anuncios.

### Datos
Carrito confirmado; Cantidades/stock; Asignaciones de descuento; Importes/envío/moneda; Elegibilidad real; Crédito compatible

### App futura
Misma fuente autoritativa y contador; safe areas propias.


## 031. Carrito · modificar y recuperar

UI:G14-A · Actualizar cantidades y resolver errores sin perder el carrito confirmado.

### Entrada
Desde UI:G14; conservar disparador, consulta, variante y posición aplicables.

### Elementos
1. Cada línea conserva foto, variante, precio unitario e importe.
2. Más/menos son botones; número central solo texto, sin acción ficticia.
3. En 1, menos indisponible; Eliminar es independiente.
4. Durante petición, bloquear repetición y el paso al pago incompatible.
5. Error junto a la línea y Reintentar; stock inválido exige corregir o retirar.

### Acciones
- Cambiar cantidad → esperar → actualizar línea, resumen y contador juntos → Mismo contexto según respuesta
- Error conocido → conservar último resultado confirmado → Mismo contexto según respuesta
- Resultado incierto → consultar carrito antes de repetir → Mismo contexto según respuesta

### Estados
Carga · Fallo conocido · Respuesta tardía / red · Stock insuficiente

### Adaptación
Móvil: Una columna; mantener orden y áreas seguras.; Tablet: Redistribuir con espacio real, sin duplicar controles.; Escritorio: Redistribuir con espacio real, sin duplicar controles.; css_320: Una columna; mantener orden y áreas seguras. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Redistribuir con espacio real, sin duplicar controles. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Redistribuir con espacio real, sin duplicar controles. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- Más/menos/Eliminar se serializan por intención y bloquean repetición mientras hay petición.
- Respuesta incierta obliga reconciliar antes de reenviar; error conocido conserva último estado confirmado.
- Tras éxito cambian juntos línea, contador, elegibilidad y resumen; menos está indisponible en 1 y el número no simula botón.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.

### Dependencias



## 032. Carrito · dorado por elegibilidad

UI:G14-B · Revisar unidades, corregir líneas e iniciar checkout con importes consistentes.

### Entrada
Carrito en navegación; no se abre automáticamente al agregar.

### Elementos
1. Icono dorado, aro interior transparente y badge oro/negro.
2. Estado determinado por elegibilidad real.
3. Movimiento solo tras agregado confirmado; no en recarga.

### Acciones
- Agregar confirmado → Actualizar estado e iniciar gota una vez → Misma página

### Estados
Carga / error de recuperación · Vacío confirmado · Una / varias líneas · Actualizando cantidad · Stock insuficiente / retirado · Mayoreo elegible activo / inactivo · Crédito disponible / no aplicable

### Adaptación
Móvil: Una columna, resumen después de líneas; barra no tapa CTA.; Tablet: Una o dos columnas según espacio real.; Escritorio: Líneas y resumen en columnas, sin tapar última línea.; css_320: Una columna, resumen después de líneas; barra no tapa CTA. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Una o dos columnas según espacio real. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Líneas y resumen en columnas, sin tapar última línea. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- 2→3→4→2 usa unidades elegibles reales y badge de unidades; el centro del botón conserva transparencia.
- Doble pulsación no duplica intención; al fallar no aparece éxito ni gota.
- Sin nueva adición, recarga/reconsulta conserva estado estático y no repite aviso/celebración.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.

### Dependencias
Porcentaje/elegibilidad/combinación reales de mayoreo; Crédito y envío integrados

### Precisiones
- Icono dorado y badge dorado con número negro; aro solo en borde interior que se desvanece, centro transparente, sin relleno oro.
- Elegibilidad real de tres piezas, sin porcentaje comercial inventado. Estado visual no aplica descuentos.
- Solo una nueva adición confirmada dispara gota y asentamiento suave; 2→3 activa oro, 3→4 lo conserva, bajar de umbral lo retira.
- Aviso mayoreo durante 4 s al cruzar el umbral; recarga/reconsulta no animan. Reduced motion confirma estático y por texto.

### Datos
Carrito confirmado; Cantidades/stock; Asignaciones de descuento; Importes/envío/moneda; Elegibilidad real; Crédito compatible

### App futura
Misma fuente autoritativa y contador; safe areas propias.


## 033. Carrito · resumen sin doble conteo

UI:G14-C · Revisar unidades, corregir líneas e iniciar checkout con importes consistentes.

### Entrada
Carrito en navegación; no se abre automáticamente al agregar.

### Elementos
1. Título Carrito
2. Líneas: foto, producto, variante, precio unitario, cantidad y Eliminar
3. Disponibilidad o incidencias junto a cada línea
4. Resumen: subtotal, descuentos reales, ahorro verificable y envío
5. Envío gratis con cuenta; saldo opcional con integración compatible
6. Importe correspondiente y Continuar al pago; vacío usa Explorar productos

### Acciones
- Foto / nombre → Abrir PDP de la variante → UI:G10
- Más / menos / Eliminar → Esperar y actualizar línea, contador y resumen juntos → UI:G14
- Continuar al pago / Explorar en vacío → Revalidar y abrir checkout / abrir catálogo → UI:G15 / UI:G05

### Estados
Carga / error de recuperación · Vacío confirmado · Una / varias líneas · Actualizando cantidad · Stock insuficiente / retirado · Mayoreo elegible activo / inactivo · Crédito disponible / no aplicable

### Adaptación
Móvil: Una columna, resumen después de líneas; barra no tapa CTA.; Tablet: Una o dos columnas según espacio real.; Escritorio: Líneas y resumen en columnas, sin tapar última línea.; css_320: Una columna, resumen después de líneas; barra no tapa CTA. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Una o dos columnas según espacio real. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Líneas y resumen en columnas, sin tapar última línea. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- Descuentos de línea/pedido se asignan una vez; comparación anterior no se resta otra vez.
- Envío cero solo con cuenta autenticada; invitado usa tarifa real. Inicio/cierre de sesión recalcula antes de pagar.
- Crédito opcional como medio de pago, sin doble resta; subtotal, cargos y total coinciden con respuesta autoritativa.

### Dependencias
Porcentaje/elegibilidad/combinación reales de mayoreo; Crédito y envío integrados

### Precisiones
- La fila de envío gratis del ejemplo representa una cuenta autenticada. Para invitado consultar tarifa real y no presentar total final inventado.

### Datos
Carrito confirmado; Cantidades/stock; Asignaciones de descuento; Importes/envío/moneda; Elegibilidad real; Crédito compatible

### App futura
Misma fuente autoritativa y contador; safe areas propias.


## 034. Checkout y estado del pago

UI:G15 · Completar una compra como invitado o cuenta con el proveedor real.

### Entrada
Continuar al pago o Comprar ahora, con variante y carrito válidos.

### Elementos
1. Contacto
2. Dirección y opciones reales de entrega
3. Métodos de pago habilitados
4. Crédito disponible compatible, si aplica
5. Resumen, cargos y total final
6. Pagar y respuesta del proveedor

### Acciones
- Datos / dirección → Validar y recalcular opciones y cargos reales → Mismo flujo
- Pagar / rechazo / resultado incierto → Evitar reenvío; corregir rechazo o consultar estado antes de nuevo pago → Proveedor → UI:G16 si corresponde
- Volver → Conservar carrito y contexto → UI:G14

### Estados
Datos incompletos / inválidos · Validando dirección/cobertura · Procesando · Pago pendiente / rechazado / desconocido · Confirmación real

### Adaptación
Móvil: Orden vertical y teclado seguro según checkout alojado.; Tablet: Diseño admitido por proveedor.; Escritorio: Resumen y datos según capacidades reales.; css_320: Orden vertical y teclado seguro según checkout alojado. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Diseño admitido por proveedor. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Resumen y datos según capacidades reales. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- Cancelar/volver no pierde carrito ni duplica cobro.
- Total final coincide; solo medios reales; prueba completa autorizada en modo de prueba.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.

### Dependencias
Plan, tipo de storefront y modalidad de cuentas; Proveedor y modo de prueba verificados

### Precisiones
- Español de México; compra con cuenta o invitada.
- No imponer Glass ni navegación propia donde el checkout alojado no permita personalización; resolver con las capacidades reales de esta tienda.
- No almacenar tarjetas ni datos sensibles desde UI. Idempotencia/reconsulta por referencia: el estado no procede de un temporizador.
- Dirección primaria real o Añadir dirección; desplegable permite elegir, añadir o modificar si el proveedor lo soporta.
- Envío gratis requiere cuenta autenticada reconocida por checkout. Invitado puede comprar con tarifa real según dirección; nunca inventar importe ni sustituir un cargo por cero visual.
- Espera: círculo abierto giratorio que nunca se cierra; estado textual persiste. Rechazo verificado: X roja con una sola aparición/asentamiento; pending/unknown no son rechazo.
- Si hay resultado incierto, consultar operación antes de habilitar otro pago; no se realizan compras para producir esta documentación.

### Datos
Checkout del proveedor; Contacto/dirección; Opciones de pago/envío; Total autoritativo; Estado de pago/pedido

### App futura
Checkout compatible con app, sin atribuir soporte a un HTML.


## 035. Checkout · dirección y entrega

UI:G15-A · Resolver envío y estado del proveedor antes de confirmar la compra.

### Entrada
Desde UI:G15; conservar disparador, consulta, variante y posición aplicables.

### Elementos
1. Sin dirección guardada: Añadir dirección.
2. Con cuenta y direcciones: primaria real seleccionada, si existe.
3. Desplegable con guardadas, Añadir dirección y Modificar seleccionada según capacidad real.
4. Invitado captura dirección de esta compra; no se guardan datos en cuenta inexistente.
5. Validar cobertura, tarifa de invitado o cero real de cuenta y actualizar resumen.

### Acciones
- Selector / añadir / modificar → Editar datos correspondientes sin alterar direcciones históricas → Mismo flujo / gestión compatible
- Confirmar dirección → Revalidar cobertura y cotizar con identidad actual → UI:G15

### Estados
Sin dirección · Primaria disponible · Desplegable abierto · Guardar / error · Cobertura no disponible

### Adaptación
Móvil: Una columna; mantener orden y áreas seguras.; Tablet: Redistribuir con espacio real, sin duplicar controles.; Escritorio: Redistribuir con espacio real, sin duplicar controles.; css_320: Una columna; mantener orden y áreas seguras. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Redistribuir con espacio real, sin duplicar controles. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Redistribuir con espacio real, sin duplicar controles. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- Elegir dirección para esta compra no cambia la primaria de cuenta sin acción expresa.
- Invitado ve tarifa real; cuenta ve cero solo cuando lo devuelve la regla real.
- Cambio de identidad/dirección invalida cotización anterior y pide confirmar total.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.

### Dependencias
Plan, proveedor y modo de prueba verificados


## 036. Confirmación de pedido

UI:G16 · Mostrar el pedido real y su estado de pago sin confundirlo con envío.

### Entrada
Respuesta autoritativa del checkout/pedido.

### Elementos
1. Resultado real del pedido/pago
2. Identificación y fecha del pedido
3. Artículos y variantes
4. Importes y datos de entrega autorizados
5. Ver pedido / continuar explorando según rutas disponibles

### Acciones
- Ver pedido → Abrir acceso autorizado al mismo pedido → UI:G23
- Recargar / volver → Consultar la misma operación sin repetir efectos → Mismo pedido

### Estados
Consultando referencia · Pago aprobado verificado · Pago pendiente · Pago rechazado verificado · Resultado desconocido · Error de consulta

### Adaptación
Móvil: Resumen vertical legible.; Tablet: Agrupar detalles sin comprimir.; Escritorio: Ancho de lectura y resumen claros.; css_320: Resumen vertical legible. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Agrupar detalles sin comprimir. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Ancho de lectura y resumen claros. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- Solo paid verificado muestra Pago completado/check; pending/unknown y fallo de lectura no se anuncian como éxito o rechazo.
- Una referencia conserva el resultado sin reproducir efectos al recargar/reconsultar; no crea pedido, cobro, bono o cashback.
- Ver pedido exige autorización del recurso y distingue estado de pago del envío.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.

### Dependencias


### Precisiones
- Resultado proviene del servicio y referencia autorizada; un pedido creado no equivale a pagado o enviado.
- paid verificado: check verde #3B7030 grueso, redondeado, sin contenedor, sombra tenue; trazo350ms + asentamiento260ms máximo2px, .94→1.01→1, una vez por referencia.
- rejected verificado: X roja con tratamiento equivalente, una vez; rojo propuesto #A63535.
- processing: círculo abierto que rota mientras se consulta, sin cerrarse. pending/unknown conservan mensaje propio y no muestran check ni X de rechazo.
- Recarga/reconsulta/volver a la misma referencia muestra símbolo final estático; fallo de almacenamiento local no autoriza efectos monetarios ni bloquea consulta.
- Reduced motion: símbolo estático inmediato con texto. No bucles de éxito/rechazo.
- Envío gratis requiere cuenta autenticada reconocida por checkout. Invitado puede comprar con tarifa real según dirección; nunca inventar importe ni sustituir un cargo por cero visual.

### Datos
ID/número de pedido real; Estados separados de pago/envío; Líneas/importes

### App futura
Enlace seguro compatible y retorno al catálogo.


## 037. Acceso y registro de cuenta

UI:G17 · Acceder a beneficios/datos privados manteniendo la compra invitada.

### Entrada
Cuenta de invitado, registro de Inicio o destino protegido.

### Elementos
1. Acceso: reemplazar Seguir explorando por el texto exacto Seguir como invitado. Conserva compra y contexto.
2. Marca y título de acceso.
3. Continuar con Google usando activo y tipografía oficiales.
4. Continuar con Apple con recurso oficial en español.
5. Continuar con correo → correo y código compatible.
6. Seguir como invitado como invitado.

### Acciones
- Google / Apple → Autenticar con proveedor y volver al destino → Flujo compatible verificado / ruta de origen
- Correo → Capturar correo y verificar código cuando aplique → UI:G17-A
- Cancelar / explorar → Conservar carrito y contexto → Catálogo o ruta anterior

### Estados
Vacío / inválido · Enviando · Código enviado si aplica · Código inválido/caducado · Error · Autenticado

### Adaptación
Móvil: Cápsula sin subrayado; teclado no tapa acción.; Tablet: Formulario compacto.; Escritorio: Ancho controlado; no duplicar formulario.; css_320: Cápsula sin subrayado; teclado no tapa acción. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Formulario compacto. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Ancho controlado; no duplicar formulario. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- Acceso vuelve al destino protegido original; invitado puede seguir comprando.
- Error conserva correo; no expone datos de otra identidad.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.
- Cotejar Corrección5: Acceso: reemplazar Seguir explorando por el texto exacto Seguir como invitado. Conserva compra y contexto.

### Dependencias
Modalidad de cuentas; Google conectado; Disponibilidad de Apple por verificar en esta tienda; Callbacks/dominios por entorno y pruebas

### Precisiones
- Google, Apple y correo son métodos deseados CONFIRMADOS; publicar solo los configurados y probados en este entorno.
- No inferir funcionalidades de identidad por plan o por una maqueta. No añadir contraseñas, fusión de cuentas o recuperación que no existan.
- Volver al origen interno permitido, conservando carrito. Acceder no acredita bonos por sí solo.
- Envío gratis requiere cuenta autenticada reconocida por checkout. Invitado puede comprar con tarifa real según dirección; nunca inventar importe ni sustituir un cargo por cero visual.
- CONFIRMADO C5 salvo las interpretaciones marcadas PROPUESTO: Acceso: reemplazar Seguir explorando por el texto exacto Seguir como invitado. Conserva compra y contexto.

### Datos
Modalidad de cuenta; Correo; Respuesta de identidad

### App futura
Autenticación e identidad compatibles con el servicio real.


## 038. Acceso · correo y verificación

UI:G17-A · Continuación del flujo compatible de cuentas; no exigir registro para comprar.

### Entrada
Desde UI:G17; conservar disparador, consulta, variante y posición aplicables.

### Elementos
1. Etiqueta y campo Correo electrónico, sin línea interior.
2. Continuar envía la solicitud al proveedor real.
3. Si aplica: código de seis dígitos, Continuar y Reenviar.
4. Nombre/roles, errores asociados y salida al destino anterior.
5. Google/Apple cancelados o fallidos conservan carrito; no generar cuenta/bono desde la UI.

### Acciones
- Correo válido → solicitar código por proveedor → Mismo contexto según respuesta
- Código válido → autenticar y regresar a origen → Mismo contexto según respuesta
- Error/caducidad → explicar, conservar correo y permitir reenvío real → Mismo contexto según respuesta

### Estados
Enviando · Inválido o caducado · Reenvío regulado por proveedor · Sesión correcta

### Adaptación
Móvil: Una columna; mantener orden y áreas seguras.; Tablet: Redistribuir con espacio real, sin duplicar controles.; Escritorio: Redistribuir con espacio real, sin duplicar controles.; css_320: Una columna; mantener orden y áreas seguras. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Redistribuir con espacio real, sin duplicar controles. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Redistribuir con espacio real, sin duplicar controles. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- Correo conserva etiqueta y error asociado, sin subrayado interior.
- Código/reenvío solo según la modalidad real; límites y caducidad proceden del proveedor.
- Éxito relee identidad y vuelve al origen; cancelar o caducar no crea cuenta, saldo ni pedido.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.

### Dependencias
Modalidad de cuentas confirmada; Google/Apple y retorno verificados


## 039. Mi cuenta

UI:G18 · Dar acceso ordenado a los módulos personales realmente disponibles.

### Entrada
Cuenta de identidad autenticada o retorno tras acceso.

### Elementos
1. Cabecera: nombre real y Miembro + nivel; Saldo pequeño arriba de monto real verde. Ejemplo PRO/$1,345 no es dato real. Tras Cerrar sesión: slot de tarjetas publicitarias editables, proporción banner, material/deslizamiento de Todas las marcas, clicables. Sin activos/destinos aún: ocultar; no fijar Mayoreo.
2. Avatar Glass con primera letra real y nombre; destino Perfil. Invitado continúa al acceso.
3. MONETTA REWARDS y datos/beneficios reales.
4. Pedidos → Favoritos → Notificaciones.
5. Direcciones → Métodos de pago solo si gestionables.
6. Preferencias de intereses → Ayuda → Contacto; divisores flotantes con bordes redondeados y mínima sombra inferior.

### Acciones
- Fila de módulo → Abrir destino disponible con permisos reales → UI:G19 / UI:G22 / UI:G24 / UI:G25 / UI:G27 / UI:G28 / UI:G29 / UI:G30 / UI:G40
- Avatar / Perfil → Editar datos permitidos → UI:G26
- Tarjeta publicitaria configurada → Abrir destino editorial autorizado; conservar regreso → Binding del anuncio, interno o externo permitido
- Cerrar sesión → Limpiar privados, conservar carrito y recalcular envío → UI:G17

### Estados
Carga · Autenticado · Sesión expirada · Error de datos con reintento

### Adaptación
Móvil: Lista con iconos coherentes y barra inferior.; Tablet: Panel cómodo con mismo orden.; Escritorio: Menú lateral y panel de contenido.; css_320: Lista con iconos coherentes y barra inferior. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Panel cómodo con mismo orden. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Menú lateral y panel de contenido. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- Cada acceso visible funciona; no filas inertes.
- Volver/cambiar de usuario no muestra datos de la identidad anterior.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.
- Cotejar Corrección5: Cabecera: nombre real y Miembro + nivel; Saldo pequeño arriba de monto real verde. Ejemplo PRO/$1,345 no es dato real. Tras Cerrar sesión: slot de tarjetas publicitarias editables, proporción banner, material/deslizamiento de Todas las marcas, clicables. Sin activos/destinos aún: ocultar; no fijar Mayoreo.

### Dependencias


### Precisiones
- Sin Modo Mayoreo ni compartir catálogo. No existe pantalla propia de movimiento/superficies; accesibilidad técnica sigue implícita.
- Métodos de pago, intereses y canales sin capacidad no aparecen como botones inertes.
- Cerrar sesión retira saldo/pedidos/direcciones visibles; conserva carrito según política real y recalcula envío antes de pagar.
- Divisores son decorativos; no controles falsos.
- CONFIRMADO C5 salvo las interpretaciones marcadas PROPUESTO: Cabecera: nombre real y Miembro + nivel; Saldo pequeño arriba de monto real verde. Ejemplo PRO/$1,345 no es dato real. Tras Cerrar sesión: slot de tarjetas publicitarias editables, proporción banner, material/deslizamiento de Todas las marcas, clicables. Sin activos/destinos aún: ocultar; no fijar Mayoreo.

### Datos
Identidad autorizada; Capacidades de módulos

### App futura
Misma jerarquía, navegación y permisos adaptados.


## 040. MONETTA REWARDS

UI:G19 · Mostrar nivel y progreso comprobados sin imitar acreditaciones.

### Entrada
MONETTA REWARDS desde Mi cuenta o aviso autorizado.

### Elementos
1. MONETTA REWARDS; nivel actual dentro del arco de270°.
2. Arco más grueso, extremos redondeados, oro translúcido y sombra interior/exterior tenue; sin aguja, numerales ni línea central.
3. Porcentaje pequeño; antes de ÉLITE, avance y Siguiente nivel textual; anteriores ocultos.
4. ÉLITE: nombre y100% dentro; sin10/10 ni ÉLITE externo; contenido inferior sube para evitar hueco.
5. Solo Saldo disponible verde, Movimientos y beneficios; no bloque visible de saldo Pendiente.

### Acciones
- Beneficios del nivel → Abrir explicación del nivel → UI:G20
- Ver movimientos → Abrir historial real de saldo → UI:G21
- Nueva información del servicio → Actualizar nivel/progreso coherentes → UI:G19

### Estados
Cargando · 0 / 4 / 5 / 9 / 10 y más compras · Error de consulta · Saldo disponible cero confirmado / positivo

### Adaptación
Móvil: Arco y datos legibles; no saturar centro.; Tablet: Panel centrado sin ampliar tipografía por factor fijo.; Escritorio: Panel de Rewards dentro de cuenta.; css_320: Arco y datos legibles; no saturar centro. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Panel centrado sin ampliar tipografía por factor fijo. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Panel de Rewards dentro de cuenta. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- Hitos0/4/5/9/10 mantienen progreso/porcentaje/nivel/texto coherentes con datos reales.
- ÉLITE es compacto y conserva lectura accesible sin10/10 ni duplicado exterior.
- No numerales, aguja, línea central ni ornamentos de nivel; reduced motion es estático.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.

### Dependencias
Compra elegible, base, acreditación, devoluciones y bonos

### Precisiones
- Diez compras y diez puntos porcentuales por compra según dato elegible real; exponer conteo textual accesible aun donde se oculta visualmente.
- Destellos fríos breves solo cuando el servicio confirma avance; nunca brillo/animación constante.
- Nueva formulación p40 sobre completar la barra quedó inconclusa: no crear conducta posterior por inferencia.
- No acreditar por carga/recarga/inicio de sesión. Error no equivale a saldo cero o nivel PRO.
- Envío gratis requiere cuenta autenticada reconocida por checkout. Invitado puede comprar con tarifa real según dirección; nunca inventar importe ni sustituir un cargo por cero visual.

### Datos
Compras elegibles; Nivel/progreso; Saldo disponible; Reglas/versiones de Rewards

### App futura
Misma fuente de nivel/saldo y lectura accesible.


## 041. Beneficios de nivel

UI:G20 · Explicar el nivel seleccionado con una composición limpia.

### Entrada
Beneficios del nivel desde Rewards.

### Elementos
1. Miembro muy próximo al nombre del nivel, que es mayor y bold; sin iconos ornamentales.
2. Introducción recibida, objetivo dos líneas de altura común al tamaño base; contenido y divisor próximos.
3. Separador algo más grueso/redondeado; beneficios más juntos en orden cashback → bono → envío.
4. Cada beneficio en una línea al tamaño base cuando cabe; no forzar recortes al ampliar texto.
5. Importe de bono verde, mxn minúsculas; X/Cerrar con Escape, foco contenido y retorno.

### Acciones
- Abrir beneficios → Mostrar el nivel solicitado sin generar saldo → Mismo modal
- X / Escape → Cerrar y devolver foco → UI:G19

### Estados
PRO · VIP · ÉLITE · Carga / error si los datos se consultan

### Adaptación
Móvil: Modal breve y desplazable si texto crece.; Tablet: Panel centrado.; Escritorio: Mismo modal y jerarquía.; css_320: Modal breve y desplazable si texto crece. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Panel centrado. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Mismo modal y jerarquía. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- Orden cashback → bono → envío y cantidades recibidas iguales en tres niveles; nivel domina cabecera.
- ÉLITE usa únicamente la frase abreviada recibida en notes, sin el cierre anterior.
- No Consulta condiciones, ornamentos o texto recortado; a200%/320px el contenido refluye y se desplaza con cierre alcanzable.
- Solo se anuncia como beneficio disponible lo respaldado por reglas y servicio; la maqueta no acredita saldo.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.

### Dependencias
Reglas de cashback, bonos, límites y acumulación; Uso de bono en compra actual o siguiente; Configuración/prueba técnica del envío gratis con cuenta, decisión ya confirmada

### Precisiones
- PRO: Estos beneficios son los que consigues registrándote en MONETTA REWARDS.
- VIP: Este nivel lo consigues completando 5 compras con tu cuenta de MONETTA REWARDS.
- ÉLITE: Completa 10 pedidos y accede al nivel más exclusivo de MONETTA REWARDS.
- PRO: 1% de Cashback → Bono de $100 mxn → Envío Gratis en todos tus pedidos.
- VIP: 2% de Cashback → Bono de $100 mxn → Envío Gratis en todos tus pedidos.
- ÉLITE: 3% de Cashback → Bono de $200 mxn → Envío Gratis en todos tus pedidos.
- Copy y valores recibidos para diseñar; cashback/bonos siguen sujetos a reglas e integración. Sin Consulta condiciones en este modal.
- Envío gratis con cuenta es confirmado; no exclusivo de VIP/ÉLITE. Bono en compra que desbloquea o siguiente permanece PENDIENTE: no elegir silenciosamente.

### Datos
Beneficios de nivel respaldados por reglas

### App futura
Capa accesible equivalente.


## 042. Saldo y movimientos

UI:G21 · Consultar saldo disponible y el origen de cada movimiento.

### Entrada
Ver movimientos desde Rewards o aviso de saldo con destino válido.

### Elementos
1. Saldo disponible confirmado con moneda
2. Movimientos cronológicos: tipo, importe, fecha y referencia
3. Detalle o enlace al pedido/evento autorizado cuando existe

### Acciones
- Movimiento → Abrir referencia autorizada o detalle soportado → UI:G23 / detalle existente
- Reintentar → Consultar servicio sin crear abonos → UI:G21

### Estados
Cargando · Saldo cero confirmado · Sin movimientos confirmado · Historial · Error con reintento

### Adaptación
Móvil: Filas que crecen con importe/referencia.; Tablet: Lectura cómoda.; Escritorio: Panel dentro de cuenta; tabla solo si conserva reflow.; css_320: Filas que crecen con importe/referencia. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Lectura cómoda. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Panel dentro de cuenta; tabla solo si conserva reflow. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- Error no se muestra como cero ni historial vacío.
- Cada importe procede del servicio y no se duplica al reintentar.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.

### Dependencias


### Precisiones
- Solo saldo disponible real en verde; sin saldo Pendiente visible ni suma de importes no acreditados.
- Movimientos mantienen tipo/fecha/importe/referencia autorizada; leer/recargar no acredita nada.
- Crédito opcional según integración real. No selector de importe parcial libre sin validación; crédito no es descuento que deba restarse dos veces.

### Datos
Saldo disponible; Movimientos y referencias autorizadas

### App futura
Misma fuente común de movimientos.


## 043. Mis pedidos

UI:G22 · Encontrar pedidos por su estado sin confundir pago y envío.

### Entrada
Pedidos desde Mi cuenta.

### Elementos
1. Título Pedidos
2. Filtros Historial / En camino / Cancelados
3. Lista de pedidos: número/fecha, resumen e importes reales
4. Estado de pago y estado de envío diferenciados

### Acciones
- Filtro → Cambiar conjunto manteniendo contexto al volver → UI:G22
- Pedido → Abrir detalle autorizado → UI:G23
- Explorar en vacío → Abrir catálogo → UI:G05

### Estados
Cargando · Sin pedidos confirmado · Con pedidos · Error · Sesión expirada

### Adaptación
Móvil: Tarjetas/filas verticales de lectura clara.; Tablet: Aumentar espacio sin perder orden.; Escritorio: Panel de cuenta.; css_320: Tarjetas/filas verticales de lectura clara. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Aumentar espacio sin perder orden. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Panel de cuenta. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- Pedido creado no se confunde con pagado/enviado.
- Otro usuario no obtiene historial anterior.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.

### Dependencias


### Precisiones
- No números de pedido operativos inventados en bocetos: usar ejemplo identificado.
- Volver conserva filtro y posición.

### Datos
Pedidos de la identidad autenticada; Estados independientes

### App futura
Misma fuente, identidad y filtros.


## 044. Detalle de pedido

UI:G23 · Entender artículos, importes, pago y envíos del pedido concreto.

### Entrada
Pedido en historial, confirmación o enlace seguro autorizado.

### Elementos
1. Barra horizontal de progreso de envío, contorno firme y tres círculos: camión/Preparando tu pedido → avión/Tu pedido va en camino → casa/Tu pedido fue entregado. Rellenar solo por estado real; pago separado. Sin porcentaje temporal inventado; parcial/cancelado/error no equivalen a entregado.
2. Identificación/fecha del pedido
3. Estado de pago
4. Estado de preparación/envío y seguimiento por envío si existe
5. Artículos: foto, nombre, variante, cantidad e importes
6. Resumen real y dirección histórica autorizada
7. Ayuda y navegación de regreso

### Acciones
- Artículo vigente → Abrir PDP correspondiente → UI:G10
- Seguimiento / Ayuda → Abrir tracking real / canal con referencia autorizada → Proveedor de seguimiento / UI:G30
- Volver → Restaurar filtro y posición del historial → UI:G22

### Estados
Carga / error · Pago pendiente / aprobado / rechazado · Envío parcial / en camino / entregado según servicio · Cancelado / reembolso parcial o total · Artículo retirado

### Adaptación
Móvil: Bloques verticales; textos largos crecen.; Tablet: Dos zonas si caben.; Escritorio: Resumen e historial legibles en panel amplio.; css_320: Bloques verticales; textos largos crecen. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Dos zonas si caben. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Resumen e historial legibles en panel amplio. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- Envío parcial no declara entregado todo el pedido.
- Recarga no crea cobro, bono o pedido; permisos por identidad en cada consulta.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.
- Cotejar Corrección5: Barra horizontal de progreso de envío, contorno firme y tres círculos: camión/Preparando tu pedido → avión/Tu pedido va en camino → casa/Tu pedido fue entregado. Rellenar solo por estado real; pago separado. Sin porcentaje temporal inventado; parcial/cancelado/error no equivalen a entregado.

### Dependencias


### Precisiones
- Sin tracking no se dibuja enlace falso.
- Artículo retirado conserva datos históricos y salida al catálogo.
- No añadir cancelar/devolver como botón si el proveedor no permite esa acción.
- Estado Pago pendiente en rojo #A63535, siempre acompañado de texto. Pendiente no significa rechazado y nunca muestra check de éxito.
- CONFIRMADO C5 salvo las interpretaciones marcadas PROPUESTO: Barra horizontal de progreso de envío, contorno firme y tres círculos: camión/Preparando tu pedido → avión/Tu pedido va en camino → casa/Tu pedido fue entregado. Rellenar solo por estado real; pago separado. Sin porcentaje temporal inventado; parcial/cancelado/error no equivalen a entregado.

### Datos
Pedido autorizado; Líneas históricas; Pagos/reembolsos; Envíos y tracking

### App futura
Acceso profundo seguro a pedido propio.


## 045. Favoritos

UI:G24 · Conservar productos preferidos con alcance local o sincronizado explícito.

### Entrada
Favoritos desde Mi cuenta o acceso existente compatible.

### Elementos
1. Añadir Basado en tus gustos: carrusel de dos filas y mínimo60 productos/modelos únicos si existen. Carga progresiva, no duplicar para completar; intereses/búsquedas reales con fallback editorial sin historial. Cada producto conserva rápida/variante/favorito; cierre a recomendaciones y acceso textual propuestos.
2. Título Favoritos
3. Indicación de alcance cuando es local
4. Tarjetas comunes guardadas
5. Vacío con salida al catálogo cuando corresponde

### Acciones
- Cuerpo / color → Abrir vista rápida / cambiar variante → UI:G09 / misma tarjeta
- Corazón o retirar → Quitar guardado y confirmar resultado → UI:G24
- Acceder → Continuar cuenta si existe sincronización compatible → UI:G17
- Basado en tus gustos → Avanzar columnas de dos filas, sin duplicar productos → Mismo carrusel; cierre al conjunto recomendado

### Estados
Carga · Vacío confirmado · Favoritos locales · Sincronizados solo con servicio real · Error al guardar / producto retirado

### Adaptación
Móvil: Grilla común; no quinta pestaña inferior.; Tablet: Columnas según ancho.; Escritorio: Panel o página de cuenta.; css_320: Grilla común; no quinta pestaña inferior. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Columnas según ancho. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Panel o página de cuenta. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- Fallos restauran estado; locales no se anuncian como sincronizados.
- Producto retirado se informa y puede retirarse.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.
- Cotejar Corrección5: Añadir Basado en tus gustos: carrusel de dos filas y mínimo60 productos/modelos únicos si existen. Carga progresiva, no duplicar para completar; intereses/búsquedas reales con fallback editorial sin historial. Cada producto conserva rápida/variante/favorito; cierre a recomendaciones y acceso textual propuestos.

### Dependencias
Fuente común y regla de unión para sincronización

### Precisiones
- PROPUESTO: unión por ID de producto sin duplicados, conservando variante como contexto.
- Sin fuente común, no escribir Guardados en tu cuenta.
- Retirar favorito no agrega al carrito ni abre otro destino.
- CONFIRMADO C5 salvo las interpretaciones marcadas PROPUESTO: Añadir Basado en tus gustos: carrusel de dos filas y mínimo60 productos/modelos únicos si existen. Carga progresiva, no duplicar para completar; intereses/búsquedas reales con fallback editorial sin historial. Cada producto conserva rápida/variante/favorito; cierre a recomendaciones y acceso textual propuestos.

### Datos
IDs guardados; Variante preferida; Alcance del almacenamiento

### App futura
Sincronización solo con identidad y servicio comunes.


## 046. Notificaciones

UI:G25 · Consultar avisos con fecha, estado y destino útil.

### Entrada
Notificaciones desde Mi cuenta/campana cuando existe servicio.

### Elementos
1. Título Notificaciones
2. Lista: título/resumen vigente, fecha y leído/no leído
3. Destino asociado a cada aviso

### Acciones
- Aviso → Abrir destino y guardar leído según servicio → Producto / colección / marca / Rewards / pedido real
- Destino retirado → Explicar y ofrecer alternativa pertinente → Catálogo o módulo relacionado

### Estados
Carga · Vacío confirmado · Leído / no leído · Error · Destino retirado / aviso repetido

### Adaptación
Móvil: Filas con área pulsable amplia y fecha legible.; Tablet: Mismo orden y contenido.; Escritorio: Panel de cuenta.; css_320: Filas con área pulsable amplia y fecha legible. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Mismo orden y contenido. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Panel de cuenta. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- Volver conserva posición; error al guardar leído no simula sincronización.
- Todo aviso tiene destino válido o alternativa.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.

### Dependencias
Servicio de avisos/canales/consentimientos

### Precisiones
- Tipos recibidos: ofertas, productos, colecciones, marcas, bonos, nivel y saldo.
- No depender solo de punto de color para no leído.
- No suponer email/WhatsApp/push activos; favorito no equivale a solicitud de reposición.

### Datos
Avisos de identidad autorizada; Fecha/estado/destino

### App futura
Push solo cuando exista permiso e integración; no se presupone.


## 047. Perfil

UI:G26 · Editar datos personales permitidos sin convertirlos en consentimiento comercial.

### Entrada
Perfil desde Mi cuenta.

### Elementos
1. Título Perfil
2. Campos permitidos con etiquetas persistentes
3. Mensajes de validación asociados
4. Guardar y Cancelar

### Acciones
- Guardar → Validar y esperar respuesta del proveedor → UI:G26 o UI:G18 según flujo
- Cancelar → Salir sin cambios → UI:G18
- Cambiar correo si se permite → Iniciar verificación real → Flujo seguro del proveedor

### Estados
Cargando · Datos cargados / editando · Guardando · Error conservando valores · Guardado real · Sesión expirada

### Adaptación
Móvil: Cápsulas Glass sin líneas inferiores; teclado no oculta Guardar.; Tablet: Ancho de formulario moderado.; Escritorio: Panel de cuenta; campos no se estiran sin necesidad.; css_320: Cápsulas Glass sin líneas inferiores; teclado no oculta Guardar. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Ancho de formulario moderado. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Panel de cuenta; campos no se estiran sin necesidad. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- Cancelar no escribe; error no borra lo introducido.
- Cambiar usuario no deja datos anteriores visibles.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.

### Dependencias


### Precisiones
- Se eliminan rayas bajo nombre/correo: solo barra/cápsula Glass limpia, antes y después de escribir.
- Etiqueta permanece visible o programática según composición; no se pierde al introducir texto.
- Cambiar email no une cuentas ni activa campañas.

### Datos
Perfil autorizado; Campos editables por proveedor

### App futura
Mismos permisos y confirmaciones.


## 048. Direcciones

UI:G27 · Listar y editar direcciones con los campos que exige el proveedor.

### Entrada
Direcciones desde Mi cuenta.

### Elementos
1. Título Direcciones
2. Listado de direcciones guardadas y predeterminada si existe soporte
3. Nueva dirección
4. Formulario de alta/edición en el mismo flujo
5. Guardar / Cancelar; eliminar con cancelación disponible

### Acciones
- Nueva / editar → Abrir formulario con datos correspondientes → UI:G27, formulario
- Guardar → Validar y esperar confirmación real → UI:G27, listado
- Cancelar / Eliminar → Volver sin escribir / permitir cancelación y esperar respuesta → UI:G27, listado

### Estados
Cargando · Sin direcciones · Listado · Alta / edición · Validación / guardando / error / éxito · Sesión expirada

### Adaptación
Móvil: Una columna; etiquetas y errores claros, sin subrayados.; Tablet: Agrupar campos relacionados si caben.; Escritorio: Formulario de ancho controlado; listado en panel.; css_320: Una columna; etiquetas y errores claros, sin subrayados. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Agrupar campos relacionados si caben. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Formulario de ancho controlado; listado en panel. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- Datos se guardan solo tras respuesta real; cancelar no escribe.
- Formulario usable a 320 px y teclado virtual sin CTA tapado.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.

### Dependencias


### Precisiones
- Esquema México con campos reales; no imponer validaciones inventadas ni teléfono innecesario.
- Eliminar no cambia direcciones históricas en pedidos.
- Alta/edición/vacío son variantes; no requieren páginas duplicadas.

### Datos
Direcciones propias; País/campos exigidos por proveedor; Predeterminada si soportada

### App futura
Autocompletado y teclado apropiados sin alterar contrato.


## 049. Métodos de pago

UI:G28 · Acceder a una gestión real del proveedor solo si existe.

### Entrada
Métodos de pago desde Mi cuenta, solo tras verificar capacidad.

### Elementos
1. La figura de Cuenta hereda Miembro + nivel real y Saldo / monto verde. No cambia la disponibilidad condicional de gestión de métodos de pago.
2. Título y contexto del proveedor
3. Métodos gestionables realmente disponibles
4. Acciones seguras que el proveedor permita

### Acciones
- Métodos de pago desde cuenta → Abrir gestión segura compatible → Proveedor de pagos/cuentas

### Estados
No disponible: acceso oculto · Carga · Listado o vacío del proveedor · Error

### Adaptación
Móvil: Flujo seguro adaptable del proveedor.; Tablet: Según capacidades reales.; Escritorio: Según capacidades reales.; css_320: Flujo seguro adaptable del proveedor. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Según capacidades reales. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Según capacidades reales. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- Sin capacidad verificada, desaparece el acceso de Mi cuenta.
- Cualquier acción visible pertenece a un flujo real y seguro.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.
- Cotejar Corrección5: La figura de Cuenta hereda Miembro + nivel real y Saldo / monto verde. No cambia la disponibilidad condicional de gestión de métodos de pago.

### Dependencias
Modalidad y capacidad de gestión del proveedor

### Precisiones
- No crear almacenamiento de tarjetas ni capturar números bancarios en un formulario propio.
- No inventar Agregar/Eliminar tarjeta si el entorno no lo permite.
- Ficha condicional, no obligación de producir una pantalla local.
- CONFIRMADO C5 salvo las interpretaciones marcadas PROPUESTO: La figura de Cuenta hereda Miembro + nivel real y Saldo / monto verde. No cambia la disponibilidad condicional de gestión de métodos de pago.

### Datos
Capacidad de cuentas/proveedor

### App futura
Solo integración soportada; no formulario bancario propio.


## 050. Preferencias

UI:G29 · Guardar únicamente intereses/opciones que el sistema pueda aplicar.

### Entrada
Preferencias desde Mi cuenta cuando pueda guardar opciones.

### Elementos
1. Título Preferencias
2. Intereses por familias reales si existe personalización
3. Selección visible
4. Guardar y respuesta
5. Comunicaciones solo cuando proveedor y consentimientos permitan gestionarlas

### Acciones
- Elegir / guardar → Persistir con fuente real y confirmar → UI:G29
- Cancelar → Regresar sin aplicar borrador → UI:G18

### Estados
Carga · Seleccionado / sin seleccionar · Guardando · Error conservando selección · Guardado real · Capacidad no disponible: acceso limitado u oculto

### Adaptación
Móvil: Controles cómodos y filas que crecen.; Tablet: Mismo orden.; Escritorio: Panel de cuenta.; css_320: Controles cómodos y filas que crecen. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Mismo orden. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Panel de cuenta. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- Cada control visible se puede guardar y tiene respuesta real.
- Sin servicio de personalización no se anuncia contenido personalizado activo.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.

### Dependencias
Servicio de preferencias y comunicaciones

### Precisiones
- Intereses/guardado y comunicaciones son condicionales a proveedor real y consentimiento; no botones inertes.
- No pantalla ni toggles propios de movimiento/transparencia. Respetar automáticamente el sistema y mantener fallback opaco.
- Crear cuenta no activa marketing, WhatsApp o push por defecto.

### Datos
Familias reales; Preferencias persistidas; Consentimientos por canal si existen

### App futura
Preferencias sincronizadas solo mediante servicio común.


## 051. Ayuda y políticas

UI:G30 · Encontrar respuestas/contacto y leer los textos vigentes sin crear políticas nuevas.

### Entrada
Ayuda desde cuenta, enlaces del pie o acordeones de PDP.

### Elementos
1. Ayuda y documentos vigentes desde CMS.
2. Preguntas, envíos, cambios/devoluciones y privacidad existentes.
3. Contenido seleccionado con jerarquía legible.
4. Contacto como destino específico y WhatsApp autorizado donde corresponde.

### Acciones
- Tema / política → Abrir lectura vigente → UI:G30-A / documento CMS configurado
- Contacto / WhatsApp → Abrir página Contacto / canal sin envío automático → UI:G40 / EXT:whatsapp_direct
- Volver → Restaurar contexto → Origen permitido

### Estados
Contenido disponible · Carga · Error o documento no disponible con alternativa

### Adaptación
Móvil: Lectura a una columna; acordeones largos crecen.; Tablet: Ancho de lectura controlado.; Escritorio: Índice sencillo si el documento lo necesita; no columnas estrechas.; css_320: Lectura a una columna; acordeones largos crecen. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Ancho de lectura controlado. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Índice sencillo si el documento lo necesita; no columnas estrechas. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- Todos los textos tienen destino legible; sin links vacíos.
- Ayuda no envía mensajes ni expone datos privados al abrirla.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.

### Dependencias


### Precisiones
- No introducir plazos, cobertura, MSI, originalidad, horarios o devoluciones a partir del boceto.
- Las páginas legales comparten plantilla y contenido vigente; no se duplican como nuevos diseños.
- Footer mínimo conserva Buscar y Aviso de privacidad; no se añade Compartir catálogo.

### Datos
Políticas/textos vigentes; Canales y destinos autorizados

### App futura
Abrir texto compatible y conservar retroceso.


## 052. Ayuda · FAQ y lectura de políticas

UI:G30-A · Reutilizar contenido vigente con lectura accesible, sin nuevas condiciones comerciales.

### Entrada
Desde UI:G30; conservar disparador, consulta, variante y posición aplicables.

### Elementos
1. Título de la sección o política desde el CMS.
2. Preguntas reales como acordeones; respuesta crece al abrir.
3. Texto largo a una columna, con títulos, enlaces y espaciado legible.
4. Regreso al contexto de entrada y ayuda configurada.
5. En este boceto, barras grises representan texto CMS; no son texto final ni un estado de carga.

### Acciones
- Pregunta → abrir/cerrar respuesta dentro del flujo → Mismo contexto según respuesta
- Política desde pie/PDP → documento vigente → Mismo contexto según respuesta
- Volver → recuperar página y posición de origen → Mismo contexto según respuesta

### Estados
Contenido disponible · Consulta fallida con reintento · Documento retirado con alternativa

### Adaptación
Móvil: Una columna; mantener orden y áreas seguras.; Tablet: Redistribuir con espacio real, sin duplicar controles.; Escritorio: Redistribuir con espacio real, sin duplicar controles.; css_320: Una columna; mantener orden y áreas seguras. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Redistribuir con espacio real, sin duplicar controles. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Redistribuir con espacio real, sin duplicar controles. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- Solo textos CMS vigentes; FAQ se expande en el flujo sin cortes.
- Lectura a320px/200% mantiene títulos, enlaces y regreso; barras de boceto no son copy final.
- Contacto y política tienen bindings válidos; si no existen no se publica un enlace inerte.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.

### Dependencias
Texto íntegro vigente de políticas/FAQ al conectar CMS


## 053. Capas y regreso al origen

UI:G31 · Cerrar una capa conservando el contexto y sin enviar al usuario a otra sección.

### Entrada
Menú, filtro, ordenar, vista rápida, zoom, reposición o beneficios abiertos desde su disparador real.

### Elementos
1. Título de capa y cierre X
2. Contenido de la capa con foco contenido
3. Origen registrado: ficha, elemento, producto/variante, consulta/filtros y posición
4. Retorno al disparador o alternativa lógica si ya no existe

### Acciones
- X / Escape / regreso del sistema → Cerrar solo la capa superior y restaurar contexto; filtros descartan borrador sin aplicar → Disparador de origen
- Navegar desde vista rápida a PDP → Cerrar la capa y guardar origen; no dejar un modal oculto bajo la página → UI:G10
- Volver de PDP o proveedor externo → Recuperar listado y selección; si el origen desapareció, enfocar título/listado cercano sin bucle → Origen válido o UI:G05

### Estados
Capa abierta / cerrada · Origen vigente / retirado · Teclado virtual · Datos actualizados mientras está abierta

### Adaptación
Móvil: Panel desplazable; X y acción final fuera de la barra/teclado. Retroceso cierra la capa cuando corresponda a su implementación.; Tablet: Panel centrado; touch/teclado con el mismo retorno.; Escritorio: Fondo inerte; foco visible devuelto. No abrir capas duplicadas por pulsación repetida.; css_320: Panel desplazable; X y acción final fuera de la barra/teclado. Retroceso cierra la capa cuando corresponda a su implementación. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Panel centrado; touch/teclado con el mismo retorno. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Fondo inerte; foco visible devuelto. No abrir capas duplicadas por pulsación repetida. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- Cerrar zoom devuelve a la foto de PDP; cerrar vista rápida devuelve a la tarjeta.
- Cerrar filtro no aplica borrador; el listado conserva selección previa.
- No historial artificial con múltiples retornos a la misma capa; no prometer que Escape funciona en el diálogo externo del proveedor.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.

### Dependencias
Gestión real de historia/estado/foco por el storefront o app

### Precisiones
- Contrato compartido, no pantalla nueva ni botón Atrás adicional en vista rápida.
- Tocar fuera solo cierra si esa conducta se define; nunca es la única salida.
- El regreso a contenido privado revalida sesión antes de mostrarlo.


## 054. Acceso cancelado, fallido o sesión expirada

UI:G32 · Recuperar el acceso sin perder el destino deseado ni revelar datos privados.

### Entrada
Proveedor Google/Apple/correo cancelado o con error, código caducado o petición privada con sesión vencida.

### Elementos
1. Icono de acceso centrado encima de No pudimos iniciar sesión.
2. Estado textual separado para cancelación, fallo o sesión vencida.
3. Correo conservado cuando fue introducido; métodos compatibles operativos.
4. Reintentar / usar otro método / seguir explorando.
5. Origen interno permitido conservado sin datos privados antiguos.

### Acciones
- Reintentar / usar correo → Reiniciar solo el acceso; conservar datos permitidos y evitar solicitudes duplicadas → UI:G17 / UI:G17-A
- Acceso confirmado → Consultar identidad y permisos de nuevo, después volver al destino interno permitido → Destino protegido de origen / UI:G18
- Cancelar / seguir explorando → Salir sin crear cuenta ni generar beneficio; carrito conserva su política real → Catálogo o página pública de origen

### Estados
Cancelado por persona · Fallo de red/proveedor · Código inválido/caducado · Sesión expirada · Identidad cambiada · Método no configurado: acceso no publicado

### Adaptación
Móvil: Mensaje junto al formulario; salida siempre visible. Volver del proveedor recupera el mismo contexto.; Tablet: Formulario compacto y teclado alcanzable.; Escritorio: Mismo estado con teclado; no interpretar una ventana cerrada como error de cuenta ni éxito.; css_320: Mensaje junto al formulario; salida siempre visible. Volver del proveedor recupera el mismo contexto. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Formulario compacto y teclado alcanzable. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Mismo estado con teclado; no interpretar una ventana cerrada como error de cuenta ni éxito. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- Cancelar Google/Apple no muestra error rojo de pago ni inicia sesión.
- Sesión vencida retira datos privados; acceder restaura solo datos del usuario actual.
- Callback/returnTo acepta únicamente destinos internos permitidos; retorno o correo coincidente no fusiona identidades.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.

### Dependencias
Métodos activos, callbacks/dominios y sesión del proveedor; Permisos por cuenta y destino de retorno seguro

### Precisiones
- Google/Apple/correo son intención CONFIRMADA; las capacidades activas siguen pendientes de comprobar.
- No agregar contraseña, recuperación o unión de cuentas que no existan.
- No bonos por acceder, recargar o cambiar proveedor.


## 055. Contenido no disponible y enlace retirado

UI:G33 · Dar una salida concreta cuando la ruta o el contenido solicitado ya no existe.

### Entrada
URL inválida, producto/colección/aviso/documento retirado o acceso sin autorización al recurso.

### Elementos
1. Cabecera y navegación pública normal
2. Título breve de contenido no disponible
3. Contexto público permitido, sin datos privados
4. Volver cuando hay origen válido
5. Explorar productos / Ayuda según contexto

### Acciones
- Volver → Restaurar un origen válido conocido sin repetir una ruta rota → Origen válido
- Explorar productos → Abrir catálogo general manteniendo compra invitada → UI:G05
- Ayuda → Abrir apoyo vigente cuando corresponde a un documento/pedido → UI:G30

### Estados
404 real · Contenido retirado · Privado sin acceso: respuesta sin revelar existencia · Error temporal separado con Reintentar

### Adaptación
Móvil: Una columna, navegación y acción principal alcanzables a 320 px.; Tablet: Mismo texto y salida; no añadir ilustración de relleno.; Escritorio: Ancho de lectura controlado; ninguna redirección automática a Inicio.; css_320: Una columna, navegación y acción principal alcanzables a 320 px. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Mismo texto y salida; no añadir ilustración de relleno. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Ancho de lectura controlado; ninguna redirección automática a Inicio. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- Error de red no se convierte en 404; sí ofrece Reintentar.
- Pedido o producto histórico retirado conserva datos permitidos en su contexto autorizado, sin inventar reemplazo.
- Una petición ajena no revela número, dirección o correo de otro cliente.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.

### Dependencias
Estado real HTTP/datos y permisos del recurso; Rutas de fallback configuradas

### Precisiones
- Grupo404/título/texto/acciones centrado en área útil, sin redirección automática. Interpretación PROPUESTA de la marca sin verbo en p58.
- Es plantilla compartida, no una URL distinta por cada recurso.
- Error de red ofrece Reintentar; agotado por variante no es404. Permisos no revelan datos de terceros.


## 056. Permiso de notificaciones de app

UI:G34 · Representar permisos de app solo si existe el canal de notificaciones que los necesita.

### Entrada
Persona solicita activar avisos en una app operativa con canal push comprobado.

### Elementos
1. Campana centrada arriba de Tus avisos; texto explicativo debajo, conjunto centrado en área útil.
2. Activar avisos voluntario y Ahora no.
3. Diálogo real del sistema, fuera de personalización Glass.
4. Permitido / denegado / no disponible; continuar siempre.
5. Abrir ajustes solo con capacidad/destino reales.

### Acciones
- Activar avisos → Solicitar permiso real una vez desde una acción explícita → Diálogo del sistema
- Denegar / continuar sin activar → Conservar compra y avisos dentro de la cuenta cuando existan → UI:G25 / UI:G29
- Abrir ajustes, si corresponde → Abrir destino seguro compatible y releer permiso al volver → Ajustes reales del sistema

### Estados
No solicitado · Permitido · Denegado · No disponible/no implementado · Regreso de ajustes

### Adaptación
Móvil: Solo builds de app con canal integrado. La web utiliza su flujo real o no muestra esta opción.; Tablet: Mismo requisito de capacidad y permiso; adaptar diálogo del sistema.; Escritorio: No trasladar un control nativo ficticio al sitio de escritorio.; css_320: Solo builds de app con canal integrado. La web utiliza su flujo real o no muestra esta opción. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Mismo requisito de capacidad y permiso; adaptar diálogo del sistema. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: No trasladar un control nativo ficticio al sitio de escritorio. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- Si no hay push integrado, esta ficha no crea acceso ni solicitud.
- Denegar no bloquea explorar, comprar o consultar pedidos.
- No pedir cámara, contactos, ubicación u otros permisos sin una función autorizada y necesaria.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.

### Dependencias
Build nativo, canal push, consentimiento y soporte del sistema

### Precisiones
- Modelo condicional PROPUESTO; no activa ni promete push, WhatsApp o email.
- El diálogo nativo no se dibuja como Glass personalizado.
- Permiso del dispositivo no equivale a consentimiento de marketing de todos los canales.


## 057. Opciones reales y agregado desde feed

UI:G35 · Elegir talla u otra opción real antes de agregar, sin inventar variantes ni tocar productos por el usuario.

### Entrada
PDP/vista rápida con opción de talla real o botón Agregar pequeño del feed específico solicitado en p11.

### Elementos
1. Producto y variante elegida
2. Color y talla solo cuando existan como opciones reales
3. Valores textuales de la fuente, con estado disponible/agotado
4. Precio, foto y disponibilidad de la combinación
5. Acción Agregar con confirmación real
6. En feed: corazón libre y botón pequeño con contenedor sobre zona libre de imagen

### Acciones
- Elegir talla/color → Resolver una combinación real y actualizar sus datos → Mismo componente / UI:G09 / UI:G10
- Agregar pequeño del feed → Si falta opción necesaria, abrir selección; si está válida, enviar una intención y confirmar → UI:G09 o UI:G10 si selección no cabe / misma sección
- Agregado confirmado / fallo → Actualizar contador y gota sin abrir carrito / conservar selección y explicar → Misma página

### Estados
Sin talla: selector omitido · Opción sin elegir · Combinación válida · Combinación inexistente · Variante agotada · Agregando / fallo conocido / incierto

### Adaptación
Móvil: Botones de opción con texto y área suficiente; no cubrir producto con el agregado superpuesto. Panel solo si hace falta elegir.; Tablet: Misma selección textual; no compactar por debajo de lectura/tacto.; Escritorio: Teclado y foco por grupo; no depender de hover o deslizar.; css_320: Botones de opción con texto y área suficiente; no cubrir producto con el agregado superpuesto. Panel solo si hace falta elegir. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Misma selección textual; no compactar por debajo de lectura/tacto. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Teclado y foco por grupo; no depender de hover o deslizar. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- No inventar S/M/L, números, equivalencias de país o guía de tallas si no existen.
- No agregar otra talla/color por falta de stock ni anunciar producto completo agotado por una opción.
- El Agregar superpuesto se aplica solo al feed marcado; corazón libre se propaga a las tarjetas de producto solicitadas.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.

### Dependencias
Opciones/variantes reales del catálogo; Regla de selección previa y stock por combinación

### Precisiones
- La presencia de talla es CONDICIONAL, no un nuevo filtro universal ni una promesa de calzado ya cargado.
- El nuevo botón de feed y corazón sin contenedor están CONFIRMADOS en anotación p11; su recuperación por falta de variante es PROPUESTA.
- Cantidad, talla y color deben quedar identificados también en carrito/pedido. No crear guía de medidas comercial de muestra.


## 058. Búsqueda y filtros: recuperar resultados

UI:G37 · Distinguir cero resultados, error y selección en borrador sin perder la búsqueda.

### Entrada
Consulta global/local sin resultados, aplicación de filtros o fallo de una petición del listado.

### Elementos
1. Título/contexto del alcance actual
2. Consulta conservada y conteo real
3. Filtros aplicados retirables
4. Mensaje de cero resultados o error, separados
5. Limpiar búsqueda/filtros o Reintentar según causa
6. Mantener Ordenar/Filtros como acciones independientes

### Acciones
- Quitar filtro / limpiar → Actualizar el alcance actual y anunciar nuevo conteo; no saltar a otra colección → UI:G05 / UI:G05-A / UI:G06 de origen
- Reintentar → Repetir la consulta de lectura vigente; ignorar respuesta antigua → Mismo listado
- Aplicar / cancelar panel → Aplicar borrador confirmado / descartarlo y devolver foco → UI:G07/G08 → listado de origen

### Estados
Consulta vacía · Buscando · 0 resultados confirmado · Error con datos escritos conservados · Borrador distinto del aplicado · Respuesta tardía · Sin opciones de una faceta

### Adaptación
Móvil: Paneles desplazables; 320 px y teclado no tapan cierre/aplicar. No línea bajo el texto.; Tablet: Aumentar espacio de grupos y conservar retorno.; Escritorio: Lateral/popover con mismo contrato; conteo anunciado sin mover foco.; css_320: Paneles desplazables; 320 px y teclado no tapan cierre/aplicar. No línea bajo el texto. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Aumentar espacio de grupos y conservar retorno. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Lateral/popover con mismo contrato; conteo anunciado sin mover foco. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- Error no presenta No hay resultados ni borra selección.
- Nombre local permanece local; buscar global no cambia silenciosamente a una colección.
- No filtrar solo los productos de la página visible; precio/color/oferta/stock pertenecen a combinación real.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.

### Dependencias
Consulta/filtrado/orden admitidos por la fuente; Opciones y conteos reales

### Precisiones
- Grupo de vacío confirmado completamente centrado en área útil; no sobre cabecera, barra o teclado.
- Chips: muestra a la izquierda, nombre, X más grande/firme próxima al borde derecho con margen; área independiente sin solaparse.
- X quita solo ese filtro, nombre accesible Quitar filtro + valor; estado y conteo se anuncian.
- No crear sugerencias, populares o historial sincronizado sin fuente.


## 059. Ayuda, contacto y destinos externos

UI:G38 · Abrir ayuda o WhatsApp con un destino válido y conservar el regreso sin enviar mensajes automáticamente.

### Entrada
Ayuda desde un pedido/PDP, red social de menú/pie, grupo o contacto de mayoreo.

### Elementos
1. Contacto hereda la nueva página G40, con hero y texto superpuesto, botón y sección de grupos corregidos; ayuda contextual del pedido conserva retorno.
2. Título del tema o contacto seleccionado
3. Contenido CMS vigente o estado de consulta
4. WhatsApp/social con icono aprobado y etiqueta
5. Referencia pública/autorizada solo si viene del contexto
6. Alternativa de contacto vigente si el destino no está disponible

### Acciones
- Tema / pregunta → Abrir lectura o acordeón con contenido real y conservar posición → UI:G30-A / mismo tema
- Contactar / grupo / red → Abrir enlace autorizado del servicio; no enviar ni inscribir automáticamente → Destino externo configurado
- Regresar / enlace no disponible → Restaurar contexto o mostrar alternativa útil sin bucle → Origen / UI:G30 / UI:G33

### Estados
Tema cargado / error de CMS · Canal configurado / no disponible · Regreso de servicio externo · Grupo retirado · Ayuda con sesión expirada

### Adaptación
Móvil: Área de contacto alcanzable; icono y etiqueta con un destino claro. No depender de app externa instalada.; Tablet: Mismo contenido y canal; no prometer apertura idéntica entre sistemas.; Escritorio: Si abre otra pestaña, comunicarlo cuando corresponda y conservar la tienda; sin popup automático.; css_320: Área de contacto alcanzable; icono y etiqueta con un destino claro. No depender de app externa instalada. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Mismo contenido y canal; no prometer apertura idéntica entre sistemas. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Si abre otra pestaña, comunicarlo cuando corresponda y conservar la tienda; sin popup automático. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- Un enlace de grupo sin URL autorizada no se publica como botón funcional.
- Abrir WhatsApp no prueba que se envió mensaje, hubo reserva o se aceptó unirse.
- No incluir sesión/token/dirección/total privado en una URL de ayuda; solo referencias necesarias permitidas.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.
- Cotejar Corrección5: Contacto hereda la nueva página G40, con hero y texto superpuesto, botón y sección de grupos corregidos; ayuda contextual del pedido conserva retorno.

### Dependencias
Contenido CMS y URLs de canales/grupos autorizados; Capacidad de apertura externa/retorno en cada plataforma

### Precisiones
- Redes del menú: círculo Glass y nombre debajo, conjunto centrado. No generalizar el círculo a todos los WhatsApp.
- WhatsApp usa un único logo reconocido, delineado limpio, verde#3B7030 libre junto al control de contacto.
- No chat interno, tickets, horarios ni SLA nuevos. Contacto tiene ficha UI:G40; enlaces externos siguen este contrato.
- CONFIRMADO C5 salvo las interpretaciones marcadas PROPUESTO: Contacto hereda la nueva página G40, con hero y texto superpuesto, botón y sección de grupos corregidos; ayuda contextual del pedido conserva retorno.


## 060. Compra invitada · envío e inicio de sesión

UI:G39 · Conservar compra invitada y aplicar envío gratis solo con cuenta autenticada.

### Entrada
UI:G14 o UI:G15 sin cuenta autenticada.

### Elementos
1. Productos, variantes, cantidades y subtotal confirmado conservados.
2. Invitado: tarifa real según dirección, sin importe/total final supuesto antes de cotizar.
3. Iniciar sesión recibe halo C y énfasis principal; Continuar como invitado permanece secundario y operativo.
4. Acceso o creación de cuenta según modalidad real, con retorno al mismo carrito/entrega.
5. Cuenta autenticada reconocida: envío cero real; cambio/salida de identidad recalcula y reconfirma total.

### Acciones
- Iniciar sesión → Autenticar o crear cuenta según proveedor; conservar carrito y volver, releer tarifa/total → UI:G17 → UI:G14 o UI:G15 de origen
- Continuar como invitado → Solicitar dirección y cotizar tarifa real sin obligar a registro → UI:G15
- Cerrar sesión / cambiar identidad → Limpiar privados e invalidar cotización anterior antes de recalcular → Mismo carrito/entrega

### Estados
Invitado sin dirección · Cotizando · Tarifa confirmada · Cuenta autenticada con cero real · Sesión vencida o servicio fallido

### Adaptación
Móvil: Una columna; mantener orden y áreas seguras.; Tablet: Redistribuir con espacio real, sin duplicar controles.; Escritorio: Redistribuir con espacio real, sin duplicar controles.; css_320: Una columna; mantener orden y áreas seguras. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Redistribuir con espacio real, sin duplicar controles. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Redistribuir con espacio real, sin duplicar controles. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- Halo/énfasis corresponde a Iniciar sesión; invitado permanece disponible sin cuenta forzada.
- Cancelar acceso devuelve al mismo contexto con todas las líneas y permite continuar invitado.
- Solo identidad autenticada reconocida por checkout recibe gratuidad; un correo escrito no basta.
- Tras entrar/salir/cambiar identidad o dirección, total y envío se recalculan antes de pagar.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.

### Dependencias
Regla servidor de envío gratis con cuenta; Tarifas invitado configuradas; Identidad reconocida en checkout; Modo test para verificar transición


## 061. Contacto

UI:G40 · Reunir contacto y comunidades con la composición aportada y enlaces reales, sin mensajes automáticos.

### Entrada
Contacto desde Ayuda/pie, menú si se configura, o ruta semántica de Contacto.

### Elementos
1. Hero con título y descripción superpuestos, no separados debajo. Botón: Enviar Whatsapp al 826 106 6868, una línea con márgenes. Después Únete / A nuestros grupos de emprendedores, alineado izquierda; luego tres botones Grupo1/Grupo2/Facebook y redes como antes.
2. Cabecera común y hero B31 con copy exacto recibido.
3. Contáctanos / Estamos para ayudarte.
4. Enviar Whatsapp al 826 106 6868 → Únete / A nuestros grupos de emprendedores → Grupo1 → Grupo2 → Grupo de Facebook; etiqueta y descripción recibidas.
5. Síguenos en redes / Descubre novedades, lanzamientos y más.; Instagram, Facebook y TikTok con activos aprobados.
6. Pie común cuando corresponda al sitio y barra inferior móvil con safe area.

### Acciones
- WhatsApp → Abrir contacto autorizado sin enviar mensaje automáticamente → EXT:whatsapp_direct
- Grupo 1 / Grupo 2 / Grupo de Facebook → Abrir invitación oficial si está configurada; unión dentro del proveedor → EXT:whatsapp_group_1 / EXT:whatsapp_group_2 / EXT:facebook_group
- Instagram / Facebook / TikTok → Abrir perfil oficial válido conservando regreso → EXT:social_profile

### Estados
Carga de hero con dimensiones reservadas · Canal configurado · Invitación/perfil no disponible: oculto en producción · Regreso de proveedor externo · Error de contenido con alternativa WhatsApp vigente

### Adaptación
Móvil: Una columna de tarjetas limpias; icono y texto no compiten, barra no tapa el último enlace.; Tablet: Conservar orden; ampliar lectura y espacios con agrupación de contactos.; Escritorio: Hero y contenido con ancho controlado; contactos pueden formar grilla en el mismo orden de lectura.; css_320: Una columna de tarjetas limpias; icono y texto no compiten, barra no tapa el último enlace. Reflow a320 CSS px sin desplazamiento horizontal de la página; texto200%, labels completos; safe areas/teclado/barra no ocultan acciones. Carruseles o imagen ampliada pueden desplazarse dentro de su componente con alternativa.; css_768: Conservar orden; ampliar lectura y espacios con agrupación de contactos. A768 CSS px mantener secuencia y áreas de48 px propuestas; admitir orientación y texto ampliado sin comprimir el modelo móvil.; css_1440: Hero y contenido con ancho controlado; contactos pueden formar grilla en el mismo orden de lectura. A1440 CSS px usar ancho máximo legible/columnas según contenido; sin barra móvil permanente duplicada ni hover como único acceso.

### Aceptación
- Orden y copy coinciden con received_copy.Contacto; blanco puro y sombras tenues.
- Solo WhatsApp directo tiene URL aportada; grupos/perfiles sin datos no se inventan ni se publican como botones inertes.
- Abrir canal no envía mensajes, no une grupos ni prueba atención/entrega.
- Teclado/320px/200% alcanzan todas las tarjetas y regreso sin recortes.
- A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.
- Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.
- Cotejar Corrección5: Hero con título y descripción superpuestos, no separados debajo. Botón: Enviar Whatsapp al 826 106 6868, una línea con márgenes. Después Únete / A nuestros grupos de emprendedores, alineado izquierda; luego tres botones Grupo1/Grupo2/Facebook y redes como antes.

### Dependencias
Confirmar/introducir invitaciones oficiales Grupo1/Grupo2/Facebook y perfiles sociales; Binding de página Contacto; Vigencia de claims del hero en CMS

### Precisiones
- La imagen de referencia es composición, no evidencia de una integración operativa.
- Se reutiliza la silueta WhatsApp reconocible verde; no aproximación deformada ni efecto luminoso continuo.
- CONFIRMADO C5 salvo las interpretaciones marcadas PROPUESTO: Hero con título y descripción superpuestos, no separados debajo. Botón: Enviar Whatsapp al 826 106 6868, una línea con márgenes. Después Únete / A nuestros grupos de emprendedores, alineado izquierda; luego tres botones Grupo1/Grupo2/Facebook y redes como antes.

### Datos
Copy CMS recibido; B31 y referencia de Contacto; URLs autorizadas por canal


## 062. Inicio · fin del feed y banner único

UI:G01 / UI:G01-B · Para ti precede al banner Mayoreo. Lo más buscado mantiene su propio nombre.

### Secuencia confirmada

Banners → Categorías → Marcas → Nueva colección → Lo más buscado → Para ti → Mayoreo único → servicios → registro → pie. Ninguna imagen extra insertada bajo el banner.

### CTA vigente

Comenzar a vender superpuesto, control nativo Glass que abre UI:G13. El texto editorial PRECIOS DE/mayoreo/A partir de 3 piezas conserva la referencia.

### Excepción documentada B04

Fuente exacta B04 conserva CONOCE MÁS. La variante editorial sin control permite poner el CTA solicitado en Corrección 4 sin dos botones ni alterar el texto editorial de la fotografía.

### Registro común

Regístrate en MONETTA REWARDS (negro); ENVÍO GRATIS (oro) para siempre (negro); GANA CASHBACK (verde) con cada compra (negro). Tres líneas independientes; botón con halo oro. La cuenta sigue siendo requisito de envío gratis.


## 063. Mayoreo · comunidad y continuación

UI:G13 · estructura de las dos referencias recibidas. El bloque de registro y el pie continúan después de recomendaciones.

### Estructura recibida

Tres pasos en una fila horizontal, comunidad y grupos; Beneficios; WhatsApp; recomendados; registro y pie. En móvil la fila puede desplazarse, sin apilar las tres tarjetas.

### Condiciones recibidas

La referencia incluye $800 de anticipo por pedido y 20 días para liquidar. Se conserva como copy recibido en los modelos; no se configura ni valida una política de apartados en esta entrega.

### Acción propuesta

Convertir Comienza a vender en botón al catálogo general, con regreso a Mayoreo, es PROPUESTO. No confundirlo con Comenzar a vender del banner Inicio, confirmado hacia Mayoreo. Grupos/WhatsApp requieren destinos reales.

### Productos y promesas

Recomendaciones se alimentan del catálogo real; precios del ejemplo no autorizan nuevas ofertas. Texto de ingresos/originalidad/garantías conserva fuente y requiere aprobación operativa antes de publicarse.


## 064. Contacto · lectura y accesos completos

UI:G40 · nueva página, con texto íntegro recibido y distribución móvil legible.

### Composición

Hero y copy → Contáctanos / Estamos para ayudarte → Enviar Whatsapp al 826 106 6868 → Únete / A nuestros grupos de emprendedores → Grupo 1 → Grupo 2 → Grupo de Facebook → Síguenos en redes / Descubre novedades, lanzamientos y más. → iconos sociales.

### Diseño

Blanco puro, tipografía editorial, botones y filas Glass discretos. WhatsApp verde fuera del botón; redes doradas con rótulo/nombre accesible. No usar el PNG de referencia como fondo único funcional.

### Responsive propuesto

Corrección 5: título y descripción permanecen superpuestos dentro del hero también en móvil, con el copy recibido. No crear un bloque de texto separado debajo de la imagen. Conservar las capas de lettering de referencia al implementar.

### Enlaces y ayuda

Teléfono recibido: +52 826 106 6868. Grupos, Facebook e Instagram/TikTok exigen URL oficial configurada. Al volver de otra app, conservar scroll; no unión ni envío automáticos.


# Adaptación por dispositivo


## 065. Inicio · escritorio y móvil

Mismo contenido y orden; cambia el espacio disponible. El primer banner es un estado del carrusel de tres, no un reemplazo de los otros dos.

Escritorio: cabecera con búsqueda y navegación; banner 2.4:1; categorías fotográficas en fila. Móvil: navegación inferior de cuatro destinos y carrusel horizontal. Reservar proporciones y altura al cargar. No reducir toda la web como una imagen.


## 066. Catálogo · tablet y reflow de 320 px

Anchos de referencia, no detección rígida de dispositivo. Los controles crecen y cambian de distribución cuando su contenido lo necesita.

### 320–430 CSS px

Una columna de producto cuando dos no conservan lectura/objetivos. Conservar barra de cuatro destinos. Chips saltan o desplazan en su propia región; texto de lectura sin scroll horizontal.

### 768–1024 CSS px

Dos columnas según espacio real y filtros en drawer. PDP puede pasar a dos zonas sin comprimir formulario. Teclado/orientación ajustan el área visible y el scroll.

### 1440 CSS px

Contenedor máximo propuesto 1344 px, márgenes 48. Filtros laterales y grilla flexible, búsqueda local separada de global. Barra móvil se sustituye por cabecera, sin duplicar controles.


## 067. Producto y cuenta · espacio amplio

Distribución amplia con el mismo contrato de variante, favoritos, saldo y nivel. Los datos visibles siguen siendo ejemplos de diseño.


## 068. Cuenta y servicios · adaptación común

El estado privado de cuenta es el mismo en web/app, condicionado a una identidad y una fuente compatibles.

Cuenta amplia: navegación lateral y panel de contenido; sidebar móvil: avatar, nombre, Miembro + nivel y Saldo, con datos reales. Sin identidad no se inventa nombre, nivel o cifra. Cambio de cuenta limpia primero los datos privados. Grupos y canales requieren fuente configurada. Reflow/200% y ambas orientaciones se prueban al implementar.


## 069. Contacto y Mayoreo · composición amplia

Los PNG completos de la galería permiten ampliar cada sección. En escritorio se conserva la composición editorial original de sus banners.

Contacto: hero fuente, contacto directo, tres tarjetas de comunidad y redes. Mayoreo: hero fuente, tres pasos en columnas, CTA, comunidad, beneficios, ayuda, recomendados, registro y pie. En tablet las filas se distribuyen según ancho, manteniendo lectura/acciones de 48px. En móvil se apilan sin alterar el copy.


## 070. Banners · copy exacto y lectura adaptable

Separar foto, capa editorial y control de UI. Las composiciones originales se conservan; no convertir fotografías o controles en una página rasterizada.


# Banners y fotografías · catálogo de activos


## 071. Banners · B01 / B02

Composición fuente con copy intacto. ID, destino semántico y procedencia enlazan con el manifiesto; las URLs reales se configuran por entorno.

### B01 · inicio_productos

Copy bloqueado:

Compra fácil
desde México

Destino semántico: Todos los productos

PNG: 03_banners/png/B01_inicio_productos.png
SVG: 03_banners/svg/B01_inicio_productos.svg

### B02 · inicio_marcas

Copy bloqueado:

Tus marcas fav
en un sólo lugar

Destino semántico: Todas las marcas

PNG: 03_banners/png/B02_inicio_marcas.png
SVG: 03_banners/svg/B02_inicio_marcas.svg


## 072. Banners · B03 / B04

Composición fuente con copy intacto. ID, destino semántico y procedencia enlazan con el manifiesto; las URLs reales se configuran por entorno.

### B03 · inicio_categorias

Copy bloqueado:

Miles
de modelos
originales por descubrir

Destino semántico: Todas las categorías

PNG: 03_banners/png/B03_inicio_categorias.png
SVG: 03_banners/svg/B03_inicio_categorias.svg

### B04 · inicio_mayoreo

Copy bloqueado:

PRECIOS DE
mayoreo
A partir de 3 piezas
CONOCE MÁS

Destino semántico: Página de Mayoreo

PNG: 03_banners/png/B04_inicio_mayoreo.png
SVG: 03_banners/svg/B04_inicio_mayoreo.svg


## 073. Banners · B05 / B06

Composición fuente con copy intacto. ID, destino semántico y procedencia enlazan con el manifiesto; las URLs reales se configuran por entorno.

### B05 · carteras_hombre

Copy bloqueado:

CARTERAS
DE HOMBRE

Destino semántico: Carteras de Hombre

PNG: 03_banners/png/B05_carteras_hombre.png
SVG: 03_banners/svg/B05_carteras_hombre.svg

### B06 · charms

Copy bloqueado:

CHARMS

Destino semántico: Charms

PNG: 03_banners/png/B06_charms.png
SVG: 03_banners/svg/B06_charms.svg


## 074. Banners · B07 / B08

Composición fuente con copy intacto. ID, destino semántico y procedencia enlazan con el manifiesto; las URLs reales se configuran por entorno.

### B07 · lentes

Copy bloqueado:

LENTES

Destino semántico: Lentes

PNG: 03_banners/png/B07_lentes.png
SVG: 03_banners/svg/B07_lentes.svg

### B08 · bolsos

Copy bloqueado:

BOLSOS

Destino semántico: Bolsos

PNG: 03_banners/png/B08_bolsos.png
SVG: 03_banners/svg/B08_bolsos.svg


## 075. Banners · B09 / B10

Composición fuente con copy intacto. ID, destino semántico y procedencia enlazan con el manifiesto; las URLs reales se configuran por entorno.

### B09 · calzado_hombre

Copy bloqueado:

CALZADO
DE HOMBRE

Destino semántico: Calzado de Hombre

PNG: 03_banners/png/B09_calzado_hombre.png
SVG: 03_banners/svg/B09_calzado_hombre.svg

### B10 · munequeras

Copy bloqueado:

MUÑEQUERAS

Destino semántico: Muñequeras

PNG: 03_banners/png/B10_munequeras.png
SVG: 03_banners/svg/B10_munequeras.svg


## 076. Banners · B11 / B12

Composición fuente con copy intacto. ID, destino semántico y procedencia enlazan con el manifiesto; las URLs reales se configuran por entorno.

### B11 · relojes

Copy bloqueado:

RELOJES

Destino semántico: Relojes de Mujer

PNG: 03_banners/png/B11_relojes.png
SVG: 03_banners/svg/B11_relojes.svg

### B12 · relojes_hombre

Copy bloqueado:

RELOJES
DE HOMBRE

Destino semántico: Relojes de Hombre

PNG: 03_banners/png/B12_relojes_hombre.png
SVG: 03_banners/svg/B12_relojes_hombre.svg


## 077. Banners · B13 / B14

Composición fuente con copy intacto. ID, destino semántico y procedencia enlazan con el manifiesto; las URLs reales se configuran por entorno.

### B13 · calzado_mujer

Copy bloqueado:

CALZADO
DE DAMA

Destino semántico: Calzado de Mujer

PNG: 03_banners/png/B13_calzado_mujer.png
SVG: 03_banners/svg/B13_calzado_mujer.svg

### B14 · bolsos_hombre

Copy bloqueado:

BOLSOS
DE HOMBRE

Destino semántico: Bolsos de Hombre

PNG: 03_banners/png/B14_bolsos_hombre.png
SVG: 03_banners/svg/B14_bolsos_hombre.svg


## 078. Banners · B15 / B16

Composición fuente con copy intacto. ID, destino semántico y procedencia enlazan con el manifiesto; las URLs reales se configuran por entorno.

### B15 · tarjeteros

Copy bloqueado:

TARJETEROS

Destino semántico: Tarjeteros

PNG: 03_banners/png/B15_tarjeteros.png
SVG: 03_banners/svg/B15_tarjeteros.svg

### B16 · perfumes_todos

Copy bloqueado:

PERFUMES

Destino semántico: Perfumes

PNG: 03_banners/png/B16_perfumes_todos.png
SVG: 03_banners/svg/B16_perfumes_todos.svg


## 079. Banners · B17 / B18

Composición fuente con copy intacto. ID, destino semántico y procedencia enlazan con el manifiesto; las URLs reales se configuran por entorno.

### B17 · accesorios

Copy bloqueado:

ACCESORIOS

Destino semántico: Accesorios

PNG: 03_banners/png/B17_accesorios.png
SVG: 03_banners/svg/B17_accesorios.svg

### B18 · crossbody

Copy bloqueado:

CROSSBODY

Destino semántico: Crossbody

PNG: 03_banners/png/B18_crossbody.png
SVG: 03_banners/svg/B18_crossbody.svg


## 080. Banners · B19 / B20

Composición fuente con copy intacto. ID, destino semántico y procedencia enlazan con el manifiesto; las URLs reales se configuran por entorno.

### B19 · tote

Copy bloqueado:

TOTES

Destino semántico: Tote

PNG: 03_banners/png/B19_tote.png
SVG: 03_banners/svg/B19_tote.svg

### B20 · bolsos_hombro

Copy bloqueado:

BOLSOS
DE HOMBRO

Destino semántico: De hombro

PNG: 03_banners/png/B20_bolsos_hombro.png
SVG: 03_banners/svg/B20_bolsos_hombro.svg


## 081. Banners · B21 / B22

Composición fuente con copy intacto. ID, destino semántico y procedencia enlazan con el manifiesto; las URLs reales se configuran por entorno.

### B21 · carteras

Copy bloqueado:

CARTERAS

Destino semántico: Carteras de Mujer

PNG: 03_banners/png/B21_carteras.png
SVG: 03_banners/svg/B21_carteras.svg

### B22 · bolsos_mano

Copy bloqueado:

BOLSOS
DE MANO

Destino semántico: De mano

PNG: 03_banners/png/B22_bolsos_mano.png
SVG: 03_banners/svg/B22_bolsos_mano.svg


## 082. Banners · B23 / B24

Composición fuente con copy intacto. ID, destino semántico y procedencia enlazan con el manifiesto; las URLs reales se configuran por entorno.

### B23 · perfumes_alternativo

Copy bloqueado:

PERFUMES

Destino semántico: Perfumes; alcance femenino por confirmar

PNG: 03_banners/png/B23_perfumes_alternativo.png
SVG: 03_banners/svg/B23_perfumes_alternativo.svg

### B24 · guess

Copy bloqueado:

GUESS

Destino semántico: Guess

PNG: 03_banners/png/B24_guess.png
SVG: 03_banners/svg/B24_guess.svg


## 083. Banners · B25 / B26

Composición fuente con copy intacto. ID, destino semántico y procedencia enlazan con el manifiesto; las URLs reales se configuran por entorno.

### B25 · tory_burch

Copy bloqueado:

TORY
BURCH

Destino semántico: Tory Burch

PNG: 03_banners/png/B25_tory_burch.png
SVG: 03_banners/svg/B25_tory_burch.svg

### B26 · marc_jacobs

Copy bloqueado:

MARC
JACOBS

Destino semántico: Marc Jacobs

PNG: 03_banners/png/B26_marc_jacobs.png
SVG: 03_banners/svg/B26_marc_jacobs.svg


## 084. Banners · B27 / B28

Composición fuente con copy intacto. ID, destino semántico y procedencia enlazan con el manifiesto; las URLs reales se configuran por entorno.

### B27 · kate_spade

Copy bloqueado:

KATE
SPADE

Destino semántico: Kate Spade

PNG: 03_banners/png/B27_kate_spade.png
SVG: 03_banners/svg/B27_kate_spade.svg

### B28 · coach

Copy bloqueado:

COACH

Destino semántico: Coach

PNG: 03_banners/png/B28_coach.png
SVG: 03_banners/svg/B28_coach.svg


## 085. Banners · B29 / B30

Composición fuente con copy intacto. ID, destino semántico y procedencia enlazan con el manifiesto; las URLs reales se configuran por entorno.

### B29 · michael_kors

Copy bloqueado:

MICHAEL
KORS

Destino semántico: Michael Kors

PNG: 03_banners/png/B29_michael_kors.png
SVG: 03_banners/svg/B29_michael_kors.svg

### B30 · steve_madden

Copy bloqueado:

STEVE
MADDEN

Destino semántico: Steve Madden

PNG: 03_banners/png/B30_steve_madden.png
SVG: 03_banners/svg/B30_steve_madden.svg


## 086. Banners · B31 / B32

Composición fuente con copy intacto. ID, destino semántico y procedencia enlazan con el manifiesto; las URLs reales se configuran por entorno.

### B31 · contacto

Copy bloqueado:

Tu boutique y
proveedor de
confianza.
Bienvenida a nuestro paraíso de
modelos originales de marcas que
amas, importados y con envíos
garantizados a todo México.

Destino semántico: Contacto

PNG: 03_banners/png/B31_contacto.png
SVG: 03_banners/svg/B31_contacto.svg

### B32 · mayoreo

Copy bloqueado:

MAYOREO
Obtén precios especiales
en productos originales
importados de tus
marcas favoritas

Destino semántico: Mayoreo

PNG: 03_banners/png/B32_mayoreo.png
SVG: 03_banners/svg/B32_mayoreo.svg


## 087. Asignación segura · nombres que requieren cuidado

No escoger recursos con una búsqueda ambigua. La relación exacta, dimensiones y hashes se entregan en manifiesto_banners.json.

| Origen | Uso final | Regla |
| --- | --- | --- |
| BANNER MARCA TORY BURCH.png | B26 · Marc Jacobs | Contenido y PDF p26 identifican Marc Jacobs; no usar en Tory Burch. |
| BANNER MARCA TORY BURCH(1).png | B25 · Tory Burch | No es duplicado del anterior; conservar ambos originales. |
| ICONO DE LENTES(1).JPG | Foto de cartera de hombre | No usar como Lentes. Etiqueta/nodo de catálogo Carteras de Hombre; no repetir la errata hacia bolsos. |
| B05 / B17 / B23 | Carteras de Hombre / Accesorios / Perfumes alternativo | Sin PNG de fondo separado: origen extraído del PDF proporcionado, no foto generada. |
| B03 / B18 / B29 | Inicio categorías / Crossbody / Michael Kors | Raster de PDF con encuadre distinto. Se integra PNG aportado proporcional, con capa de texto fuente; sin doble recorte. |
| B04 · fuente y UI | Original CONOCE MÁS; CTA final Comenzar a vender | Fuente exacta archivada; variante editorial omite solo control antiguo y usa botón nativo. Un único CTA. |
| B11/B12 · relojes | Accesorios → Relojes; contexto Mujer/Hombre si existe colección | Recibir un banner no crea nuevas ramas de navegación ni inventa pertenencia del producto. |


## 088. Fotos de categorías · Inicio 1

18 fotografías recibidas. Exclusivas de los carruseles de categoría de Inicio; navegación interna conserva la familia de iconos dorados.

Fotografías del bloque: ICONO  CALZADO DE DAMA.JPG, ICONO BOLSO DE HOMBRO.JPG, ICONO BOLSO DE MANO.JPG, ICONO CALZADO DE HOMBRE.JPG, ICONO DE ACCESORIOS.JPG, ICONO DE BOLSOS DE HOMBRE.JPG, ICONO DE BOLSOS.JPG, ICONO DE CARTERAS .AVIF, ICONO DE CARTERAS DE MUJER.JPG


## 089. Fotos de categorías · Inicio 2

18 fotografías recibidas. Exclusivas de los carruseles de categoría de Inicio; navegación interna conserva la familia de iconos dorados.

Fotografías del bloque: ICONO DE CROSSBODY.png, ICONO DE LENTES(1).JPG, ICONO DE LENTES.JPG, ICONO DE RELOJES DE HOMBRE.PNG, ICONO DE TARJETEROS.PNG, ICONO MUÑEQUERA.JPG, ICONO RELOJ DE MUJER.JPG, ICONO TOTE.JPG, INCONO DE BOLSOS.JPG


## 090. Uso de fotos y alternativas · sin nueva taxonomía

Familias y subniveles conservan el documento vigente. Las fotos no se convierten en nuevos botones de primer nivel.

### Familias en Inicio

Bolsos, Carteras, Perfumes, Calzado, Accesorios. Selección editorial propuesta: ICONO DE BOLSOS y CARTERAS genérica para sus familias; Calzado de Dama para familia Calzado; Accesorios para su familia.

### Fallback explícito

No llegó un ICONO de Perfumes independiente. Usar encuadre completo del fondo B16 como miniatura editorial, sin deformarlo ni atribuir género. Dos fotos genéricas de Bolsos son alternativas, no categorías nuevas.

### Fotos de subtipos

Crossbody, Tote, De mano, De hombro, Bolsos de Hombre, Muñequeras, Tarjeteros, Carteras de Mujer/Hombre, Calzado Hombre y Relojes se asignan a su nodo/contexto de Inicio. No a navegación interna.

### Jerarquía constante

Bolsos → Mujer, estilos y Hombre. Carteras → Mujer, Muñequeras, Carteras, Tarjeteros y Hombre. Perfumes → Mujer/Hombre. Calzado → Mujer, Deportivo, Casual y Hombre. Accesorios → Lentes, Relojes, Charms, Otros.

### Conservar fotografías

Originales byte por byte archivados. No retocar color, textura, logo, herrajes ni proporción. Miniaturas PNG son conversión de formato para diseño; no nuevas fotos ni mejora artificial de resolución.

### Producción

Nombres accesibles y texto de categoría junto a la foto. Si imagen repite el enlace, alt vacío; el nombre del enlace comunica destino. Reservar dimensiones y cargar carrusel progresivamente.


# Datos, accesibilidad y aceptación


## 091. Contratos y aceptación por ficha · 01

Hereda componentes comunes. Son criterios para implementar y comprobar; no resultados de una prueba de software.

| Ficha | Datos / dependencias | Aceptar cuando |
| --- | --- | --- |
| UI:G01; Inicio | Activos y destinos editoriales; Productos/variantes reales; Selección social manual; Registro compatible Envío gratis con cuenta confirmado; activar cashback solo con reglas e integración; Autoplay accesible; CMS y cuenta compatibles | Los tres banners abren productos, marcas y categorías, respectivamente.; El orden Nueva colección → Lo más buscado → Para ti → Mayoreo → servicios → registro → pie es idéntico en 320, 768 y 1440 CSS px.; Solo hay un banner Mayoreo inferior, con Comenzar a vender; registro valida y conserva el correo ante fallo.; Sin historial no se afirma personalización; no se duplican productos ni se insertan imágenes de relleno.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.; Cotejar Corrección5: Registro: Regístrate en MONETTA REWARDS en negro; ENVÍO GRATIS en oro + para siempre negro; GANA CASHBACK verde + con cada compra negro. Cada texto en una línea al tamaño base; botón con halo oro. A zoom/reflow se permite crecer sin cortar. Pie gris muy tenue: Contacto, Envíos, Cambios y devoluciones, Mayoreo, Privacidad y Términos vigentes. Retirar Buscar del pie. |
| UI:G01-A; Inicio · Nueva colección |  Fecha de alta definida; Colección real | La tarjeta grande es una tarjeta de producto completa, sin botón de pausa ni imagen adicional de relleno.; Las miniaturas muestran hasta el conjunto real con al menos 40 únicos si existen; su selección y el destacado comparten variante/precio/fotos.; El cierre es flecha Glass libre con Ver Nueva colección debajo, un solo enlace.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.; Cotejar Corrección5: PROPUESTO por los dos trazos laterales de p13: controles Anterior/Siguiente sobre el área libre del destacado; no Pausar ni reactivar autoplay. |


## 092. Contratos y aceptación por ficha · 02

Hereda componentes comunes. Son criterios para implementar y comprobar; no resultados de una prueba de software.

| Ficha | Datos / dependencias | Aceptar cuando |
| --- | --- | --- |
| UI:G01-B; Inicio · Lo más buscado, Para ti y Mayoreo |  Selección editorial y activos; Datos de variante | El feed se titula Para ti; Lo más buscado permanece anterior y no se renombra.; Agregar superpuesto solo existe en el feed indicado y no tapa producto/favorito.; El banner Mayoreo queda después de Para ti y antes de servicios, una sola vez.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado. |
| UI:G02; Menú lateral | Árbol de colecciones; Marcas; URLs sociales verificadas; Identidad autorizada  | Última marca, Mayoreo y contacto alcanzables con teclado y 320 px.; Invitado no ve nombre/saldo de una sesión anterior. Autenticado muestra el nivel real junto a Miembro.; Cerrar conserva scroll/contexto y devuelve foco; redes forman un grupo centrado.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado. |
| UI:G03; Categorías | category_tree incluido en este archivo; IDs de colección y marcas  | Todos los niveles abren el contenido correspondiente.; Expandir no superpone contenido; texto 200% conserva nombres completos.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado. |
| UI:G04; Todas las marcas | Logo oficial por marca; Nombre accesible; Orden editorial y destino  | La tarjeta enfocada no queda oculta por otra.; Todas las marcas configuradas son alcanzables y tienen nombre accesible.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado. |


## 093. Contratos y aceptación por ficha · 03

Hereda componentes comunes. Son criterios para implementar y comprobar; no resultados de una prueba de software.

| Ficha | Datos / dependencias | Aceptar cuando |
| --- | --- | --- |
| UI:G05; Colección y catálogo | Colección por ID; Productos y variantes; Opciones normalizadas de filtros; Orden disponible  | Cada tarjeta muestra datos de una misma variante y conserva acciones independientes.; La búsqueda local no incorpora productos ajenos a la colección.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.; Cotejar Corrección5: Título contextual de categoría/marca pequeño y secundario; banner con sombra superior/inferior muy tenue, sin distorsionar la fotografía. |
| UI:G06; Búsqueda global | Consulta; Resultados globales; Precios/variantes reales  | Una búsqueda global y la misma búsqueda local tienen alcance correcto.; Enter busca; fallo conserva la consulta y no se presenta como cero resultados.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado. |
| UI:G07; Filtros | Opciones reales de marca/estilo/color; Selección aplicada y borrador; Conteo  | Cerrar sin aplicar conserva listado anterior.; Aplicar anuncia conteo sin mover foco; selección puede retirarse y limpiarse.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado. |
| UI:G07-A; Filtros · nuevos, ofertas y disponibilidad |  Datos booleanos/indexación reales; Fecha comercial definida; Disponibles usa disponibilidad de venta; no promete stock físico ni entrega inmediata | Recién llegados y Nuevo comparten una fecha definida; Ofertas no incluye mayoreo visual.; Color se reconoce por muestra y nombre; selección con estado accesible y aro tenue, sin subrayado.; Intersección de filtros, limpieza y cancelación se comportan igual en el catálogo completo, no solo en página visible.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado. |


## 094. Contratos y aceptación por ficha · 04

Hereda componentes comunes. Son criterios para implementar y comprobar; no resultados de una prueba de software.

| Ficha | Datos / dependencias | Aceptar cuando |
| --- | --- | --- |
| UI:G08; Ordenar | Opciones de orden del storefront; Orden activo  | Más nuevos y Más antiguos usan campo de orden real compatible con el alcance; si el motor global no lo admite, no fingirlo.; Nombre A-Z es PROPUESTO; Más vendidos requiere datos y decisión. Precios y relevancia solo donde soportados.; Cambiar orden preserva consulta/filtros; paginación no duplica ni pierde resultados.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado. |
| UI:G05-A; Colección de una marca |  ID de marca/colección configurado | B26 es Marc Jacobs aunque el archivo original contenga TORY BURCH en el nombre; Tory usa B25.; No se muestra inventario de otra marca como fallback ni se fabrican slugs.; Vuelta de PDP restaura marca, consulta, filtros, orden y posición.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.; Cotejar Corrección5: Hereda título contextual discreto y banner flotante de categoría; conserva marca y pertenencia reales. |


## 095. Contratos y aceptación por ficha · 05

Hereda componentes comunes. Son criterios para implementar y comprobar; no resultados de una prueba de software.

| Ficha | Datos / dependencias | Aceptar cuando |
| --- | --- | --- |
| UI:G13; Información de mayoreo | Página vigente; URL de entorno IDs/ruta real de la página; Regla real de tres piezas y elegibilidad; porcentaje no facilitado; Confirmación comercial de anticipo/plazo/textos de ingresos y garantías recibidos; URLs oficiales de grupos y redes; Contenido de registro y cuenta compatible | Usa B32 y orden de secciones recibido; Inicio/Cuenta/menú llevan al mismo contenido.; No se publican $800/20días/descuento automático u otras promesas sin confirmación y servicio; no se ejecutan descuentos en JS visual.; Grupos sin invitación validada no aparecen como botones funcionales; WhatsApp no envía mensaje ni reserva.; No precios ficticios de productos, catálogo compartido nuevo ni gratuidad universal.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.; Cotejar Corrección5: Título y descripción superpuestos en el banner también en móvil. Tres pasos uno al lado de otro en una única fila; en móvil se desplaza horizontalmente para conservar lectura, no se apilan. Mantener comunidad, botones, beneficios y continuación de las dos referencias. |
| UI:G09; Vista rápida | Producto y variante activa; Fotos asociadas; Precio/stock; Favorito  | Foto abre PDP de la variante elegida; color y favorito no navegan.; Cerrar restaura posición y foco de origen.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado. |
| UI:G10; Página de producto | Producto/variantes/imágenes; Precios/comparación/stock; Descripción/medidas confirmadas; Políticas vigentes; Recomendaciones reales Halo C confirmado; Servicio reposición; Reglas de beneficios/políticas | Variante de entrada, datos visibles y artículo añadido coinciden.; Comprar ahora no pierde otros productos del carrito.; Foto no abre pestaña; acordeones crecen y WhatsApp solo aparece en el correspondiente.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado. |


## 096. Contratos y aceptación por ficha · 06

Hereda componentes comunes. Son criterios para implementar y comprobar; no resultados de una prueba de software.

| Ficha | Datos / dependencias | Aceptar cuando |
| --- | --- | --- |
| UI:G10-A; Producto · detalles y recomendaciones |  Contenido vigente; Recomendaciones reales | Acordeones crecen en el flujo y muestran contenido CMS vigente, sin inventar descripción física.; WhatsApp se muestra solo al abrir el acordeón correspondiente; no crea reserva ni bloqueo de stock.; Relacionados → Más de la marca → Vistos hace un momento; sin historial se omite Vistos, y cada carrusel conserva cierre y tarjetas comunes.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado. |
| UI:G11; Zoom de producto | Fotografía original y resolución disponible; Índice de foto  | Se amplía/cierra con teclado; al salir se conserva posición de PDP.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado. |
| UI:G12; Aviso de reposición | ID de variante; Correo autorizado; Respuesta de servicio de reposición Proveedor/canal/consentimiento y disparador real de stock | Solo aparece para variante agotada en PDP y con servicio activo.; Repetir registro no duplica suscripción; cancelar no registra.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.; Cotejar Corrección5: Agotado: etiqueta compacta negra con texto blanco, más pequeña y más abajo, junto al borde inferior de la foto. Sin brillo/animación; disponibilidad por variante. |


## 097. Contratos y aceptación por ficha · 07

Hereda componentes comunes. Son criterios para implementar y comprobar; no resultados de una prueba de software.

| Ficha | Datos / dependencias | Aceptar cuando |
| --- | --- | --- |
| UI:G14; Carrito | Carrito confirmado; Cantidades/stock; Asignaciones de descuento; Importes/envío/moneda; Elegibilidad real; Crédito compatible Porcentaje/elegibilidad/combinación reales de mayoreo; Crédito y envío integrados | 2→3→4→2 refleja elegibilidad real; contador suma unidades.; Doble toque o respuesta incierta no duplica productos.; Eliminar última línea muestra vacío confirmado, no resumen de cero ni compra inerte.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.; Cotejar Corrección5: Cuenta en barra puede mostrar contador de notificaciones: badge oro/número negro sin modificar el icono. PROPUESTO contar no leídas, ocultar en cero y 99+ visual; fuente real, no sumar anuncios. |
| UI:G14-A; Carrito · modificar y recuperar |   | Más/menos/Eliminar se serializan por intención y bloquean repetición mientras hay petición.; Respuesta incierta obliga reconciliar antes de reenviar; error conocido conserva último estado confirmado.; Tras éxito cambian juntos línea, contador, elegibilidad y resumen; menos está indisponible en 1 y el número no simula botón.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado. |
| UI:G14-B; Carrito · dorado por elegibilidad | Carrito confirmado; Cantidades/stock; Asignaciones de descuento; Importes/envío/moneda; Elegibilidad real; Crédito compatible Porcentaje/elegibilidad/combinación reales de mayoreo; Crédito y envío integrados | 2→3→4→2 usa unidades elegibles reales y badge de unidades; el centro del botón conserva transparencia.; Doble pulsación no duplica intención; al fallar no aparece éxito ni gota.; Sin nueva adición, recarga/reconsulta conserva estado estático y no repite aviso/celebración.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado. |


## 098. Contratos y aceptación por ficha · 08

Hereda componentes comunes. Son criterios para implementar y comprobar; no resultados de una prueba de software.

| Ficha | Datos / dependencias | Aceptar cuando |
| --- | --- | --- |
| UI:G14-C; Carrito · resumen sin doble conteo | Carrito confirmado; Cantidades/stock; Asignaciones de descuento; Importes/envío/moneda; Elegibilidad real; Crédito compatible Porcentaje/elegibilidad/combinación reales de mayoreo; Crédito y envío integrados | Descuentos de línea/pedido se asignan una vez; comparación anterior no se resta otra vez.; Envío cero solo con cuenta autenticada; invitado usa tarifa real. Inicio/cierre de sesión recalcula antes de pagar.; Crédito opcional como medio de pago, sin doble resta; subtotal, cargos y total coinciden con respuesta autoritativa. |
| UI:G15; Checkout y estado del pago | Checkout del proveedor; Contacto/dirección; Opciones de pago/envío; Total autoritativo; Estado de pago/pedido Plan, tipo de storefront y modalidad de cuentas; Proveedor y modo de prueba verificados | Cancelar/volver no pierde carrito ni duplica cobro.; Total final coincide; solo medios reales; prueba completa autorizada en modo de prueba.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado. |
| UI:G15-A; Checkout · dirección y entrega |  Plan, proveedor y modo de prueba verificados | Elegir dirección para esta compra no cambia la primaria de cuenta sin acción expresa.; Invitado ve tarifa real; cuenta ve cero solo cuando lo devuelve la regla real.; Cambio de identidad/dirección invalida cotización anterior y pide confirmar total.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado. |
| UI:G16; Confirmación de pedido | ID/número de pedido real; Estados separados de pago/envío; Líneas/importes  | Solo paid verificado muestra Pago completado/check; pending/unknown y fallo de lectura no se anuncian como éxito o rechazo.; Una referencia conserva el resultado sin reproducir efectos al recargar/reconsultar; no crea pedido, cobro, bono o cashback.; Ver pedido exige autorización del recurso y distingue estado de pago del envío.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado. |


## 099. Contratos y aceptación por ficha · 09

Hereda componentes comunes. Son criterios para implementar y comprobar; no resultados de una prueba de software.

| Ficha | Datos / dependencias | Aceptar cuando |
| --- | --- | --- |
| UI:G17; Acceso y registro de cuenta | Modalidad de cuenta; Correo; Respuesta de identidad Modalidad de cuentas; Google conectado; Disponibilidad de Apple por verificar en esta tienda; Callbacks/dominios por entorno y pruebas | Acceso vuelve al destino protegido original; invitado puede seguir comprando.; Error conserva correo; no expone datos de otra identidad.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.; Cotejar Corrección5: Acceso: reemplazar Seguir explorando por el texto exacto Seguir como invitado. Conserva compra y contexto. |
| UI:G17-A; Acceso · correo y verificación |  Modalidad de cuentas confirmada; Google/Apple y retorno verificados | Correo conserva etiqueta y error asociado, sin subrayado interior.; Código/reenvío solo según la modalidad real; límites y caducidad proceden del proveedor.; Éxito relee identidad y vuelve al origen; cancelar o caducar no crea cuenta, saldo ni pedido.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado. |
| UI:G18; Mi cuenta | Identidad autorizada; Capacidades de módulos  | Cada acceso visible funciona; no filas inertes.; Volver/cambiar de usuario no muestra datos de la identidad anterior.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.; Cotejar Corrección5: Cabecera: nombre real y Miembro + nivel; Saldo pequeño arriba de monto real verde. Ejemplo PRO/$1,345 no es dato real. Tras Cerrar sesión: slot de tarjetas publicitarias editables, proporción banner, material/deslizamiento de Todas las marcas, clicables. Sin activos/destinos aún: ocultar; no fijar Mayoreo. |


## 100. Contratos y aceptación por ficha · 10

Hereda componentes comunes. Son criterios para implementar y comprobar; no resultados de una prueba de software.

| Ficha | Datos / dependencias | Aceptar cuando |
| --- | --- | --- |
| UI:G19; MONETTA REWARDS | Compras elegibles; Nivel/progreso; Saldo disponible; Reglas/versiones de Rewards Compra elegible, base, acreditación, devoluciones y bonos | Hitos0/4/5/9/10 mantienen progreso/porcentaje/nivel/texto coherentes con datos reales.; ÉLITE es compacto y conserva lectura accesible sin10/10 ni duplicado exterior.; No numerales, aguja, línea central ni ornamentos de nivel; reduced motion es estático.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado. |
| UI:G20; Beneficios de nivel | Beneficios de nivel respaldados por reglas Reglas de cashback, bonos, límites y acumulación; Uso de bono en compra actual o siguiente; Configuración/prueba técnica del envío gratis con cuenta, decisión ya confirmada | Orden cashback → bono → envío y cantidades recibidas iguales en tres niveles; nivel domina cabecera.; ÉLITE usa únicamente la frase abreviada recibida en notes, sin el cierre anterior.; No Consulta condiciones, ornamentos o texto recortado; a200%/320px el contenido refluye y se desplaza con cierre alcanzable.; Solo se anuncia como beneficio disponible lo respaldado por reglas y servicio; la maqueta no acredita saldo.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado. |
| UI:G21; Saldo y movimientos | Saldo disponible; Movimientos y referencias autorizadas  | Error no se muestra como cero ni historial vacío.; Cada importe procede del servicio y no se duplica al reintentar.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado. |
| UI:G22; Mis pedidos | Pedidos de la identidad autenticada; Estados independientes  | Pedido creado no se confunde con pagado/enviado.; Otro usuario no obtiene historial anterior.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado. |


## 101. Contratos y aceptación por ficha · 11

Hereda componentes comunes. Son criterios para implementar y comprobar; no resultados de una prueba de software.

| Ficha | Datos / dependencias | Aceptar cuando |
| --- | --- | --- |
| UI:G23; Detalle de pedido | Pedido autorizado; Líneas históricas; Pagos/reembolsos; Envíos y tracking  | Envío parcial no declara entregado todo el pedido.; Recarga no crea cobro, bono o pedido; permisos por identidad en cada consulta.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.; Cotejar Corrección5: Barra horizontal de progreso de envío, contorno firme y tres círculos: camión/Preparando tu pedido → avión/Tu pedido va en camino → casa/Tu pedido fue entregado. Rellenar solo por estado real; pago separado. Sin porcentaje temporal inventado; parcial/cancelado/error no equivalen a entregado. |
| UI:G24; Favoritos | IDs guardados; Variante preferida; Alcance del almacenamiento Fuente común y regla de unión para sincronización | Fallos restauran estado; locales no se anuncian como sincronizados.; Producto retirado se informa y puede retirarse.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.; Cotejar Corrección5: Añadir Basado en tus gustos: carrusel de dos filas y mínimo60 productos/modelos únicos si existen. Carga progresiva, no duplicar para completar; intereses/búsquedas reales con fallback editorial sin historial. Cada producto conserva rápida/variante/favorito; cierre a recomendaciones y acceso textual propuestos. |
| UI:G25; Notificaciones | Avisos de identidad autorizada; Fecha/estado/destino Servicio de avisos/canales/consentimientos | Volver conserva posición; error al guardar leído no simula sincronización.; Todo aviso tiene destino válido o alternativa.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado. |


## 102. Contratos y aceptación por ficha · 12

Hereda componentes comunes. Son criterios para implementar y comprobar; no resultados de una prueba de software.

| Ficha | Datos / dependencias | Aceptar cuando |
| --- | --- | --- |
| UI:G26; Perfil | Perfil autorizado; Campos editables por proveedor  | Cancelar no escribe; error no borra lo introducido.; Cambiar usuario no deja datos anteriores visibles.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado. |
| UI:G27; Direcciones | Direcciones propias; País/campos exigidos por proveedor; Predeterminada si soportada  | Datos se guardan solo tras respuesta real; cancelar no escribe.; Formulario usable a 320 px y teclado virtual sin CTA tapado.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado. |
| UI:G28; Métodos de pago | Capacidad de cuentas/proveedor Modalidad y capacidad de gestión del proveedor | Sin capacidad verificada, desaparece el acceso de Mi cuenta.; Cualquier acción visible pertenece a un flujo real y seguro.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.; Cotejar Corrección5: La figura de Cuenta hereda Miembro + nivel real y Saldo / monto verde. No cambia la disponibilidad condicional de gestión de métodos de pago. |
| UI:G29; Preferencias | Familias reales; Preferencias persistidas; Consentimientos por canal si existen Servicio de preferencias y comunicaciones | Cada control visible se puede guardar y tiene respuesta real.; Sin servicio de personalización no se anuncia contenido personalizado activo.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado. |


## 103. Contratos y aceptación por ficha · 13

Hereda componentes comunes. Son criterios para implementar y comprobar; no resultados de una prueba de software.

| Ficha | Datos / dependencias | Aceptar cuando |
| --- | --- | --- |
| UI:G30; Ayuda y políticas | Políticas/textos vigentes; Canales y destinos autorizados  | Todos los textos tienen destino legible; sin links vacíos.; Ayuda no envía mensajes ni expone datos privados al abrirla.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado. |
| UI:G30-A; Ayuda · FAQ y lectura de políticas |  Texto íntegro vigente de políticas/FAQ al conectar CMS | Solo textos CMS vigentes; FAQ se expande en el flujo sin cortes.; Lectura a320px/200% mantiene títulos, enlaces y regreso; barras de boceto no son copy final.; Contacto y política tienen bindings válidos; si no existen no se publica un enlace inerte.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado. |
| UI:G31; Capas y regreso al origen |  Gestión real de historia/estado/foco por el storefront o app | Cerrar zoom devuelve a la foto de PDP; cerrar vista rápida devuelve a la tarjeta.; Cerrar filtro no aplica borrador; el listado conserva selección previa.; No historial artificial con múltiples retornos a la misma capa; no prometer que Escape funciona en el diálogo externo del proveedor.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado. |


## 104. Contratos y aceptación por ficha · 14

Hereda componentes comunes. Son criterios para implementar y comprobar; no resultados de una prueba de software.

| Ficha | Datos / dependencias | Aceptar cuando |
| --- | --- | --- |
| UI:G32; Acceso cancelado, fallido o sesión expirada |  Métodos activos, callbacks/dominios y sesión del proveedor; Permisos por cuenta y destino de retorno seguro | Cancelar Google/Apple no muestra error rojo de pago ni inicia sesión.; Sesión vencida retira datos privados; acceder restaura solo datos del usuario actual.; Callback/returnTo acepta únicamente destinos internos permitidos; retorno o correo coincidente no fusiona identidades.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado. |
| UI:G33; Contenido no disponible y enlace retirado |  Estado real HTTP/datos y permisos del recurso; Rutas de fallback configuradas | Error de red no se convierte en 404; sí ofrece Reintentar.; Pedido o producto histórico retirado conserva datos permitidos en su contexto autorizado, sin inventar reemplazo.; Una petición ajena no revela número, dirección o correo de otro cliente.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado. |
| UI:G34; Permiso de notificaciones de app |  Build nativo, canal push, consentimiento y soporte del sistema | Si no hay push integrado, esta ficha no crea acceso ni solicitud.; Denegar no bloquea explorar, comprar o consultar pedidos.; No pedir cámara, contactos, ubicación u otros permisos sin una función autorizada y necesaria.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado. |


## 105. Contratos y aceptación por ficha · 15

Hereda componentes comunes. Son criterios para implementar y comprobar; no resultados de una prueba de software.

| Ficha | Datos / dependencias | Aceptar cuando |
| --- | --- | --- |
| UI:G35; Opciones reales y agregado desde feed |  Opciones/variantes reales del catálogo; Regla de selección previa y stock por combinación | No inventar S/M/L, números, equivalencias de país o guía de tallas si no existen.; No agregar otra talla/color por falta de stock ni anunciar producto completo agotado por una opción.; El Agregar superpuesto se aplica solo al feed marcado; corazón libre se propaga a las tarjetas de producto solicitadas.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado. |
| UI:G37; Búsqueda y filtros: recuperar resultados |  Consulta/filtrado/orden admitidos por la fuente; Opciones y conteos reales | Error no presenta No hay resultados ni borra selección.; Nombre local permanece local; buscar global no cambia silenciosamente a una colección.; No filtrar solo los productos de la página visible; precio/color/oferta/stock pertenecen a combinación real.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado. |
| UI:G38; Ayuda, contacto y destinos externos |  Contenido CMS y URLs de canales/grupos autorizados; Capacidad de apertura externa/retorno en cada plataforma | Un enlace de grupo sin URL autorizada no se publica como botón funcional.; Abrir WhatsApp no prueba que se envió mensaje, hubo reserva o se aceptó unirse.; No incluir sesión/token/dirección/total privado en una URL de ayuda; solo referencias necesarias permitidas.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.; Cotejar Corrección5: Contacto hereda la nueva página G40, con hero y texto superpuesto, botón y sección de grupos corregidos; ayuda contextual del pedido conserva retorno. |


## 106. Contratos y aceptación por ficha · 16

Los IDs permanecen estables; no se reutiliza el identificador de la pantalla retirada.

| Ficha | Datos / dependencias | Aceptar cuando |
| --- | --- | --- |
| UI:G39; Compra invitada · envío e inicio de sesión |  Regla servidor de envío gratis con cuenta; Tarifas invitado configuradas; Identidad reconocida en checkout; Modo test para verificar transición | Halo/énfasis corresponde a Iniciar sesión; invitado permanece disponible sin cuenta forzada.; Cancelar acceso devuelve al mismo contexto con todas las líneas y permite continuar invitado.; Solo identidad autenticada reconocida por checkout recibe gratuidad; un correo escrito no basta.; Tras entrar/salir/cambiar identidad o dirección, total y envío se recalculan antes de pagar.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado. |
| UI:G40; Contacto | Copy CMS recibido; B31 y referencia de Contacto; URLs autorizadas por canal Confirmar/introducir invitaciones oficiales Grupo1/Grupo2/Facebook y perfiles sociales; Binding de página Contacto; Vigencia de claims del hero en CMS | Orden y copy coinciden con received_copy.Contacto; blanco puro y sombras tenues.; Solo WhatsApp directo tiene URL aportada; grupos/perfiles sin datos no se inventan ni se publican como botones inertes.; Abrir canal no envía mensajes, no une grupos ni prueba atención/entrega.; Teclado/320px/200% alcanzan todas las tarjetas y regreso sin recortes.; A320/768/1440 CSS px y texto200% no hay cortes, solapes o acciones inaccesibles; teclado conserva orden y foco.; Datos/destinos faltantes se identifican en entorno de revisión; en producción se oculta solo el control o bloque dependiente, sin botón inerte ni éxito simulado.; Cotejar Corrección5: Hero con título y descripción superpuestos, no separados debajo. Botón: Enviar Whatsapp al 826 106 6868, una línea con márgenes. Después Únete / A nuestros grupos de emprendedores, alineado izquierda; luego tres botones Grupo1/Grupo2/Facebook y redes como antes. |


## 107. Fuentes de datos · autoridad y estados

El catálogo JSON detalla cada ficha. Las imágenes muestran geometría; el servicio decide identidad, variantes, importes y estado.

| Dominio | Campos mínimos | Respuesta y límite |
| --- | --- | --- |
| Contenido | ID, jerarquía, orden, nombre, activo, copy bloqueado, destino/visibilidad. | CMS/versionado. No inventar slugs, redes o grupos; sin destino válido, omitir control. |
| Producto / variante | IDs, opciones reales, medios asociados, moneda/precio/comparación, disponibilidad, fecha comercial. | No mezclar fotografías o stock al cambiar color. Nuevo un mes desde origen definido; pendiente fecha técnica exacta. |
| Consulta | Texto, filtros, alcance, orden, cursor, conteo, request ID. | Resultados globales al motor, no filtrar solo la página cargada. Ignorar respuestas obsoletas y no duplicar. |
| Carrito / pago | Identidad, líneas/unidades, elegibilidad, descuentos asignados, tarifas, total, estado autoritativo. | Operación deduplicada/reconciliada. Crédito como pago una sola vez. No resultado inferido de animación. |
| Cuenta / Rewards | Identidad/permisos, nombre, nivel, compras elegibles, saldo disponible, movimientos. | No cero falso ante error. No acreditar por abrir, entrar repetidamente o recargar. Limpiar datos al cambiar cuenta. |
| Avisos / contacto | ID, fecha, leído, destino válido, permisos/canal y enlaces autorizados. | No asumir push, correo o WhatsApp habilitados. Grupo no se une ni mensaje se envía automáticamente. |


## 108. Rewards, envío y apartados · condiciones delimitadas

Se diseña la representación; los valores recibidos no validan rentabilidad, vigencia o automatización.

### Envío confirmado

Cuenta autenticada reconocida por checkout → envío gratis según configuración real. Invitado puede comprar con tarifa real. Cambiar dirección/identidad revalida método y total antes de pagar; no pintar cero sobre un cargo.

### Rewards recibido

PRO 1%/$100; VIP quinta compra 2%/$100; ÉLITE décima 3%/$200. No saldo pendiente visible; mantener disponible y movimientos. Falta definir compra elegible/base/momento, cancelación/devolución, vigencias/límites y acumulación.

### Bono pendiente

Existe contradicción compra que desbloquea/siguiente compra. No escoger silenciosamente. Prototipo puede documentar siguiente compra como propuesta; producción no anuncia condición hasta decisión e integración.

### Crédito nativo

Shopify documenta cuentas compatibles, excluye cuentas heredadas y no deja elegir libremente una parte del saldo. No diseñar selector de importe como función disponible sin comprobar alternativa. Crédito no crea por sí solo niveles/cashback.

### Apartado recibido

Mayoreo incluye copy $800 por pedido / 20 días en la referencia nueva. Es contenido recibido, pendiente de ratificación operativa para publicarse. WhatsApp abre consulta y nunca reserva/cobra automáticamente.

### Otras promesas

ENVÍO GRATIS / 5 - 7 días hábiles, originalidad, importación y MSI conservan su fuente. Las nuevas referencias dicen ingresos/garantías: no se validan aquí como resultados garantizados ni nueva política financiera.


## 109. Accesibilidad · criterios para el build

WCAG 2.2 AA es referencia verificable, no una certificación del PDF o de las maquetas. No existe una pantalla propia de ajustes en esta versión.

### Contraste

Texto normal 4.5:1; grande 3:1; estructura visual necesaria 3:1. Oro de identidad se usa como decoración/icono o título grande, no texto pequeño de bajo contraste. Información también con palabras/forma.

### Foco y lectura

Orden lógico, foco visible no oculto, nombres/roles/estados. Modales contienen Tab/Shift+Tab; Escape cierra y devuelve foco. Errores asociados y anuncio moderado tras respuesta real.

### Escala y reflow

Texto 200% y ancho 320 CSS px sin perder contenido o acciones. Orientación y teclado virtual no tapan cierre/compra. Crecer/scroll antes de reducir letra; precios y montos pueden saltar de línea.

### Objetivos táctiles

48×48 px objetivo interno propuesto en acciones principales. No es el mínimo AA, que es 24×24 CSS px con excepciones. Corazón y X conservan área amplia sin añadir una caja visible.

### Movimiento y material

Respetar preferencia reducida del sistema automáticamente. Sin gota, giro o destellos continuos en fallback; estado y texto permanecen. Glass puede usar superficie blanca opaca para lectura/rendimiento.

### Banners y controles

Texto editorial equivalente accesible y una sola lectura, no duplicada por imagen/DOM. CTA, carrusel y cerrar son controles reales independientes de la foto; navegación manual disponible. Las imágenes decorativas no crean anuncios redundantes.


## 110. Estados comunes y rendimiento

Metas de campo y comportamientos por implementar. No se midió el sitio durante esta entrega.

| Área | Especificación | Criterio |
| --- | --- | --- |
| Estados | Reposo, hover cuando aplique, foco, presionado, carga, error, éxito, vacío e indisponible. | No añadir estados imposibles ni declarar éxito antes de la respuesta. Conservar lo confirmado ante fallos. |
| LCP / INP / CLS | LCP ≤2.5 s, INP ≤200 ms, CLS ≤0.1, p75 de campo. | Metas, no resultados. Medir al publicar build; reservar ancho/alto y prioridad de imagen principal. |
| Imágenes | Fuente original, variantes responsivas, dimensiones y carga progresiva. | SVG con fotografías incrustadas es referencia visual; separar fotos/texto/componentes para web/app eficiente. |
| Blur / animación | Glass en controles; limitar capas y animaciones simultáneas. | Fallback opaco, sin cambios de layout. Evitar descargar de inicio todos los productos o galerías. |
| Datos y red | Petición identificada, carga específica, reintento seguro, deduplicación. | No mezclar búsqueda antigua, stock/variante o identidad. Resultado incierto consulta antes de repetir operación. |


# Auditoría y entrega a desarrollo


## 111. Auditoría · cobertura de la corrección

Preauditoría realizada antes de editar. La matriz CSV conserva una fila por anotación, con fuente, criterio y evidencia.

| Área | Trazabilidad | Cambio en esta entrega |
| --- | --- | --- |
| Inicio / registro | C4-01/02 | Negritas/capitalización; orden corregido y banner único con Comenzar a vender. |
| Menú / cuenta | C4-03–06/14–16 | Redes centradas; WhatsApp reconocible; inicial/nombre/nivel/saldo; REWARDS y separadores. |
| Vacíos / filtros | C4-07/08/21–23 | Centrado útil, X firme junto a orilla, error acceso/404/campana sobre texto. |
| Producto | C4-09–11 | Retiro de microcopy, corazón global guardado dorado y AGOTADO pequeño negro/blanco de Corrección 5. |
| Pago | C4-12/13 | Spinner abierto y X roja ante rechazo, con fuentes de estado distintas. |
| Rewards | C4-17–20 | Arco suave más grueso, cabeceras compactas y orden cashback→bono→envío. |
| Retirada / invitado | C4-24/25 | Sin pantalla propia de ajustes; Iniciar sesión con halo, invitado secundario. |
| Activos nuevos | B01–B32 / fotos | Banner por marca/categoría, copy protegido; fotos solo Inicio; Contacto y Mayoreo nuevos. |


## 112. Auditoría · límites y pendientes de publicación

La revisión final de esta entrega es documental y visual. El usuario excluyó pruebas de checkout para esta tarea.

### Revisión de archivo

77 anotaciones trazadas; 32 banners mapeados; 18 fotos y tres referencias inspeccionadas. Modelos/PDF/JSON comparten decisiones y activos. Inventario identifica versión, dimensiones y hashes.

### Interpretaciones registradas

404 centrado por consistencia (marca sin verbo); medidas y tiempos propuestos; Contacto/Mayoreo reflow de texto largo; B04 separa editorial y CTA. No se transforman en políticas nuevas.

### Integraciones sin probar

No se ejecutaron pago, checkout, descuentos, login, cuenta o app. Los estados y pruebas de aceptación describen cómo deben funcionar. Ni PDF ni PNG demuestran accesibilidad de un build.

### Antes de publicar funciones

Resolver cashback/bonos/apartados, fecha de Nuevo, grupos/redes reales y modalidad de cuenta/proveedores. Verificar regla de descuento y envío con cuenta en entorno autorizado cuando haya implementación.

### Alcance de app

Identidad, jerarquía y contrato compartidos; controles/áreas seguras/permisos se adaptan a iOS/Android. Una maqueta web no acredita soporte nativo, push o sincronización.

### Cierre de diseño

Se entrega documento completo, editable, catálogo, modelos y activos. La validación de la implementación será otra fase con rutas/datos/reflow/lectores/movimiento y compra de prueba autorizada.


## 113. Plan de implementación · orden y aceptación

No se exige un framework específico. Alexis decide arquitectura compatible y mantiene cambios revisables.

| Paso | Implementar | Aceptar cuando |
| --- | --- | --- |
| 1 · Base | Tokens, fuentes, componentes/estados y navegación; bindings de contenido. | Identidad y activos correctos, cuatro destinos, jerarquía y rutas configuradas por entorno. |
| 2 · Descubrir | Inicio, categorías/marcas, colecciones, búsqueda/filtros/orden. | Secuencia exacta; nuevos banners con copy intacto y fotos solo Inicio; retorno conserva contexto. |
| 3 · Producto | Tarjetas, rápida, PDP, zoom, recomendaciones, reposición. | Misma variante en foto/precio/stock; corazón independiente; agotado correcto; acciones reales. |
| 4 · Comprar | Carrito, elegibilidad, envío/cuenta, checkout/estado. | Datos autoritativos, deduplicación, sin doble conteo ni éxito falso; checkout nativo adaptado a límites reales. |
| 5 · Cuenta / ayuda | Rewards condicionado, pedidos, favoritos, avisos, perfil, Contacto/Mayoreo. | Fuente privada compatible, saldos reales, enlaces activos o controles omitidos; sin reglas inventadas. |
| 6 · Validación | Responsive, teclado, lector, contraste, carga/error, rendimiento y compra test. | Evidencia de build con casos del catálogo; defectos resueltos o alcance explícito antes de publicar. |


## 114. Archivos y continuidad · inicio único para la IA

Todo el paquete es portable. Los PNG/SVG son referencias y recursos visuales; los contratos describen el comportamiento que debe implementarse.

- 01_documentacion: Este maestro PDF y fuente editable Markdown.
- 02_sistema: Catálogo, tokens, inventarios y manifiesto de banners con asociaciones/huellas.
- 03_banners: 32 fuentes compuestas PNG/SVG, capas de texto, fondos de PDF y originales intactos; B04 editorial separado.
- 04_iconos: Iconos de interfaz y estados SVG/PNG, componentes; fotos de categoría como recursos separados.
- 05_maquetas: Pantallas, tramos y estados PNG2x/SVG. No equivalen a ese número de URLs o componentes.
- 06_referencias: PDF de banners original, tres referencias, fuentes/licencias y notas de procedencia.
- 07_auditoria: Trazabilidad de correcciones, revisión visual, integridad y límites de QA.
- 08_IA: INICIO_IA.md: orden de lectura, reglas obligatorias, acciones, datos y gates de publicación.


## 115. Fuentes y cambios · v4.1

Consulta local/visual del 05/11/2026. Fuentes oficiales verificadas para requisitos y límites; no son prueba de que la tienda los implemente.

- [W3C · WCAG 2.2](https://www.w3.org/TR/WCAG22/)

- [WAI-ARIA · Modal](https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/)

- [WAI · Tamaño mínimo](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html)

- [WAI · Movimiento automático](https://www.w3.org/WAI/WCAG22/Understanding/pause-stop-hide.html)

- [Shopify · Store credit](https://help.shopify.com/en/manual/customers/store-credit)

- [Shopify · Cuentas](https://help.shopify.com/en/manual/customers/customer-accounts)

- [Simple Icons · Fuente/CC0](https://github.com/simple-icons/simple-icons)

- [Google Fonts · Cormorant/OFL](https://github.com/google/fonts/tree/main/ofl/cormorantgaramond)

### Cambios respecto a v4.0

Corrección 5 aplicada sin rediseñar recursos vigentes: registro/pie, agotado, navegación, pedidos, Favoritos, Cuenta, Contacto y Mayoreo. Retiro del panel propio de accesibilidad, sin renumerar IDs. Ninguna función financiera nueva activada.

### Licencias y fidelidad

WhatsApp usa representación Simple Icons CC0, con requisitos de marca separados. Cormorant OFL adjunta. Fotografías/logotipos aportados: conservar derechos y autorización de uso originales, sin atribuir una licencia que no se entregó.

### Síntesis portable

MONETTA: blanco puro, oro #A58248, verde #3B7030, halo C; cuatro destinos; invitado compra; envío gratis con cuenta; variantes coherentes; botones reales; sin Modo Mayoreo/Compartir/Pausar; fotos Home únicamente.


## 116. Corrección 5 · registro de cambios vigente

122 marcas en17páginas. Se conserva la base; esta corrección reemplaza expresamente los puntos opuestos de C4.

### Producto y descubrimiento

Agotado: etiqueta compacta negra con texto blanco, más pequeña y más abajo, junto al borde inferior de la foto. Sin brillo/animación; disponibilidad por variante. Títulos de categoría/marca secundarios y sombra de banner tenue. Cheurones del destacado: propuesta mínima de navegación manual.

### Registro y pie

Registro: Regístrate en MONETTA REWARDS en negro; ENVÍO GRATIS en oro + para siempre negro; GANA CASHBACK verde + con cada compra negro. Cada texto en una línea al tamaño base; botón con halo oro. A zoom/reflow se permite crecer sin cortar. Pie gris suave, sin Buscar; enlaces vigentes de ayuda e información.

### Cuenta y notificaciones

Miembro + nivel y Saldo/monto reales. Badge oro/negro sin cambiar icono. Slot publicitario editable en Cuenta, sin Mayoreo fijo; futuro arte/destinos requeridos.

### Pedido y Favoritos

Barra horizontal de progreso de envío, contorno firme y tres círculos: camión/Preparando tu pedido → avión/Tu pedido va en camino → casa/Tu pedido fue entregado. Rellenar solo por estado real; pago separado. Sin porcentaje temporal inventado; parcial/cancelado/error no equivalen a entregado. Añadir Basado en tus gustos: carrusel de dos filas y mínimo60 productos/modelos únicos si existen. Carga progresiva, no duplicar para completar; intereses/búsquedas reales con fallback editorial sin historial. Cada producto conserva rápida/variante/favorito; cierre a recomendaciones y acceso textual propuestos.

### Contacto y Mayoreo

Título/copy superpuestos en el hero. Contacto: Enviar Whatsapp al 826 106 6868 → Únete / A nuestros grupos de emprendedores →3grupos →redes. Mayoreo:3tarjetas en fila horizontal, desplazable en móvil.

### Marcas sin texto

P11: se conserva arco vigente; p13: cheurones propuestos; p63: no se inventa acción a partir del asterisco. Carteras Hombre conserva su asignación aunque archivo diga LENTES(1).


## 117. Mayoreo · los tres pasos en una fila

C5-p24 · misma estructura horizontal en todos los tamaños. En móvil se desplaza la fila; no se convierte en tres filas.

### Escritorio

Tres tarjetas visibles una al lado de otra, alturas alineadas y espaciado uniforme. Mantener el copy recibido, iconos y material de MONETTA.

### Móvil y tablet

Una fila horizontal con tarjetas de ancho legible. Deslizar o usar teclado/controles para llegar a las tres, sin comprimir texto ni duplicar tarjetas. Las imágenes anteriores muestran el primer tramo de esa fila.

### Accesibilidad

Orden1–2–3 y etiquetas reales; cada tarjeta crece con texto200%. No arrastre como único acceso. Movimiento reducido sin desplazamiento animado.

### Condiciones recibidas

Los $800 y20días vienen de la referencia del usuario; siguen sujetos a ratificación operativa antes de publicarse como política. No se configuró dinero o apartado.