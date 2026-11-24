# Matriz de validez de Monetta staging

Verificación del 24 de noviembre de 2026 en iPhone 18 Pro con iOS 27.2. Los identificadores corresponden a las etapas 6 a 12 del plan original.

| ID | Resultado | Evidencia |
| --- | --- | --- |
| E6-1 | Sí | El carrito lateral usa el alto disponible y sitúa «Seguir comprando» dentro del contenido desplazable, después de las recomendaciones. |
| E6-2 | Sí | El botón de pago precede a los controles de descuento y a las recomendaciones. |
| E6-3 | Sí | Las pruebas de la bolsa y del carrito Shopify verifican la ausencia del encabezado de resumen, subtotal y total estimado. |
| E6-4 | Sí | El bloque de descuentos conserva el campo, el botón, la respuesta de Shopify y el panel de Rewards cuando corresponde. |
| E6-5 | Sí | Pasaron las suites de carrito, navegación, aceptación y componentes previstas en la etapa. El análisis de los archivos de checkout editados quedó limpio. |
| E7-1 | Sí | `openCheckout` presenta Shopify directamente desde la bolsa y «Comprar ahora». La prueba de regresión comprueba la ausencia de la pantalla intermedia. |
| E7-2 | Sí | Las pruebas cubren la elección de invitado, identidad de compra, protección de doble cobro, verificación del retorno, reintento, confirmación con bolsa vacía y acceso al navegador desde el modal. |
| E7-3 | Sí | El validador aceptó la configuración local de staging. El permiso para presentar una tienda protegida se aplica exclusivamente cuando `APP_ENV=staging`. |
| E7-4 | Sí | Pasaron las pruebas de checkout, navegación, Home y `test/app/`. |
| E8-1 | Sí | El título «Favoritos» aparece en la barra superior. Se retiró el encabezado duplicado del cuerpo. |
| E8-2 | Sí | Se conservaron el texto informativo, el estado vacío, las recomendaciones y la cuadrícula de piezas guardadas. |
| E8-3 | Sí | Pasaron las pruebas de Favoritos y del encabezado compartido. |
| E9-1 | Sí | La superficie consume el espacio que ya reservó antes de transmitir `padding` y `viewPadding` a los hijos. |
| E9-2 | Sí | Una prueba con oclusión superior verifica que el encabezado de colección conserve su altura de 64. |
| E9-3 | Sí | El encabezado de exploración del catálogo utiliza una altura de 64. |
| E9-4 | Sí | Pasaron las pruebas de Catálogo, plataforma y encabezado compartido. |
| E10-1 | Sí | Las pruebas verifican que la barra superior sea la única que muestra «Notificaciones» y que el cuerpo omita «Avisos». |
| E10-2 | Sí | El icono de ajustes está alineado con «Recientes» y abre las preferencias. El aviso redundante se retiró del estado con permiso concedido. |
| E10-3 | Sí | Con un controlador de cuenta, Notificaciones usa `AutoRewardsSection` para resolver el lector del backend de staging. La prueba de pantalla usa un lector de prueba. |
| E10-4 | Sí | Pasaron las suites de Notificaciones, Rewards y Cuenta. |
| E11-1 | Sí | Se retiró del modal la explicación sobre dónde se guardan la foto y el nombre. |
| E11-2 | Sí | El modal indica «JPG, PNG o HEIC. Se ajusta a 384 px.». |
| E11-3 | Sí | Las pruebas de Dart cubren la detección y el envío del formato. La rutina nativa de la app convirtió en el simulador un archivo HEIC real a JPEG de 307 × 384 píxeles y 24,253 bytes. |
| E11-4 | Sí | Pasaron las suites de Cuenta y autenticación. El análisis del selector de fotos editado quedó limpio. |
| E12-1 | Parcial | Formato, configuración de staging y pruebas correctos. El análisis global conserva los 346 diagnósticos de la corrida previa a este cierre. |
| E12-2 | Parcial | Se revisaron los criterios y se corrigió la navegación de retorno identificada durante la auditoría inicial. Esa auditoría no dejó un dictamen final independiente. |
| E12-3 | Sí | Se compiló, instaló y abrió `mx.monetta.monettaApp.staging`. Se verificó la pantalla de inicio y se trajo Device Hub al frente. |

La corrida amplia registró **1,185 pruebas aprobadas y cinco omitidas**. Tras la última corrección de checkout se repitieron las suites directamente afectadas con **142 pruebas aprobadas**. El flujo de compra se verificó con resultados simulados de Shopify. La prueba HEIC en iOS verificó la conversión sin guardar una foto de prueba en la cuenta.

## Retorno tras la contraseña de staging

La reproducción en iOS confirmó que Shopify entrega una URL de checkout válida y redirige al formulario de contraseña. El historial de la hoja mostró que después del acceso se abrió la tienda. La hoja iOS de staging reabre la URL original una vez tras autenticar la tienda, usando la sesión del mismo navegador. Si Shopify vuelve a entregar la tienda, la app conserva la bolsa y muestra un error de apertura. Pasaron las 37 pruebas de puente, coordinación y retorno. La verificación con las credenciales de la tienda sigue pendiente.
