# 💊 MediScribe

**Your Personal Medicine Reminder and Prescription Manager**

MediScribe is a Flutter-based mobile app designed to help users manage their medicines, track their prescriptions, and receive timely reminders. It combines a clean interface with powerful features like image-based prescription input, customizable notification schedules, and local database storage.

---

## 🚀 Features

- 📷 **Add Medicines**: Add medicines manually or scan a prescription from images.
- 🕐 **Smart Reminders**:
  - Meal-time based: Reminders for before/after lunch, dinner or any other meals.
  - Interval-based: Hourly reminders (e.g., every 2 hours).
- 📋 **Medicine Tracking**:
  - View Active and Inactive Medicines.
  - Track historical medicine usage.
- 🧪 **Alternate Suggestions**:
  - Find alternate brands with the same generic and strength.
- ⚙️ **Custom Settings**:
  - Set meal times for personalized scheduling.
---

## 🧱 Tech Stack

| Layer       | Stack                       |
|-------------|-----------------------------|
| Frontend    | Flutter, Dart               |
| Backend     | Native Android (Kotlin)     |
| Database    | SQLite (`sqflite` package)  |
| Notifications | AlarmManager + BroadcastReceiver |

---

## 📱 Screens and Pages

- **HomePage**: Quick access buttons to all major actions.
- **Add Manual Medicine**: Form to input medicine name, strength, schedule type.
- **Active/Inactive Medicines**: See your ongoing and past medicines.
- **History**: Log of all added medicines.
- **Settings**: Set lunch/dinner times for accurate scheduling.
- **Alternate Finder**: Search alternate brands based on generic name & strength.

## 📸 Screenshots

<p float="left">
  <img src="https://github.com/fardinik98/Mediscribe/blob/main/screenshots/homepage.jpg?raw=true" width="45%" alt="Home Page"/>
  <img src="https://github.com/fardinik98/Mediscribe/blob/main/screenshots/addmanually.jpg?raw=true" width="45%" alt="Add Medicine"/>
</p>

<p float="left">
  <img src="https://github.com/fardinik98/Mediscribe/blob/main/screenshots/activeMed.jpg?raw=true" width="45%" alt="Active Medicines"/>
  <img src="https://github.com/fardinik98/Mediscribe/blob/main/screenshots/history.jpg?raw=true" width="45%" alt="History"/>
</p>

<p align="center">
  <img src="https://github.com/fardinik98/Mediscribe/blob/main/screenshots/settings.jpg?raw=true" width="45%" alt="Settings"/>
</p>


## 🛠️ Getting Started

### Prerequisites

- Flutter SDK
- Android Studio / VS Code with Flutter plugins
- Android device or emulator

### Installation

```bash
git clone https://github.com/fardinik98/Mediscribe.git
cd mediscribe
flutter pub get
flutter run
```

## 📬 Feedback

If you have any feedback or suggestions, feel free to reach out via **[Fardin Islam Khan](https://github.com/fardinik98)**, or create an issue in this repository.

---

## 👥 Authors
- **Fardin Islam Khan** – [GitHub](https://github.com/fardinik98)

