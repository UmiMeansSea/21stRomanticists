# The 21st Romanticists

A premium literary blogging platform built with Flutter. Designed for poets, authors, and dreamers to share and discover contemporary romantic literature.

## ✨ Features

- **Modern Literary Feed:** A curated reading experience with elegant typography (EB Garamond & Literata).
- **Post Details:** Immersive reading mode with reading progress tracking, estimated reading time, and rich media support.
- **Bookmarks System:** Save your favorite poems and prose to your personal library, synced via Firebase Firestore.
- **Push Notifications:** Stay updated with new content via Firebase Cloud Messaging (FCM).
- **User Authentication:** Secure sign-in with Google and Email via Firebase Auth.
- **Premium UI:** Custom-designed components with a warm, paper-like aesthetic and smooth micro-animations.
- **Settings & Profile:** Manage your account, view app versioning, and navigate easily.

## 🛠 Tech Stack

- **Framework:** Flutter (3.x)
- **Backend:** WordPress API (Content) & Firebase (Auth, Firestore, Messaging)
- **State Management:** Provider
- **Navigation:** GoRouter
- **Styling:** Custom Design System (Vanilla CSS inspired Flutter themes)

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (>=3.2.0)
- Android Studio / VS Code with Flutter extension
- Firebase project configured with `google-services.json`

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/UmiMeansSea/21stRomanticists.git
   ```
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run the app:
   ```bash
   flutter run
   ```

## 📜 Deployment

### Firestore Security Rules
Ensure you deploy the rules provided in `firestore.rules` using the Firebase CLI:
```bash
firebase deploy --only firestore:rules
```

### Build APK
```bash
flutter build apk --release
```

---

*“To be a Romantic is to be a 21st-century rebel.”*
