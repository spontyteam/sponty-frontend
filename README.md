# 📍 Sponty Frontend

The Flutter-based frontend for **Sponty** — a smart location discovery app that helps users find places nearby through random suggestions, intelligent recommendations, and collaborative decision-making.

---

## ✨ What is Sponty?

Sponty helps users discover places to eat, drink, or explore — whether they’re alone or with a group.

### 🔑 Key Features

- 🎯 **Smart Nearby Recommendations**  
  Accurately recommends nearby places based on user preferences, activity type, cuisine, and more.

- 🎲 **Random Exploration**  
  Don’t know what to do? Let Sponty pick a random place for you within your selected radius and interest.

- 👥 **Group Matching with Swipe UI**  
  Users can create groups (e.g., for birthdays, outings) and collaboratively choose preferences like:
  - Meal type (e.g., lunch, dinner)
  - Activity (e.g., bar, club, escape room)
  - Cuisine or vibe

  Each group member swipes left or right on suggestions in a Tinder-style interface. Sponty then finds the best match — either a common like or the best fit based on group overlap.

- 🧍 **Solo Matching Mode**  
  The same swiping experience is available for individuals who want curated or random options.

- 🗺 **Interactive Map & List View**  
  Browse and search for locations on an interactive map or a detailed list — just like you'd expect in modern location apps.

---

## 🔧 Tech Stack

- **Flutter** 3.32.4
- **Dart** SDK ^3.8.1
- GitHub Actions (CI/CD)
- Firebase (planned for backend and hosting)

---

## 📦 Getting Started

```bash
git clone https://github.com/etazza/sponty-frontend.git
cd sponty-frontend
flutter pub get
flutter run
