# Fuentes de las comprobaciones de cuenta

Se conservan las fuentes exactas de las verificaciones ejecutadas durante esta
sesión, como evidencia. Usan exclusivamente clientes, direcciones, pedidos e
imágenes de prueba; no contienen sesiones reales de Shopify.

Los archivos `.mjs.txt` son referencias del entorno de ejecución original, con
rutas locales. No forman parte del código del tema ni del despliegue. Para
repetirlas en otra máquina hay que adaptar la raíz del proyecto y la carpeta
del tema, instalar `liquidjs` en la carpeta de dependencias temporal indicada
y disponer de `playwright-core`, `axe-core` y Firefox. Los resultados guardados
están en `../active-theme-verification/` y en la carpeta principal de la entrega.
