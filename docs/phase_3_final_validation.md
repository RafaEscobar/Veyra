# Validación final — Fase 3.13

Fecha: 2026-09-29

## Seguridad

| Caso | Evidencia automatizada | Resultado |
|---|---|---|
| 50 intentos consecutivos de NIP | `secure_authentication_repository_test.dart` avanza cada bloqueo y completa 50 fallos | La sesión nunca abre; persisten 50 fallos y un bloqueo de 10 minutos |
| Reinicio de app durante lockout | Se crea un repositorio nuevo sobre el mismo estado persistido | El bloqueo y su vencimiento permanecen activos |
| Reinicio de dispositivo durante lockout | Se recrean repositorio, servicio criptográfico y sesión sobre el almacenamiento persistido | Un NIP correcto sigue rechazado durante el bloqueo |
| Copia de archivos internos | `security_audit_test.dart` verifica almacenamiento privado, ausencia de `FileProvider` y de rutas externas | No existe una ruta pública para copiar la bóveda |
| Archivo cifrado alterado | Pruebas de `CryptoService` y servicios de imagen, video y documento modifican ciphertext/MAC | La autenticación falla y no queda texto plano |
| Metadata alterada | Se usa un nombre físico con traversal `../` | La ruta es rechazada y el archivo externo no se toca |
| Screenshot | Inspección automatizada de `FLAG_SECURE` antes del primer frame | Capturas bloqueadas globalmente |
| Aplicaciones recientes | Inspección de `setRecentsScreenshotEnabled(false)` | Snapshot de recientes desactivado en Android 13+ |
| Recuperar NIP | Flujo de integración con respuesta de recuperación | Se conserva la misma clave maestra |
| Cambiar NIP | Reemplazo del wrapper de NIP y desbloqueo con el nuevo valor | NIP anterior rechazado y nuevo NIP aceptado |

## Formatos y tamaños

Las pruebas de importación cifran el contenido completo, guardan metadata y
comprueban el resultado. Los archivos grandes se crean como archivos dispersos
y se procesan en bloques de 4 MB para evitar presión artificial de memoria.

| Categoría | Casos aprobados |
|---|---|
| Imágenes | JPEG, PNG, WEBP; 1 MB y 10 MB |
| Videos | MP4, MOV/QuickTime; 20 MB y 100 MB |
| Documentos | PDF, TXT, DOCX, ZIP; 1 MB y 50 MB |

## Interrupciones

| Caso | Resultado |
|---|---|
| Minimizar durante importación | Una interrupción breve permite terminar la transacción sin corrupción |
| Bloquear pantalla | Si la sesión se bloquea durante la importación, la operación falla cerrada y no crea metadata ni ciphertext parcial |
| Recibir llamada | Una interrupción breve conserva la sesión; al superar el timeout se bloquea |
| Cerrar app | `dispose` destruye inmediatamente la clave de sesión |
| Forzar cierre | El siguiente arranque elimina temporales huérfanos de una ejecución interrumpida |
| Poco almacenamiento | ENOSPC se convierte en `StorageFullException` y no crea metadata |
| Permiso denegado | Los selectores muestran una explicación y acceso a configuración sin iniciar importación |

## Comandos de cierre

```text
dart analyze
flutter test
flutter build apk --release
```
