# Plan de desarrollo — Vault App local para fotos, videos y archivos: 
# Nombre de la app: Veyra

## 1. Visión general

Desarrollar una aplicación móvil minimalista y rápida para almacenar de forma privada:

- Imágenes.
- Videos de tamaño moderado.
- Archivos/documentos.

La aplicación será completamente **local**:

- Sin registro.
- Sin inicio de sesión.
- Sin backend.
- Sin servicios externos.
- Sin sincronización en la nube.
- Sin analíticas obligatorias.
- Sin dependencia de Internet.

El acceso principal estará protegido mediante:

- **NIP de 4 dígitos**.
- **Pregunta de seguridad**, utilizada únicamente como mecanismo de recuperación cuando el usuario no recuerde el NIP.

Toda la información sensible deberá almacenarse cifrada dentro del almacenamiento privado de la aplicación.

---

# 2. Objetivo del producto

La experiencia debe ser deliberadamente sencilla:

1. El usuario abre la app por primera vez.
2. Configura un NIP de 4 dígitos.
3. Selecciona una pregunta de seguridad entre 5 opciones.
4. Introduce y confirma su respuesta.
5. Ingresa a la bóveda.
6. Visualiza tres categorías:
   - Imágenes.
   - Videos.
   - Archivos.
7. Puede importar contenido a la bóveda.
8. Puede visualizarlo.
9. Puede:
   - Eliminarlo permanentemente.
   - Sacarlo de la bóveda.
10. Puede alternar entre tema claro y oscuro.

No añadir funcionalidades innecesarias.

La prioridad es:

> Seguridad → simplicidad → velocidad → estética.

---

# 3. Stack recomendado

## Framework

- Flutter.

## Plataformas iniciales

- Android como plataforma principal.
- Mantener arquitectura compatible con iOS para una posible segunda etapa.

## Persistencia local

Usar una combinación de:

- SQLite mediante `drift` o `sqflite` para metadatos.
- `flutter_secure_storage` para secretos pequeños.
- Sistema de archivos privado de la aplicación para contenido cifrado.

## Librerías sugeridas

Evaluar versiones actuales antes de instalarlas.

- `flutter_bloc`
- `equatable`
- `go_router`
- `flutter_secure_storage`
- `path_provider`
- `file_picker`
- `image_picker`
- `photo_manager` si resulta necesario.
- `video_player`
- `cryptography`
- `drift` o `sqflite`
- `permission_handler`
- `mime`
- `uuid`

Evitar dependencias innecesarias.

---

# 4. Arquitectura propuesta

Utilizar arquitectura modular por features.

```text
lib/
├── app/
│   ├── app.dart
│   ├── router/
│   └── theme/
│
├── core/
│   ├── crypto/
│   ├── errors/
│   ├── storage/
│   ├── security/
│   └── utils/
│
├── features/
│   ├── onboarding/
│   ├── authentication/
│   ├── vault/
│   ├── images/
│   ├── videos/
│   ├── files/
│   ├── recovery/
│   └── settings/
│
└── main.dart
```

Separar cada feature en:

```text
feature/
├── data/
├── domain/
└── presentation/
```

No crear capas innecesarias si no aportan valor real.

---

# 5. Principios de seguridad obligatorios

Esta aplicación NO debe limitarse a mover archivos a una carpeta oculta.

Los archivos deben almacenarse cifrados.

## 5.1 Master Encryption Key

Generar una clave aleatoria principal:

```text
Master Encryption Key
```

Esta clave será responsable de cifrar y descifrar los archivos.

Nunca utilizar directamente el NIP para cifrar los archivos.

El NIP solamente deberá utilizarse para proteger una copia cifrada de la Master Encryption Key.

---

## 5.2 Cifrado recomendado

Usar cifrado autenticado moderno:

```text
AES-256-GCM
```

o:

```text
ChaCha20-Poly1305
```

Cada archivo debe utilizar:

- IV/nonce único.
- Authentication tag.
- Metadata mínima necesaria.

Nunca reutilizar nonces.

---

## 5.3 Protección del NIP

Un NIP de cuatro dígitos solo tiene:

```text
0000 - 9999
```

Por lo tanto, no debe almacenarse directamente.

Utilizar un KDF resistente a fuerza bruta.

Preferencia:

```text
Argon2id
```

Si la librería disponible no proporciona una implementación mantenida y segura, utilizar:

```text
PBKDF2-HMAC-SHA256
```

con:

- Salt aleatorio.
- Cantidad elevada de iteraciones.
- Parámetros ajustados para dispositivos móviles.

Nunca guardar:

```text
PIN = 1234
```

ni siquiera usando SHA256 simple.

---

## 5.4 Protección contra fuerza bruta

Implementar intentos limitados.

Ejemplo:

```text
5 intentos incorrectos
→ bloqueo de 30 segundos

otros 5 intentos incorrectos
→ bloqueo de 2 minutos

otros 5 intentos incorrectos
→ bloqueo de 10 minutos
```

Guardar el estado del bloqueo de forma segura.

No reiniciar el contador simplemente cerrando la aplicación.

---

## 5.5 Pregunta de seguridad

La respuesta nunca debe almacenarse en texto plano.

Aplicar:

- Normalización.
- Salt independiente.
- KDF fuerte.

Ejemplo de normalización:

```text
"Mi Perro"
"mi perro"
" MI PERRO "
```

pueden tratarse como una misma respuesta.

Evitar normalizaciones excesivas que reduzcan demasiado la entropía.

La respuesta de seguridad solo debe utilizarse cuando el usuario pulse:

```text
Olvidé mi NIP
```

Nunca mostrar la recuperación automáticamente.

---

## 5.6 Recuperación del NIP

Crear dos envolturas independientes de la Master Encryption Key.

```text
MasterKey
   │
   ├── encryptedWithPinKey
   │
   └── encryptedWithRecoveryKey
```

Donde:

```text
PinKey = KDF(PIN + salt)
RecoveryKey = KDF(securityAnswer + recoverySalt)
```

De esta forma:

- El NIP puede abrir la bóveda normalmente.
- La respuesta de seguridad puede recuperar el acceso.
- Cambiar el NIP no requiere volver a cifrar todos los archivos.

---

## 5.7 Almacenamiento

Los archivos cifrados deben permanecer exclusivamente en:

```text
Application Private Storage
```

No guardar contenido sin cifrar en carpetas públicas.

Ejemplo conceptual:

```text
/app_private/vault/
├── images/
├── videos/
└── files/
```

Los nombres reales de archivos pueden ser UUID.

Ejemplo:

```text
7e8b529c-fac2-40f8-991d-e27c42d51254.dat
```

No conservar nombres originales como nombre físico si no es necesario.

---

## 5.8 Archivos temporales

Evitar generar archivos temporales sin cifrar.

Si son necesarios para visualización:

- Utilizar memoria siempre que sea viable.
- Eliminar inmediatamente cualquier archivo temporal.
- No dejarlos en caché persistente.
- Limpiar temporales al cerrar la vista.

---

## 5.9 Capturas de pantalla

En pantallas sensibles se recomienda bloquear:

- Screenshots.
- Vista previa en aplicaciones recientes.

En Android utilizar:

```text
FLAG_SECURE
```

Aplicarlo especialmente en:

- Pantalla principal de la bóveda.
- Visor de imágenes.
- Reproductor de videos.
- Visor de documentos.

---

# 6. Modelo de datos sugerido

## VaultItem

```text
VaultItem
```

Campos:

```text
id
originalName
encryptedFileName
type
mimeType
size
createdAt
importedAt
thumbnailPath?
```

Tipos:

```text
image
video
file
```

No guardar rutas externas originales si no son necesarias.

---

## SecurityConfig

```text
SecurityConfig
```

Campos conceptuales:

```text
pinSalt
encryptedMasterKeyWithPin
recoverySalt
encryptedMasterKeyWithRecovery
securityQuestionId
failedAttempts
lockUntil
createdAt
```

---

# 7. Preguntas de seguridad

Incluir exactamente cinco preguntas predeterminadas.

Ejemplo:

1. ¿Cuál era el nombre de tu primera mascota?
2. ¿Cuál era el apodo que tenías de pequeño?
3. ¿Cuál fue el nombre de tu primera escuela?
4. ¿Cuál es el segundo nombre de tu madre?
5. ¿Cuál era el nombre de tu mejor amigo de la infancia?

Codificarlas mediante IDs internos.

Ejemplo:

```text
pet_name
childhood_nickname
first_school
mother_middle_name
childhood_friend
```

Nunca guardar únicamente el texto como identificador.

---

# FASE 1 — Base del proyecto, seguridad y onboarding

## Objetivo

Construir la infraestructura completa de seguridad y permitir que el usuario configure y desbloquee la bóveda.

Al finalizar esta fase debe existir una aplicación funcional capaz de:

- Iniciar por primera vez.
- Configurar NIP.
- Configurar pregunta de seguridad.
- Crear la Master Encryption Key.
- Entrar con NIP.
- Recuperar acceso mediante pregunta de seguridad.
- Alternar tema claro/oscuro.

---

## 1.1 Inicialización del proyecto

### TODO

- [x] Crear proyecto Flutter.
- [x] Configurar Android.
- [x] Definir `minSdk` apropiado.
- [x] Configurar estructura modular.
- [x] Instalar dependencias.
- [x] Configurar `go_router`.
- [x] Configurar BLoC.
- [x] Configurar sistema global de errores.
- [x] Crear constantes del proyecto.
- [x] Configurar análisis estático estricto.
- [x] Configurar reglas de lint.
- [x] Eliminar código generado que no sea necesario.

---

## 1.2 Sistema de temas

Crear:

```text
AppTheme
```

con:

```text
lightTheme
darkTheme
```

### Estilo

Debe ser:

- Minimalista.
- Sin degradados innecesarios.
- Esquinas ligeramente redondeadas.
- Espaciado amplio.
- Tipografía limpia.
- Iconos simples.
- Animaciones discretas.

### TODO

- [x] Crear `AppTheme`.
- [x] Crear colores semánticos.
- [x] Crear tipografías.
- [x] Crear tema claro.
- [x] Crear tema oscuro.
- [x] Crear `ThemeCubit`.
- [x] Persistir selección localmente.
- [x] Añadir botón de cambio de tema.
- [x] Verificar contraste y accesibilidad.

---

## 1.3 Onboarding inicial

Pantallas:

```text
WelcomeScreen
CreatePinScreen
ConfirmPinScreen
SecurityQuestionScreen
SecurityAnswerScreen
SetupCompleteScreen
```

### Flujo

```text
Inicio
  ↓
Crear NIP
  ↓
Confirmar NIP
  ↓
Elegir pregunta
  ↓
Escribir respuesta
  ↓
Generar MasterKey
  ↓
Crear envolturas cifradas
  ↓
Bóveda
```

### TODO

- [x] Detectar primera ejecución.
- [x] Crear pantalla de bienvenida.
- [x] Crear teclado numérico propio.
- [x] Limitar NIP exactamente a 4 dígitos.
- [x] Solicitar confirmación.
- [x] Impedir NIP diferentes.
- [x] Crear selector de pregunta.
- [x] Crear campo de respuesta.
- [x] Solicitar confirmación de respuesta.
- [x] Normalizar respuesta.
- [x] Crear configuración segura.
- [x] Generar Master Encryption Key.
- [x] Generar salt del PIN.
- [x] Derivar PinKey.
- [x] Cifrar MasterKey con PinKey.
- [x] Generar recoverySalt.
- [x] Derivar RecoveryKey.
- [x] Cifrar MasterKey con RecoveryKey.
- [x] Guardar configuración.
- [x] Eliminar secretos temporales de memoria cuando sea viable.
- [x] Marcar onboarding como finalizado.

---

## 1.4 Pantalla de desbloqueo

Crear:

```text
UnlockScreen
```

Diseño:

```text
        🔒

      Mi Bóveda

      ○ ○ ○ ○

   [1] [2] [3]
   [4] [5] [6]
   [7] [8] [9]
       [0]

 ¿Olvidaste tu NIP?
```

### TODO

- [x] Crear teclado numérico personalizado.
- [x] Crear indicadores de cuatro dígitos.
- [x] Evitar teclado del sistema.
- [x] Comparar NIP mediante derivación criptográfica.
- [x] Descifrar MasterKey.
- [x] Manejar NIP incorrecto.
- [x] Implementar contador de intentos.
- [x] Implementar lockout progresivo.
- [x] Persistir lockout.
- [x] Mostrar tiempo restante.
- [x] Limpiar NIP de memoria tras intento.
- [x] Añadir navegación a recuperación.

---

## 1.5 Recuperación

Crear:

```text
RecoveryScreen
```

Flujo:

```text
Olvidé mi NIP
      ↓
Mostrar pregunta
      ↓
Respuesta
      ↓
Derivar RecoveryKey
      ↓
Descifrar MasterKey
      ↓
Crear nuevo NIP
      ↓
Reemplazar encryptedMasterKeyWithPin
```

### TODO

- [x] Mostrar únicamente la pregunta seleccionada.
- [x] Crear campo para respuesta.
- [x] Normalizar respuesta.
- [x] Aplicar KDF.
- [x] Intentar descifrar Recovery Master Key.
- [x] Añadir protección contra intentos repetidos.
- [x] Permitir definir nuevo NIP.
- [x] Confirmar nuevo NIP.
- [x] Generar nuevo salt de PIN.
- [x] Crear nueva PinKey.
- [x] Volver a cifrar únicamente la MasterKey.
- [x] No volver a cifrar todos los archivos.
- [x] Mostrar confirmación de recuperación.
- [x] Regresar al UnlockScreen.

---

## 1.6 Secure Storage

Crear:

```text
SecureStorageService
```

Responsabilidades:

- Configuración criptográfica.
- Tema.
- Estado inicial.
- Contadores de seguridad.

### TODO

- [x] Crear abstracción.
- [x] Crear implementación.
- [x] No guardar PIN.
- [x] No guardar respuesta.
- [x] No guardar MasterKey descifrada permanentemente.
- [x] Añadir pruebas.

---

## 1.7 Pruebas de Fase 1

### TODO

- [x] PIN correcto desbloquea.
- [x] PIN incorrecto falla.
- [x] PIN nunca aparece en logs.
- [x] Respuesta correcta permite recuperación.
- [x] Respuesta incorrecta falla.
- [x] Lockout persiste tras reiniciar app.
- [x] Tema persiste.
- [x] MasterKey puede recuperarse con PIN.
- [x] MasterKey puede recuperarse con respuesta.
- [x] Cambiar PIN no cambia la MasterKey.
- [x] App recién instalada entra al onboarding.
- [x] App configurada entra directamente al desbloqueo.

**Estado de la Fase 1: completada.**

---

# FASE 2 — Bóveda, importación, cifrado y visualización

## Objetivo

Implementar el núcleo funcional de la aplicación.

El usuario podrá:

- Importar imágenes.
- Importar videos.
- Importar archivos.
- Consultarlos.
- Eliminarlos.
- Sacarlos nuevamente de la bóveda.

---

# 2.1 Home de la bóveda

Crear:

```text
VaultHomeScreen
```

Interfaz:

```text
Mi bóveda                         ☀ / 🌙

┌─────────────────────────┐
│ 🖼 Imágenes             │
│ 24 elementos            │
└─────────────────────────┘

┌─────────────────────────┐
│ 🎬 Videos               │
│ 8 elementos             │
└─────────────────────────┘

┌─────────────────────────┐
│ 📄 Archivos             │
│ 14 elementos            │
└─────────────────────────┘
```

### TODO

- [x] Crear pantalla principal.
- [x] Crear tarjeta `VaultCategoryCard`.
- [x] Mostrar cantidad de elementos.
- [x] Navegar a cada categoría.
- [x] Añadir cambio de tema.
- [x] Mantener interfaz limpia.
- [x] Evitar dashboards innecesarios.

---

# 2.2 Base de datos

Crear repositorio:

```text
VaultRepository
```

### TODO

- [x] Crear DB local.
- [x] Crear tabla `vault_items`.
- [x] Crear migración inicial.
- [x] Crear modelo `VaultItem`.
- [x] Crear DAO/repository.
- [x] Obtener elementos por tipo.
- [x] Insertar metadata.
- [x] Eliminar metadata.
- [x] Contar elementos.
- [x] Añadir índices necesarios.
- [x] Añadir pruebas CRUD.

---

# 2.3 CryptoService

Crear:

```text
CryptoService
```

Debe ser una pieza aislada y testeable.

Métodos conceptuales:

```text
encryptFile()
decryptFile()
encryptBytes()
decryptBytes()
derivePinKey()
deriveRecoveryKey()
generateMasterKey()
generateSalt()
```

### TODO

- [x] Implementar generación de clave aleatoria.
- [x] Implementar KDF.
- [x] Implementar cifrado autenticado.
- [x] Crear nonce único por archivo.
- [x] Validar autenticidad.
- [x] Manejar archivos corruptos.
- [x] Evitar logging de claves.
- [x] Crear tests con vectores deterministas cuando sea posible.
- [x] Crear pruebas encrypt/decrypt.
- [x] Crear pruebas de archivo manipulado.
- [x] Crear pruebas de clave incorrecta.

---

# 2.4 Importación de imágenes

Flujo:

```text
Galería
  ↓
Seleccionar imagen
  ↓
Leer archivo
  ↓
Cifrar
  ↓
Guardar en app_private
  ↓
Guardar metadata
  ↓
Confirmar importación
```

Después de importar:

Preguntar:

```text
¿Deseas eliminar el archivo original del dispositivo?
```

No eliminar automáticamente.

### TODO

- [x] Abrir selector.
- [x] Permitir selección múltiple.
- [x] Validar MIME.
- [x] Validar existencia.
- [x] Validar tamaño.
- [x] Cifrar archivo.
- [x] Crear UUID.
- [x] Guardar archivo cifrado.
- [x] Guardar metadata.
- [x] Manejar errores parciales.
- [x] Mostrar progreso.
- [x] Preguntar si desea eliminar original.
- [x] Manejar permisos correctamente.

---

# 2.5 Importación de videos

Los videos previstos serán pequeños o moderados.

No cargar videos completos en memoria si puede evitarse.

Usar streaming/chunks cuando la librería criptográfica elegida lo permita.

### TODO

- [x] Crear selector.
- [x] Validar MIME.
- [x] Validar tamaño.
- [x] Mostrar advertencia si es demasiado grande.
- [x] Cifrar sin bloquear UI.
- [x] Mostrar progreso.
- [x] Guardar metadata.
- [x] Manejar errores.
- [x] No generar copias sin cifrar permanentes.

---

# 2.6 Importación de archivos

Tipos permitidos inicialmente:

```text
pdf
txt
doc
docx
xls
xlsx
zip
```

La bóveda puede aceptar otros MIME mediante configuración extensible.

### TODO

- [x] Integrar FilePicker.
- [x] Obtener metadata.
- [x] Cifrar.
- [x] Guardar.
- [x] Indexar.
- [x] Mostrar icono según extensión.
- [x] Manejar tipo desconocido.
- [x] Evitar ejecución directa de archivos.

---

# 2.7 Listado de imágenes

Crear:

```text
ImagesVaultScreen
```

Usar grid.

### TODO

- [x] Crear grid.
- [x] Crear thumbnails seguros.
- [x] Descifrar únicamente lo necesario.
- [x] Implementar lazy loading.
- [x] Mostrar nombre opcionalmente.
- [x] Abrir visor.
- [x] Añadir menú contextual.
- [x] Eliminar.
- [x] Sacar de bóveda.

---

# 2.8 Visor de imágenes

Crear:

```text
ImageViewerScreen
```

### TODO

- [x] Descifrar imagen.
- [x] Mostrar fullscreen.
- [x] Soportar zoom.
- [x] Evitar screenshot.
- [x] Liberar memoria al cerrar.
- [x] Eliminar temporal.
- [x] Añadir botón borrar.
- [x] Añadir botón sacar de bóveda.

---

# 2.9 Listado de videos

Crear:

```text
VideosVaultScreen
```

### TODO

- [x] Mostrar listado/grid.
- [x] Mostrar thumbnail.
- [x] Mostrar duración si está disponible.
- [x] Abrir reproductor.
- [x] Añadir eliminar.
- [x] Añadir sacar de bóveda.

---

# 2.10 Video player

Crear:

```text
VaultVideoPlayerScreen
```

### TODO

- [x] Descifrar video de forma temporal y segura.
- [x] Reproducir.
- [x] Pausar.
- [x] Seek.
- [x] Limpiar archivo temporal.
- [x] Bloquear screenshots.
- [x] Liberar recursos al cerrar.

---

# 2.11 Listado de archivos

Crear:

```text
FilesVaultScreen
```

Mostrar:

```text
icono
nombre
tipo
tamaño
fecha
```

### TODO

- [x] Crear lista.
- [x] Ordenar por fecha.
- [x] Mostrar metadata.
- [x] Añadir vista previa cuando sea viable.
- [x] Añadir eliminar.
- [x] Añadir sacar de bóveda.

---

# 2.12 Sacar de la bóveda

Flujo:

```text
Elemento cifrado
      ↓
Descifrar
      ↓
Elegir ubicación
      ↓
Guardar archivo externo
      ↓
Verificar escritura
      ↓
Preguntar si desea quitarlo de la bóveda
```

### TODO

- [x] Crear export service.
- [x] Permitir seleccionar destino.
- [x] Descifrar.
- [x] Escribir archivo.
- [x] Verificar resultado.
- [x] Mantener original cifrado hasta confirmar.
- [x] Eliminar de bóveda si usuario acepta.
- [x] Limpiar temporales.

---

# 2.13 Eliminación permanente

La app debe dejar claro que eliminar es irreversible.

Modal:

```text
Eliminar permanentemente

Este archivo será eliminado de la bóveda.
Esta acción no se puede deshacer.

Cancelar | Eliminar
```

### TODO

- [x] Crear diálogo.
- [x] Requerir confirmación.
- [x] Eliminar archivo cifrado.
- [x] Eliminar thumbnail.
- [x] Eliminar metadata.
- [x] Manejar fallos parciales.
- [x] Actualizar UI.

---

# 2.14 Pruebas Fase 2

### TODO

- [x] Importar imagen.
- [x] Importar múltiples imágenes.
- [x] Importar video.
- [x] Importar PDF.
- [x] Reiniciar app.
- [x] Confirmar persistencia.
- [x] Abrir imagen.
- [x] Reproducir video.
- [x] Exportar imagen.
- [x] Exportar video.
- [x] Exportar archivo.
- [x] Eliminar elemento.
- [x] Confirmar que no queda metadata huérfana.
- [x] Confirmar que archivo cifrado no puede abrirse externamente.
- [x] Modificar manualmente archivo cifrado y confirmar fallo de autenticidad.
- [x] Probar importación interrumpida.
- [x] Probar almacenamiento lleno.

---

# FASE 3 — Hardening, rendimiento, UX y preparación de release

## Objetivo

Transformar el MVP funcional en una aplicación suficientemente robusta para uso real.

Esta fase no debe introducir funciones innecesarias.

Debe concentrarse en:

- Seguridad.
- Estabilidad.
- Rendimiento.
- Manejo de errores.
- Privacidad.
- Experiencia final.

---

# 3.1 Auto-lock

La bóveda debe bloquearse automáticamente.

Casos:

```text
app en background
app minimizada
pantalla bloqueada
timeout de inactividad
```

Valor sugerido inicial:

```text
30 segundos
```

Puede mantenerse fijo para conservar simplicidad.

### TODO

- [x] Detectar lifecycle.
- [x] Borrar MasterKey de memoria.
- [x] Regresar a UnlockScreen.
- [x] Cerrar visores.
- [x] Eliminar temporales.
- [x] Validar comportamiento tras llamadas/notificaciones.

---

# 3.2 Protección de memoria

La MasterKey puede existir en RAM únicamente mientras la bóveda esté abierta.

### TODO

- [x] Mantener key exclusivamente en sesión.
- [x] Nunca persistir key descifrada.
- [x] Limpiar referencia al bloquear.
- [x] Evitar serialización.
- [x] Evitar logs.
- [x] Evitar exposición en crash reports.

---

# 3.3 Protección contra screenshots

### TODO

- [x] Activar `FLAG_SECURE`.
- [x] Probar screenshots.
- [x] Probar vista de recientes.
- [x] Validar funcionamiento en diferentes versiones Android.

---

# 3.4 Manejo seguro de thumbnails

Los thumbnails también son sensibles.

Opciones:

1. Guardarlos cifrados.
2. Generarlos bajo demanda.

Preferencia:

```text
thumbnails cifrados
```

### TODO

- [x] Cifrar thumbnails.
- [x] Usar UUID.
- [x] Eliminar con elemento.
- [x] No dejar thumbnails en cachés públicas.

---

# 3.5 Limpieza de temporales

Crear:

```text
TemporaryFileManager
```

### TODO

- [x] Registrar temporales creados.
- [x] Borrar al cerrar visor.
- [x] Borrar al bloquear app.
- [x] Borrar al iniciar app.
- [x] Manejar cierre inesperado.
- [x] Probar temporales huérfanos.

---

# 3.6 Rendimiento

### TODO

- [x] Medir tiempo de arranque.
- [x] Medir desbloqueo.
- [x] Medir importación.
- [x] Evitar jank al cifrar.
- [x] Mover operaciones pesadas fuera del main isolate cuando corresponda.
- [x] No cargar galerías completas en RAM.
- [x] Implementar paginación/lazy loading.
- [x] Optimizar thumbnails.
- [x] Liberar controladores de video.
- [x] Liberar imágenes grandes.

---

# 3.7 Manejo de errores

Crear errores tipados:

```text
WrongPinException
WrongRecoveryAnswerException
VaultFileNotFoundException
VaultFileCorruptedException
StorageFullException
PermissionDeniedException
EncryptionException
DecryptionException
ExportException
```

### TODO

- [x] Crear jerarquía de errores.
- [x] Traducir errores técnicos a mensajes amigables.
- [x] Evitar mostrar stack traces.
- [x] No revelar detalles criptográficos.
- [x] Añadir logs únicamente no sensibles.

---

# 3.8 Corrupción de archivos

### TODO

- [x] Detectar authentication tag inválido.
- [x] Mostrar mensaje:

```text
No se pudo abrir este elemento.
El archivo puede estar dañado.
```

- [x] No intentar recuperar contenido inseguro.
- [x] Permitir eliminar registro corrupto.
- [x] No crashear app.

---

# 3.9 UX final

Pantallas definitivas:

```text
Splash
Setup
Unlock
Recovery
VaultHome
ImagesVault
ImageViewer
VideosVault
VideoPlayer
FilesVault
```

No añadir navegación compleja.

### TODO

- [x] Revisar textos.
- [x] Revisar tamaños táctiles.
- [x] Revisar contraste.
- [x] Añadir animaciones pequeñas.
- [x] Añadir loaders discretos.
- [x] Añadir estados vacíos.
- [x] Añadir estados de error.
- [x] Añadir feedback tras importar.
- [x] Añadir feedback tras exportar.
- [x] Añadir feedback tras eliminar.

---

# 3.10 Estados vacíos

Ejemplo:

```text
No tienes imágenes ocultas

Agrega imágenes para guardarlas
de forma segura en tu bóveda.

[ Agregar imágenes ]
```

### TODO

- [x] Imágenes.
- [x] Videos.
- [x] Archivos.

---

# 3.11 Auditoría de seguridad

### TODO

- [x] Buscar PIN en código.
- [x] Buscar claves hardcodeadas.
- [x] Buscar logs sensibles.
- [x] Buscar rutas públicas.
- [x] Revisar AndroidManifest.
- [x] Revisar backups Android.
- [x] Desactivar backup automático de datos sensibles.
- [x] Revisar almacenamiento privado.
- [x] Revisar temporales.
- [x] Revisar cifrado.
- [x] Revisar salts.
- [x] Revisar nonces.
- [x] Revisar lockout.
- [x] Revisar Secure Storage.
- [x] Revisar capturas de pantalla.
- [x] Revisar archivos recientes.
- [x] Revisar metadata EXIF si se generan copias.
- [x] Revisar permisos solicitados.
- [x] Eliminar permisos innecesarios.

---

# 3.12 Android Backup

La aplicación debe evitar que Android realice backups inseguros del contenido de la bóveda.

Revisar:

```text
android:allowBackup
```

y reglas modernas de backup.

### TODO

- [x] Desactivar backups de archivos cifrados o configurar exclusiones.
- [x] Excluir secretos.
- [x] Probar restore.
- [x] Verificar que una restauración parcial no rompa la bóveda de forma insegura.

---

# 3.13 Pruebas finales

### Seguridad

- [x] 50 intentos consecutivos de PIN.
- [x] Reiniciar app durante lockout.
- [x] Reiniciar dispositivo durante lockout.
- [x] Intentar copiar archivos internos.
- [x] Alterar archivo cifrado.
- [x] Alterar metadata.
- [x] Intentar screenshot.
- [x] Abrir recientes.
- [x] Recuperar PIN.
- [x] Cambiar PIN.

### Archivos

- [x] JPEG.
- [x] PNG.
- [x] WEBP.
- [x] MP4.
- [x] MOV si se soporta.
- [x] PDF.
- [x] TXT.
- [x] DOCX.
- [x] ZIP.

### Tamaños

- [x] Imagen 1 MB.
- [x] Imagen 10 MB.
- [x] Video 20 MB.
- [x] Video 100 MB.
- [x] Archivo 1 MB.
- [x] Archivo 50 MB.

### Interrupciones

- [x] Minimizar durante importación.
- [x] Bloquear pantalla.
- [x] Recibir llamada.
- [x] Cerrar app.
- [x] Forzar cierre.
- [x] Poco almacenamiento.
- [x] Permiso denegado.

---

# 8. BLoCs / Cubits sugeridos

Mantener pocos estados globales.

```text
AppBloc
ThemeCubit
AuthBloc
VaultBloc
ImagesBloc
VideosBloc
FilesBloc
ImportBloc
```

No crear un BLoC para cada widget.

---

# 9. Servicios sugeridos

```text
CryptoService
SecureStorageService
VaultStorageService
VaultDatabase
TemporaryFileManager
ImportService
ExportService
PermissionService
```

---

# 10. Repositories sugeridos

```text
SecurityRepository
VaultRepository
SettingsRepository
```

---

# 11. Navegación

Flujo:

```text
                    ┌──────────────┐
                    │ First launch │
                    └──────┬───────┘
                           ↓
                       Setup PIN
                           ↓
                  Security Question
                           ↓
                     Vault Home
                           ↑
                           │
Launch → Unlock ───────────┘
           │
           │ forgot PIN
           ↓
        Recovery
           ↓
      Create new PIN
           ↓
         Unlock
```

---

# 12. Pantalla Home definitiva

Mantenerla extremadamente simple.

```text
┌──────────────────────────────┐
│ Mi bóveda               ☾    │
│                              │
│ ┌──────────────────────────┐ │
│ │ 🖼  Imágenes            │ │
│ │     18 elementos         │ │
│ └──────────────────────────┘ │
│                              │
│ ┌──────────────────────────┐ │
│ │ 🎬  Videos              │ │
│ │     4 elementos          │ │
│ └──────────────────────────┘ │
│                              │
│ ┌──────────────────────────┐ │
│ │ 📄  Archivos            │ │
│ │     9 elementos          │ │
│ └──────────────────────────┘ │
│                              │
└──────────────────────────────┘
```

Nada más.

---

# 13. Fuera del alcance inicial

NO implementar inicialmente:

- Cuentas.
- Login.
- Backend.
- Firebase.
- Sincronización.
- Cloud backup.
- Compartir bóveda.
- Múltiples bóvedas.
- Chat.
- Notificaciones.
- Álbumes.
- Carpetas internas.
- Tags.
- Búsqueda avanzada.
- Reconocimiento facial.
- IA.
- Editor de imágenes.
- Compresión.
- Streaming remoto.
- PIN alternativo.
- Biometría.
- Contraseña alfanumérica.
- Recuperación por correo.

Estas funciones solo deberían evaluarse después de tener un MVP sólido.

---

# 14. Definición de terminado

La versión 1.0 puede considerarse lista cuando:

- [ ] Primera ejecución configura NIP.
- [ ] Pregunta de seguridad funciona.
- [ ] Recuperación funciona.
- [ ] NIP nunca se almacena directamente.
- [ ] Respuesta nunca se almacena directamente.
- [ ] MasterKey nunca se persiste descifrada.
- [ ] Todos los archivos permanecen cifrados.
- [ ] Imágenes funcionan.
- [ ] Videos funcionan.
- [ ] Archivos funcionan.
- [ ] Importar funciona.
- [ ] Visualizar funciona.
- [ ] Exportar funciona.
- [ ] Eliminar funciona.
- [ ] Tema claro funciona.
- [ ] Tema oscuro funciona.
- [ ] Auto-lock funciona.
- [ ] Screenshots están bloqueados.
- [ ] Temporales se limpian.
- [ ] No existen permisos innecesarios.
- [ ] No existe backend.
- [ ] No existe conexión obligatoria a Internet.
- [ ] No existen logs sensibles.
- [ ] Tests críticos pasan.

---

# 15. Orden recomendado de implementación para Codex

Codex debe trabajar en pequeños bloques y no intentar construir toda la aplicación de una sola vez.

Orden:

```text
01 Project bootstrap
02 Theme system
03 App router
04 SecureStorageService
05 CryptoService
06 SecurityRepository
07 Initial setup flow
08 PIN unlock
09 Recovery flow
10 Vault database
11 VaultStorageService
12 Vault home
13 Image import
14 Image gallery
15 Image viewer
16 Video import
17 Video list
18 Video player
19 File import
20 File list
21 Export service
22 Permanent deletion
23 Auto-lock
24 FLAG_SECURE
25 Temporary file manager
26 Error handling
27 Performance pass
28 Security audit
29 Integration tests
30 Release build
```

---

# 16. Instrucciones generales para Codex

Al implementar este proyecto:

1. No inventar APIs.
2. Revisar documentación actual de paquetes antes de utilizarlos.
3. No introducir Firebase.
4. No introducir backend.
5. No introducir autenticación remota.
6. Mantener toda la información en el dispositivo.
7. No guardar archivos sensibles sin cifrado.
8. No guardar PIN en texto plano.
9. No guardar respuesta de seguridad en texto plano.
10. No utilizar hashes rápidos para proteger el PIN.
11. No usar SHA256(PIN) como sistema de seguridad.
12. No reutilizar nonces.
13. No almacenar claves criptográficas dentro del código fuente.
14. No imprimir claves en logs.
15. No imprimir respuestas de seguridad.
16. No imprimir rutas de archivos sensibles.
17. Mantener UI minimalista.
18. No agregar features que no estén descritas.
19. Evitar sobreingeniería.
20. Crear tests para criptografía y autenticación antes de implementar features secundarias.

---

# 17. Regla crítica

En cualquier decisión técnica, utilizar esta prioridad:

```text
SEGURIDAD
   ↓
INTEGRIDAD DE DATOS
   ↓
SIMPLICIDAD
   ↓
RENDIMIENTO
   ↓
ESTÉTICA
```

Nunca reducir la seguridad únicamente para simplificar código.

---

# 18. Nota sobre el NIP de cuatro dígitos

Un PIN de cuatro dígitos por sí mismo no ofrece alta entropía.

Por ello la seguridad del proyecto depende también de:

- KDF lento.
- Salt aleatorio.
- Lockout.
- almacenamiento privado.
- MasterKey aleatoria.
- cifrado autenticado.
- protección de Secure Storage.
- auto-lock.
- bloqueo de screenshots.
- ausencia de archivos temporales persistentes.

La respuesta de seguridad también es potencialmente débil si el usuario escoge una respuesta fácil de adivinar.

Por ello debe recibir la misma protección contra fuerza bruta que el PIN.

La arquitectura debe asumir que:

> El PIN y la respuesta de seguridad son mecanismos de acceso, no claves criptográficas suficientemente fuertes por sí solos.

---

# Resultado esperado

Al finalizar las tres fases debe existir una aplicación móvil extremadamente sencilla:

```text
Abrir app
    ↓
NIP
    ↓
Bóveda
    ↓
Imágenes | Videos | Archivos
```

con únicamente las operaciones necesarias:

```text
Agregar
Ver
Eliminar
Sacar de la bóveda
Cambiar tema
```

y toda la complejidad criptográfica deberá permanecer invisible para el usuario.

---

# Ajustes posteriores al MVP

### TODO

- [x] Generar e integrar un icono propio de Veyra.
- [x] Agregar un registro seguro de errores en memoria para compilaciones debug.
- [x] Agregar una pantalla debug para consultar, copiar y limpiar errores.
- [x] Mostrar el acceso a logs junto al selector de tema solo en debug.
- [x] Generar y validar un nuevo APK debug.
- [x] Registrar fallos parciales de importación y enlazar sus detalles debug.
- [x] Admitir miniaturas inmutables entregadas por Android al importar imágenes y videos.
- [x] Admitir bloques inmutables del backend criptográfico Android al descifrar archivos.
