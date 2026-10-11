# Mesa · menú y compra semanal

Aplicación web estática, sin cuenta ni servidor. El perfil, los platos, el menú y la lista se guardan en el almacenamiento local del navegador.

## Abrir en local

Abre `index.html` con un navegador moderno. También puedes arrastrar la carpeta a un editor estático o ejecutar un servidor local desde esta carpeta.

## Publicar en GitHub Pages

1. Crea un repositorio en GitHub y sube `index.html` y este `README.md`.
2. En el repositorio, entra en **Settings → Pages**.
3. En **Build and deployment**, elige **Deploy from a branch**, selecciona `main` y la carpeta `/ (root)`, y guarda.
4. Abre la dirección que GitHub Pages muestre.

No necesita compilación ni configuración de secretos.

## Datos y límites

- Los datos permanecen en el navegador y dispositivo donde se usa la app. No se sincronizan entre dispositivos ni con GitHub.
- **Exportar mis datos** descarga una copia JSON del perfil, menú, despensa y recetas.
- **Borrar datos del dispositivo** elimina los datos guardados por Mesa en ese navegador.
- El catálogo de supermercados es una referencia inicial de disponibilidad habitual; no incluye precios ni stock en tiempo real.
- Los filtros usan los alérgenos conocidos de las recetas. Comprueba siempre etiquetas y trazas, especialmente ante alergias o intolerancias.
