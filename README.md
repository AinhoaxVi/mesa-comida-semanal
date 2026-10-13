# Casa a Punto

Aplicación web instalable para dos personas: menú, recetas, compra, despensa, congelador y tareas del hogar. El frontal se sirve desde GitHub Pages; Supabase guarda los datos, autentica a cada persona y aplica las reglas de acceso.

## Publicación

La aplicación actual debe conservarse hasta disponer de un proyecto Supabase. Este paquete contiene el reemplazo preparado. Los archivos de esta carpeta se publican en la raíz del repositorio para conservar la dirección existente de GitHub Pages.

1. Crear un proyecto de Supabase y copiar **Project URL** y **publishable / anon key** a `config.js`. La clave publicada es pública por diseño; nunca copiar `service_role` ni claves privadas a este archivo. Añadir la URL de GitHub Pages en **Authentication → URL Configuration → Redirect URLs** y confirmar por correo las cuentas si se mantiene la opción de confirmación.
2. Ejecutar `supabase/schema.sql` en SQL Editor. Solo debe ejecutarse una vez en un proyecto vacío. Las tablas activan Row Level Security antes de que se creen cuentas. La tabla `profiles` solo permite leer y editar el registro propio, incluso con una consulta REST manual.
3. Poner los archivos `index.html`, `style.css`, `app.js`, `catalog.js`, `config.js`, `manifest.webmanifest`, `icon.svg` y `sw.js` en la raíz del repositorio. Mantener `supabase/` en el repositorio para infraestructura. Publicar `main` desde la raíz en GitHub Pages.
4. Ainhoa crea su cuenta, completa preferencias y crea el hogar. Marcos crea su cuenta y le comparte su código de usuario. Ainhoa lo añade desde **Ajustes → Personas del hogar**. Cada uno inicia sesión con su correo y contraseña; no hay selector para entrar en la cuenta ajena. Sus gustos, alergias e intolerancias no se comparten como perfil; la función `allowed_recipes` comprueba ambas cuentas y devuelve únicamente platos admitidos por coincidencias de texto.
5. En **Ajustes → Productos y formatos**, corregir tamaños según la tienda real. Son ejemplos de compra, no un catálogo en tiempo real. Los ingredientes de las recetas están en cantidades para dos raciones; la lista redondea al envase completo y resta lo ya anotado en despensa y las raciones congeladas.

## Avisos push con la aplicación cerrada

La tabla de actividad y la sincronización en tiempo real funcionan al activar la base de datos. Para activar las notificaciones push del dispositivo hacen falta estos pasos adicionales:

1. Generar un par VAPID (por ejemplo, con `npx web-push generate-vapid-keys`). Poner **solo** la clave pública en `config.js` como `vapidPublicKey`.
2. Instalar Supabase CLI, vincular el proyecto y desplegar `supabase/functions/send-push`. Configurar secretos de la función `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY`, `VAPID_CONTACT` (por ejemplo `mailto:correo@dominio.com`) y `WEBHOOK_SECRET` (cadena aleatoria larga). El entorno de Supabase proporciona `SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY` a la función.
3. En **Database Webhooks**, crear un webhook sobre `public.notifications`, evento **INSERT**, URL `https://<project-ref>.supabase.co/functions/v1/send-push`, cabecera `x-webhook-secret` con exactamente `WEBHOOK_SECRET`. La función verifica la cabecera y busca el registro en la base de datos antes de enviarlo.
4. Cada persona abre la app instalada y pulsa **Ajustes → Activar avisos del dispositivo**, concediendo permiso. En iPhone, añadir la web a la pantalla de inicio antes de activar avisos. Al cerrar sesión se elimina la suscripción del dispositivo para proteger la cuenta.

Sin esos pasos, la campana y la actividad compartida funcionan con la app abierta, pero no llegan avisos cuando está cerrada.

## Acceso y límites

- `household_members` controla el acceso a los datos comunes. Solo admin puede crear o cambiar tareas; ambos pueden completar tareas y cambiar menú, compra, despensa y recetas.
- Una finalización genera una notificación para el otro miembro con el emoji y la tarea. Hay un registro por tarea y ciclo; el servidor evita duplicados.
- El filtro de restricciones compara texto de las preferencias con nombres de platos e ingredientes. **No garantiza seguridad alimentaria**: revisad siempre ingredientes y etiquetas ante alergias o intolerancias.
- Los datos ya guardados en `localStorage` por la antigua app no se importan automáticamente. La migración necesitará revisar formatos y asociar datos a las cuentas.
- En el plan gratuito del proveedor pueden aplicarse límites o pausas por inactividad; consultar el plan actual antes de depender de los avisos.

## Comprobación local

`node --check app.js && node validate.cjs`
