# WebRTC Healthcare Video Call App

A peer-to-peer video calling application built with Flutter and Node.js for healthcare consultations.

## 🔐 Security Notice

This repository does **NOT** include sensitive credential files. You need to set up your own:

### Required Files (Not in Repository):

1. **`lib/firebase_options.dart`** - Firebase configuration
2. **`android/app/google-services.json`** - Google Services for Android
3. **`lib/config/app_config.dart`** - Server URLs and configuration

### Setup Instructions:

1. Create Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Download your `google-services.json` and place in `android/app/`
3. Create `lib/firebase_options.dart` with your Firebase credentials
4. Create `lib/config/app_config.dart` with your server URL

## 🚀 Quick Start

```bash
# Install dependencies
flutter pub get

# Run the app
flutter run

# Start the signaling server
cd server
npm install
node server.js
```

## 📱 Features

- Peer-to-peer video calling using WebRTC
- Real-time signaling with Socket.IO
- Firebase for meeting management
- Audio/Video toggle controls
- Camera switching

## 🏗️ Architecture

- **Flutter** - Mobile app (Android/iOS)
- **WebRTC** - Peer-to-peer video/audio streaming
- **Socket.IO** - Signaling server for connection setup
- **Node.js** - Backend signaling server
- **Firebase** - Meeting metadata storage

## ⚠️ Important

Never commit credential files to the repository. They are protected by `.gitignore`.
