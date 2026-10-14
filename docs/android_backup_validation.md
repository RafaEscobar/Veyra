# Validación de Android Backup — Fase 3.12

Fecha: 2026-09-29

## Política

Veyra no permite respaldar ni transferir datos internos de la bóveda. El
manifiesto fija `android:allowBackup="false"` y referencia dos conjuntos de
reglas como defensa adicional ante diferencias entre versiones y fabricantes:

- `res/xml/backup_rules.xml` para Android 11 y versiones anteriores.
- `res/xml/data_extraction_rules.xml` para Android 12 y versiones posteriores.

Ambos excluyen los dominios `root`, `file`, `database`, `sharedpref`,
`external` y sus cuatro equivalentes de almacenamiento protegido del dispositivo.
Las reglas modernas aplican las exclusiones tanto a `cloud-backup` como a
`device-transfer`.

Esto excluye los archivos cifrados, temporales, metadata SQLite, preferencias y
el registro de Flutter Secure Storage. Android Keystore tampoco forma parte de
estos dominios exportables.

## Pruebas de restauración

`test/security/android_backup_rules_test.dart` construye un conjunto de datos
representativo para cada dominio, aplica las reglas heredadas, de nube y de
transferencia, y restaura el snapshot resultante. Los tres snapshots quedan
vacíos.

La restauración parcial se valida además en las capas de aplicación:

- Sin configuración de seguridad, la app permanece en configuración inicial y
  no consulta ni abre contenido restaurado.
- Metadata sin el archivo cifrado produce un error controlado de archivo no
  encontrado; nunca crea texto plano.
- Un archivo cifrado sin metadata no aparece en ninguna consulta de la bóveda.
- Un archivo cifrado sin la clave maestra sigue autenticado e indescifrable.
- Los temporales se limpian en el arranque y al bloquear la bóveda.

La compilación Android valida la sintaxis de ambos XML y el manifiesto fusionado
de release conserva `allowBackup=false` junto con las dos referencias.
