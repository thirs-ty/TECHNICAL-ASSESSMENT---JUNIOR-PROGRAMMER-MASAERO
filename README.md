# 📋 Booking Management App
**Masaero Junior Programmer Technical Assessment**
-----------------------------------------------------------------------------------
## Overview
A Flutter mobile application simulating a real-world booking management system, 
built for the Aerosparkle platform assessment.
-----------------------------------------------------------------------------------
## Features
| Feature                                          | Status |
| Display booking list (Name, Service, Status)       | ✅ |
| Mark booking as Completed                          | ✅ |
| Auto 10% discount for bookings > RM200             | ✅ |
| Firebase Firestore integration                     | ✅ |
| Error handling & retry                             | ✅ |
| Shimmer loading indicator                          | ✅ |
| Pull-to-refresh                                    | ✅ |
| List & Grid view toggle                            | ✅ |
| Filter tabs (All / Pending / Completed / Discount) | ✅ |
| Smooth animations & clean UI                       | ✅ |
-----------------------------------------------------------------------------------
## Tech Stack
- **Flutter** (Dart)
- **Firebase Firestore**
- **Material 3**
-----------------------------------------------------------------------------------
## Getting Started
```bash
git clone https://github.com/thirs-ty/TECHNICAL-ASSESSMENT---JUNIOR-PROGRAMMER-MASAERO.git
cd TECHNICAL-ASSESSMENT---JUNIOR-PROGRAMMER-MASAERO
flutter pub get
flutter run
```
> Firebase is pre-configured. No additional setup required.
-----------------------------------------------------------------------------------
## Project Structure
lib/
├── main.dart
├── models/
│   └── booking.dart
├── services/
│   └── booking_services.dart
└── screens/
└── booking_list_screen.dart
-----------------------------------------------------------------------------------
## Approach
Built with clean architecture — model, service, and screen layers separated. 
Firebase Firestore used as the real backend API. UI designed to reflect a 
production-ready experience with per-card loading states, animated transitions, 
and full error handling.
-----------------------------------------------------------------------------------
## Candidate
**Muhammad Firdaus** · Junior Programmer · Masaero (Aerosparkle Platform)
