# V Education Flutter App

Flutter application for V Education Quiz/Duel Platform supporting Android, iOS, and Web.

## Setup

1. Install Flutter SDK: https://flutter.dev/docs/get-started/install

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
# Android
flutter run -d android

# iOS
flutter run -d ios

# Web
flutter run -d chrome
```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
├── providers/                # State management (Provider)
├── screens/                  # UI screens
│   ├── auth/                # Authentication screens
│   ├── home/                # Home/Dashboard
│   └── duel/                # Duel/Quiz screens
├── services/                 # API services
└── utils/                    # Utilities & theme
```

## Features

- OTP-based authentication
- Daily duel registration
- Quiz/test taking
- Leaderboard
- Rewards & Referrals
- Multi-language support (English/Telugu)

## API Configuration

Update `lib/services/api_service.dart` with your backend URL:
```dart
static const String baseUrl = 'http://your-backend-url:8000/api/v1';
```

For Android emulator, use: `http://10.0.2.2:8000`
For iOS simulator, use: `http://localhost:8000`
For Web, use: `http://localhost:8000`

