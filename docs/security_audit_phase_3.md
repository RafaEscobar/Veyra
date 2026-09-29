# Auditoría de seguridad — Fase 3.11

Fecha: 2026-09-29

## Alcance y resultado

La revisión cubre el código Dart de producción, la configuración Android, el
almacenamiento local, la administración de temporales, el cifrado, la sesión,
el bloqueo por intentos, los permisos y los flujos de importación y exportación.
No se encontraron secretos hardcodeados ni rutas que publiquen contenido de la
bóveda sin una acción explícita del usuario.

## Hallazgos verificados

- **NIP y claves:** no existen NIP, claves maestras ni claves de API literales
  en `lib/`. El NIP vive temporalmente en los cubits de configuración o
  desbloqueo y nunca forma parte del modelo persistido. La clave maestra se
  genera con aleatoriedad criptográfica, permanece en `VaultSession` solo
  durante una sesión desbloqueada y se destruye al bloquear.
- **Logs:** `AppErrorHandler` escribe únicamente códigos de error no sensibles
  y solo en compilaciones de depuración. No imprime excepciones, stack traces,
  NIP, respuestas, claves, rutas ni nombres de archivos.
- **AndroidManifest:** los backups están desactivados con
  `android:allowBackup="false"` y `android:fullBackupContent="false"`. El
  tráfico HTTP sin cifrar también está desactivado. La única actividad
  exportada es la actividad launcher.
- **Permisos:** producción solicita lectura de imágenes y videos, incluido el
  acceso seleccionado de Android moderno. `READ_EXTERNAL_STORAGE` está limitado
  hasta API 32. No se solicitan cámara, ubicación, escritura global,
  administración total de archivos ni Internet en producción.
  Los permisos transitivos `ACCESS_NETWORK_STATE` y `WAKE_LOCK` de Media3 se
  eliminan porque Veyra reproduce exclusivamente archivos locales.
- **Almacenamiento:** archivos cifrados y temporales usan
  `getApplicationSupportDirectory`; SQLite usa el directorio privado de bases
  de datos. Los nombres físicos se validan con `basename` para impedir traversal.
  Solo una exportación confirmada por el usuario usa MediaStore o el selector
  de documentos para crear una copia pública.
- **Temporales:** se registran, eliminan al cerrar los visores, al bloquear y al
  iniciar la aplicación. El descifrado escribe primero en un archivo temporal y
  no reemplaza el destino si falla la autenticación.
- **Cifrado:** contenido y miniaturas usan AES-256-GCM. Los archivos se cifran
  por bloques autenticados; encabezado e índice forman parte del AAD. Un MAC,
  tamaño o formato inválido cancela el descifrado.
- **Salts y nonces:** el NIP y la recuperación usan salts aleatorios e
  independientes de 16 bytes. Cada valor cifrado usa un nonce aleatorio de 12
  bytes; cada archivo genera un nonce base nuevo y deriva nonces distintos por
  bloque con límites validados.
- **Derivación y lockout:** PBKDF2-HMAC-SHA256 usa 310,000 iteraciones. NIP y
  recuperación mantienen contadores persistentes y bloqueos de 30 segundos,
  2 minutos y 10 minutos cada cinco fallos.
- **Secure Storage:** persiste wrappers autenticados de la clave maestra, salts,
  contadores y fechas de bloqueo. No guarda el NIP, la respuesta de recuperación
  ni la clave maestra en claro.
- **Capturas y recientes:** `FLAG_SECURE` se aplica antes del primer frame y se
  reafirma al volver a primer plano. Android 13 o superior también desactiva las
  capturas de la vista de aplicaciones recientes.
- **EXIF y copias:** las miniaturas se obtienen ya renderizadas y se cifran; no
  se generan copias públicas durante la importación. Una exportación solicitada
  por el usuario restaura el archivo original, incluida su metadata original.

## Controles automatizados

`test/security/security_audit_test.dart` evita regresiones en backups, tráfico
sin cifrar, permisos de producción, protección de pantalla, logs, NIP literales
y uso de almacenamiento privado.

Las reglas modernas y las pruebas de restauración se desarrollan por separado
en el paso 3.12, que permanece pendiente.
