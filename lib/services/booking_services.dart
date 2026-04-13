import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/booking.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class BookingService {

  final CollectionReference _ref =
  FirebaseFirestore.instance.collection('bookings');

  Future<List<Booking>> fetchBookings() async {
    await Future.delayed(const Duration(milliseconds: 800));

    try {
      final snapshot = await _ref
          .orderBy('customerName')
          .get(const GetOptions(source: Source.server));

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Booking.fromJson(data);
      }).toList();

    } on FirebaseException catch (e) {
      if (e.code == 'unavailable') {
        throw ApiException('No internet connection. Please try again.');
      }
      throw ApiException('Firebase error: ${e.message}');
    } catch (e) {
      throw ApiException('Failed to load.');
    }
  }

  Future<void> updateBookingStatus(String bookingId, String newStatus) async {
    try {
      await _ref.doc(bookingId).update({'status': newStatus});
    } on FirebaseException catch (e) {
      throw ApiException('Status update failed.: ${e.message}');
    } catch (e) {
      throw ApiException('Status update failed.');
    }
  }

  Future<void> applyDiscount(String bookingId) async {
    try {
      await _ref.doc(bookingId).update({'discountApplied': true});
    } on FirebaseException catch (e) {
      throw ApiException('Failed to apply discount: ${e.message}');
    } catch (e) {
      throw ApiException('Failed to apply discount.');
    }
  }

}