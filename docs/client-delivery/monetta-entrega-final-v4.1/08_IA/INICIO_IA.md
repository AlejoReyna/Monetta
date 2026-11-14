# MONETTA · inicio de implementación v4.1

Corrección5 final, 05/11/2026. Entrega para Alexis y su IA. Esta versión incorpora las decisiones vigentes de v4.0 y las122 marcas nuevas. No hace falta leer versiones anteriores para implementar.

## Orden de lectura

1. ../01_documentacion/MONETTA_Documento_Maestro_UI_v4.1.pdf: distribución, componentes, flujos, datos y aceptación.
2. MONETTA_UI_Contrato_IA_v4.1.json:50 fichas y contratos comunes. Leer `correction5` y `new_action_contracts`; sus cambios sustituyen las apariencias opuestas de C4.
3. ../02_sistema/tokens_v4.1.json e inventarios: medidas propuestas, activos por ID, dimensiones y hashes.
4. ../MONETTA_Presentacion_Visual_v4.1.html: galería local de referencia. LosPNG/SVG no son código de componentes; reconstruir controles nativos, texto accesible y comportamiento real.

## Reglas que deben conservarse

- MONETTA dobleT; blanco puro, oro#A58248, verde#3B7030. Cormorant editorial y DM Sans enUI; logotipo/fotografías originales. Glass discreto y superficies estables para producto/formularios.
- Móvil: Inicio/Categorías/Carrito/Cuenta. Invitado puede comprar. Sin Modo Mayoreo, Compartir catálogo o Pausar sobre producto. No existe panel propio de ajustes visuales; accesibilidad base permanece.
- Inicio mantiene su orden:3banners →categorías→marcas→Nueva colección→Lo más buscado→Para ti→Mayoreo único→servicios→registro→pie. Fotos de categoría soloInicio; iconos dorados en otras superficies.
- Producto: tarjeta común→rápida→PDP; destacado→PDP directo. Color/favorito independientes, variantes/fotos/stock/precios coherentes. Agotado es AHORA etiqueta pequeña negra/texto blanco más abajo; retirar estilo gris de C4. El corazón guardado sigue oro dentro de su silueta, sin contenedor.
- Registro exacto: Regístrate en MONETTA REWARDS (negro); ENVÍO GRATIS (oro) para siempre(negro); GANA CASHBACK(verde) con cada compra(negro). Tres líneas independientes, una línea cada una al tamaño base; a320px/200% dejar crecer antes de cortar. Texto oro propuesto20pxbold para contraste sobre blanco. Botón Registrarme con halo oro. Pie gris tenue sin Buscar, con destinos/políticas existentes.
- Envío gratis sigue requiriendo cuenta autenticada reconocida porcheckout. La frase recibida para siempre no elimina ese requisito ni inventa cobertura. Invitado usa tarifa real. Cashback/bonos/apartados conservan reglas e integración pendientes.
- Cuenta: Miembro+nivel y Saldo/monto real; ejemplosPRO/$1,345 no son datos del cliente. Badge de avisos oro/número negro sin cambiar icono; propuesto contar no leídas, cero oculto y99+visual. Datos autorizados, limpieza al salir/cambiar cuenta.
- Publicidad enCuenta: reemplazar el Mayoreo fijo bajo Cerrar sesión por slot editable con proporción banner y material/interacción de Todas las marcas. Sin activos/destinos, ocultar. No inventar una plataforma de anuncios o mensajes.
- Pedido: progreso horizontal camión/Preparando tu pedido →avión/Tu pedido va en camino →casa/Tu pedido fue entregado. Relleno según envío real, independiente del pago. Parcial/cancelado/error requiere texto propio; no inferir avance por tiempo o pago.
- Favoritos: Basado en tus gustos, carrusel deDOS filas con60productos únicos si existen, carga progresiva y fallback editorial sin historial. No duplicar para completar. Este alcance60 es de este módulo; otros carruseles conservan40si existen.
- Contacto/Mayoreo: título y descripción dentro del hero, superpuestos; no ponerlos debajo como bloque separado. Conservar copy y lettering de los recursos fuente. Maqueta móvil adapta distribución del mismo hero para lectura, sin deformar productos.
- Contacto: Enviar Whatsapp al 826 106 6868, una línea/márgenes; después Únete / A nuestros grupos de emprendedores alineado izquierda; tres grupos y redes. Sin envío/unión automáticos. Links de grupos/redes siguen pendientes.
- Mayoreo:3tarjetas lado a lado, misma fila; en móvil desplazar horizontalmente sin apilar ni comprimir letra. Incluye referencia completa de fila en el maestro. Los$800/20días son copy recibido, no regla operativa validada.
- Interpretaciones delimitadas: p11 solo señala arco, se conserva. Cheurones de p13 proponen anterior/siguiente manual; no activan autoplay. Asteriscos de63/64 no borran secciones. LENTES(1) se etiqueta Carteras de Hombre; su nombre original queda en procedencia.

## Implementación

Identificar arquitectura/cuentas/servicios reales; no inferir framework por la IA usada. Resolver bindings por entorno, sin inventarURL/stock/precio/saldo. No modificar producción ni dinero por un diseño. Trabajar en entorno autorizado con cambios revisables.

Cumplir estados de carga/error/vacío/éxito, teclado/foco, modales, reflow320px, texto200%, reducedmotion y fallback opaco.48px es objetivo interno, no mínimoAA. Respuesta autoritativa antes de gota/contador/descuento o confirmación de pago; reconciliar resultados inciertos antes de repetir.

Entregar evidencia por ficha: implementado/probado/pendiente. Esta entrega revisó documentos y archivos; no ejecutó checkout, cuentas o pagos por alcance expreso del usuario. No publicar funciones pendientes con botones inertes o datos ficticios.
