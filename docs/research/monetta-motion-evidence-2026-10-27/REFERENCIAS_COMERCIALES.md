# Referencias comerciales verificadas

28 de octubre de 2026 · Complementa [INVESTIGACION_V2.md](INVESTIGACION_V2.md), que ya incorpora estas referencias candidato por candidato.

Se revisaron grabaciones completas de **ocho apps iOS reales**: FARFETCH y Moda Operandi (lujo), Zara, HBX, Lyst, ASOS, Zalando y Shop, la app de compras de Shopify. De ellas se extrajeron **31 hojas de fotogramas** con tiempos, que están en `evidence/` y registradas en [sources.json](evidence/sources.json). Cada afirmación de este documento se comprobó en esas hojas, a veces cuadro por cuadro (30 fps).

## Correcciones a la versión anterior de este documento

- **FARFETCH no hace «vuelo al carrito».** ScreensDesign describe en 03:48 un botón que «se transforma en un icono de bolsa que viaja hacia arriba». En la grabación, el icono aparece en el centro de la pantalla con un anillo de progreso, se encoge en su sitio y da paso a una hoja de confirmación ([farfetch-icono-central](evidence/farfetch-icono-central.jpg)). Esa descripción de terceros era incorrecta.
- **Baymard, pestañas horizontales.** El artículo confirma que las personas pasaban por alto el contenido oculto tras pestañas, pero no contiene la cifra de «27 %» que traía el resumen de búsqueda; se retira. Las otras dos cifras sí están en las fuentes: solo el 24 % de los sitios móviles usa miniaturas en la galería ([Baymard](https://baymard.com/blog/always-use-thumbnails-additional-images)) y el 31 % no valida en línea ([Baymard](https://baymard.com/blog/inline-form-validation)).

## Resultados por candidato

| # · V2 | Evidencia comercial observada | Consecuencia para Monetta |
|---|---|---|
| 01 · R | **HBX:** indicador de carga dentro del botón (≈0,7 s), el botón pasa a «Checkout», insignia en la pestaña Bolsa y franja superior «✓ Item Added» ([hbx-agregar](evidence/hbx-agregar.jpg)). **Moda Operandi:** tres puntos dentro del botón (≈0,8 s) y franja verde superior ([moda-operandi-agregar](evidence/moda-operandi-agregar.jpg)). | Respaldada: dos apps confirman en el propio control. Ambas añaden además una franja; Monetta debe elegir una sola respuesta dominante, como ya pide la V2. |
| 02 · R | **FARFETCH**, **Zara** y **Zalando** confirman con una hoja inferior: producto y «Go to bag», o sugerencias ([farfetch-agregar-bolsa](evidence/farfetch-agregar-bolsa.jpg), [zara-agregar-rapido](evidence/zara-agregar-rapido.jpg), [zalando-hoja-deseos](evidence/zalando-hoja-deseos.jpg)). | La variante B (panel de confirmación) tiene precedente comercial directo. Se mantiene la comparación A/B. |
| 04 · R | **FARFETCH:** galería por deslizamiento con indicador de segmentos y una última tarjeta «Explore More»; sin miniaturas ([farfetch-galeria](evidence/farfetch-galeria.jpg)). **Moda Operandi:** puntos. | Las apps revisadas no usan miniaturas. Si Monetta las usa, se apoya en Baymard, no en la práctica del sector: hay que comparar con segmentos. |
| 05 · R | No observado: en los tramos revisados nadie amplió una foto. | Sigue sin precedente comercial móvil; se apoya en P1 (escritorio) y en la tarea de inspeccionar detalles. |
| 06 · R | **FARFETCH:** al cambiar de color abre otra ficha con esqueleto de carga (≈2 s) ([farfetch-variante-color](evidence/farfetch-variante-color.jpg)). | Contraejemplo: el cambio en el sitio que propone la V2 no es lo que hace FARFETCH. Se mantiene porque conserva el contexto, sin presentarlo como práctica del sector. |
| 07 · C | No verificable: el indicador de toque de las grabaciones tapa los controles. | Sin cambio. |
| 08 · C | **FARFETCH:** borde en la fila seleccionada, sin check animado. La pantalla se bloquea ≈1 s mientras recalcula «Show N Results» ([farfetch-filtro-color](evidence/farfetch-filtro-color.jpg)). | Respalda el check estático. El bloqueo es justo lo que la V2 evita. |
| 09 · C | Ver la sección del logo. | — |
| 10 · C | **FARFETCH:** la altura se anima ≈0,2 s y el chevron se invierte ([farfetch-plegable](evidence/farfetch-plegable.jpg)). | Ajuste: animar la altura (≤200 ms) solo en secciones cortas como envío o medidas. Los textos largos aparecen sin animación. |
| 11 · C | **FARFETCH:** sin indicador que se desplace; al tocar Inicio vuelve arriba con esqueleto ([farfetch-pestana-inicio](evidence/farfetch-pestana-inicio.jpg)). | Sin precedente; mantener estático. |
| 12 · C | **Zara:** tras eliminar, barra inferior con acción de deshacer ([zara-borrar-deshacer](evidence/zara-borrar-deshacer.jpg)). **FARFETCH:** espera local en la fila y retirada sin deshacer ([farfetch-quitar-bolsa](evidence/farfetch-quitar-bolsa.jpg), [farfetch-quitar-deseos](evidence/farfetch-quitar-deseos.jpg)). | Deshacer tiene precedente comercial. Reacomodo de la lista en ≈0,2 s, coherente con la V2. |
| 13 · C | **Espera local:** HBX y Moda Operandi (dentro del botón), FARFETCH (fila oscurecida). **Espera que bloquea:** FARFETCH al agregar (≈3 s) y al filtrar, Zara al borrar. **Indicador de marca:** Moda Operandi (formas del logo) y ASOS (monograma) ([moda-operandi-carga-marca](evidence/moda-operandi-carga-marca.jpg), [asos-carga-marca](evidence/asos-carga-marca.jpg)). | Existen las dos variantes; la V2 elige la local. Un indicador de marca sirve para cargas de pantalla, no dentro de un botón. |
| 14 · C | **Moda Operandi:** mensaje persistente junto a la fila ([moda-operandi-error-stock](evidence/moda-operandi-error-stock.jpg)). **HBX:** franja roja arriba, lejos del control ([hbx-error-stock](evidence/hbx-error-stock.jpg)). | Respalda la versión junto al control (Moda Operandi). |
| 15 · C | **FARFETCH:** «Code Copied» en el mismo botón con un fundido de ≈0,25 s, sin aviso flotante ([farfetch-copiar-codigo](evidence/farfetch-copiar-codigo.jpg)). | Precedente directo del mecanismo. Sigue condicionado a que Monetta tenga algo útil que copiar. |
| 17 · C | **Zalando:** relleno con rebote (≈0,3 s) y además una hoja de confirmación ([zalando-corazon](evidence/zalando-corazon.jpg)). **FARFETCH:** relleno sin rebote; en la ficha aparece ≈0,9 s después del toque ([farfetch-favorito-ficha](evidence/farfetch-favorito-ficha.jpg), [farfetch-favorito-marca](evidence/farfetch-favorito-marca.jpg)). | Hay precedente del rebote que la V2 retiró, pero no de que haga falta. Se mantiene el relleno sin rebote. Si se prueba un rebote, que dure como mucho lo de Zalando y sin respuesta adicional. |
| 18 · X | **Lyst** y **Shop** rotan su lema cada ≈2 s en la bienvenida ([lyst-bienvenida-reposo](evidence/lyst-bienvenida-reposo.jpg), [shop-bienvenida-reposo](evidence/shop-bienvenida-reposo.jpg)). | Aparece en bienvenidas, nunca en el recorrido de compra revisado. Mantener X. |
| 19 · X | **Zara:** deslizar revela «DELETE»; la fila conserva una ✕ visible y hay deshacer ([zara-borrar-deshacer](evidence/zara-borrar-deshacer.jpg)). | Hay precedente comercial. Se mantiene X en la primera versión; si se agrega después, que sea como en Zara: un atajo junto a la ✕ visible y con deshacer. |
| 20 · X | No observado en seis momentos de agregar a la bolsa o a deseos en cinco apps. La descripción sobre FARFETCH era incorrecta. | Refuerza X. |

#03 y #16 ya tenían evidencia comercial (Jo Loves). FARFETCH filtra en una pantalla propia con contador de resultados, lo que no cambia #03.

## El logo: qué muestran las grabaciones

| App | Arranque observado |
|---|---|
| FARFETCH, Moda Operandi | Logotipo estático durante la carga ([farfetch-arranque](evidence/farfetch-arranque.jpg), [moda-operandi-arranque](evidence/moda-operandi-arranque.jpg)). |
| Zara, HBX | Logotipo estático y corte ([zara-arranque](evidence/zara-arranque.jpg), [hbx-arranque](evidence/hbx-arranque.jpg)). |
| Zalando | Logo estático que se difumina en un indicador de carga en ≈0,35 s ([zalando-arranque](evidence/zalando-arranque.jpg)). |
| ASOS | Intro de ≈5,6 s durante la carga: monograma, zoom, disolución en bloques y once logos de submarcas en cortes ([asos-intro](evidence/asos-intro.jpg)). |
| Shop | Fundido a blanco; un trazo dibuja la «o» del logotipo, que estalla en el logotipo con productos. ≈1,2 s, con «Get Started» visible antes de terminar ([shop-intro](evidence/shop-intro.jpg)). |

Conclusiones:

1. **Ninguna app escribe su logotipo letra por letra.** Las dos de lujo lo muestran estático. La animación del logo de Monetta sigue justificada por preferencia de marca, no por la práctica del sector.
2. **Shop es el único precedente comercial de escritura por trazo**, es decir, de la variante B. Solo dibuja un glifo y lo resuelve en ≈1,2 s. La variante A (máscaras por letra) no tiene precedente comercial observado.
3. **Los 1000 ms de la V2 están en el rango de Shop** y muy lejos de los ≈5,6 s de ASOS. Shop muestra el botón principal antes de terminar la intro, que es lo que la V2 exige con «Comenzar».
4. **Todas las apps parten de un logotipo estático** y la animación empieza después. Shop no la encadena directamente: funde a blanco y luego dibuja. *Inferencia para Monetta:* el splash nativo no debería mostrar el logotipo completo si la bienvenida va a escribirlo desde cero. Conviene un splash solo de fondo, o un fundido como el de Shop, para no «borrar» el logo antes de escribirlo.

## Movimiento en reposo

Lyst y Shop mantienen sus bienvenidas en movimiento continuo sin interacción; FARFETCH y Moda Operandi no. El principio de reposo de la V2 coincide con lo que hacen las dos de lujo, pero no es universal.

## Límites

- **Grabaciones de terceros.** Son de ScreensDesign; la página no indica la fecha ni la versión de la app, así que se registra la fecha de consulta. Los videos tienen 592×1280 a 30 fps.
- **Duraciones aproximadas.** Incluyen la latencia de red de la grabación: describen lo observado, no especificaciones de las marcas.
- **Indicador de toque.** El círculo azul de la grabación tapa a veces el control; donde impidió ver el efecto, se dice.
- **Apps sin revisar.** NET-A-PORTER, Mytheresa y SSENSE no están en el catálogo de ScreensDesign. Tampoco se revisaron los videos de vista previa de App Store ni la crítica de ASOS de Pratt. El caso NET-A-PORTER de One Darnley Road sigue sin verificar.
- **Uso del material.** Las hojas son extractos de análisis con atribución; los videos no se conservan ni se redistribuyen. Las imágenes y marcas pertenecen a sus dueños.

## Cómo reproducir una hoja

1. Abrir la página de la app en ScreensDesign (`https://screensdesign.com/apps/<app>/`). El video completo es un enlace firmado y temporal `play_720p.mp4` en el HTML de esa página.
2. Descargarlo y ejecutar, con la ventana y la frecuencia registradas en `sources.json`:

   ```sh
   python3 docs/research/monetta-motion-evidence-2026-10-27/evidence/frames.py \
     --source video.mp4 --page https://screensdesign.com/apps/farfetch-shop-luxury-fashion/ \
     --id farfetch-icono-central --start 230.6 --end 231.9 --fps 15 --width 90 --columns 20
   ```

   `--crop ancho:alto:x:y` recorta antes de escalar; se usó para el corazón de Zalando (`200:300:392:704`).
