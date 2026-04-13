import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/booking_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }
  runApp(const BookingApp());
}

class BookingApp extends StatelessWidget {
  const BookingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aerosparkle Booking',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A73E8)),
        useMaterial3: true,
      ),
      home: const BookingListScreen(),
    );
  }
}