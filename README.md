# Livora Hostel Hub (Flutter)

Mobile app for discovering hostels and managing the tenant experience, connected to the Livora backend API.

## Setup

1. Install [Flutter](https://docs.flutter.dev/get-started/install).
2. Copy environment file:
   ```bash
   cp .env.example .env
   ```
3. Edit `.env` if your API is not on Render:
   ```
   BASE_URL=https://livora-hostel-hub-1.onrender.com
   SOCKET_URL=https://livora-hostel-hub-1.onrender.com
   ```
4. Install dependencies and run:
   ```bash
   flutter pub get
   flutter run
   ```

## API integration

- **Base URL** is read from `.env` via `flutter_dotenv` (`lib/core/config/env_config.dart`).
- **Dio client** with JWT interceptor: `lib/core/network/api_client.dart`
- **Endpoint paths**: `lib/core/network/api_endpoints.dart`
- **Services**: `lib/services/` (auth, buildings, bookings, payments, complaints, tenant portal, notifications)

Protected routes send `Authorization: Bearer <token>` from `flutter_secure_storage`.

If the API is unreachable, the app falls back to local dummy hostel data in `lib/data/dummy_properties.dart`.

## Project structure

```
lib/
  app/app_services.dart       # Service initialization
  core/config/env_config.dart
  core/network/             # ApiClient, endpoints
  core/storage/             # Secure token storage
  data/dummy_properties.dart
  models/
  services/
  widgets/property_image.dart
  main.dart                 # UI screens
```
