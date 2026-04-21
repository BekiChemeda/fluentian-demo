# Fluentian Mobile (Flutter)

Android-first Flutter client for Fluentian MVP.

## Features
- Riverpod state management
- Dio API client with token interceptor + auto refresh
- Onboarding flow
- Auth flow (register/login)
- Dashboard with XP and streak
- Lesson path + lesson player
- Community match + send message

## Run
1. Install dependencies:
   flutter pub get
2. Run on Android emulator/device:
   flutter run

## API Base URL
Configured in lib/presentation/app/providers.dart as:
http://10.0.2.2:8000

If testing on physical device, switch to your machine LAN IP.
