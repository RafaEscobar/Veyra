# Veyra

Veyra es una bóveda móvil local para guardar fotos, videos y archivos de forma
privada. El proyecto está construido con Flutter y tiene Android como plataforma
inicial.

## Requisitos

- Flutter 3.44.0 o compatible.
- Dart 3.12.0 o compatible.
- Android SDK con soporte para API 24 o superior.

## Desarrollo

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

El código se organiza por módulos dentro de `lib/features`, con infraestructura
compartida en `lib/core` y configuración de la aplicación en `lib/app`.
