import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AttendanceSync {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Publish a lecturer code as a document under `classes/{code}`.
  /// Document id = the six-digit code so students can query by code.
  static Future<void> publishCode({
    required String code,
    required DateTime expiry,
    String? lecturerEmail,
  }) async {
    try {
      final docRef = _db.collection('classes').doc(code);
      await docRef.set({
        'currentCode': code,
        'expiresAt': Timestamp.fromDate(expiry.toUtc()),
        'lecturerEmail': lecturerEmail,
        'publishedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true),);
      debugPrint('Published code $code to Firestore');
    } catch (e) {
      debugPrint('Error publishCode: $e');
      rethrow;
    }
  }

  /// One-off check if a code exists and is still valid (not expired).
  static Future<bool> isCodeValid(String code) async {
    try {
      final doc = await _db.collection('classes').doc(code).get();
      if (!doc.exists) return false;
      final data = doc.data();
      if (data == null) return false;
      final expires = data['expiresAt'] as Timestamp?;
      if (expires != null && expires.toDate().isBefore(DateTime.now().toUtc())) {
        return false; // expired
      }
      return true;
    } catch (e) {
      debugPrint('Error isCodeValid: $e');
      return false;
    }
  }

  /// Record attendance under `classes/{code}/attendance/` subcollection.
  static Future<void> recordAttendance({
    required String code,
    required String studentId,
    required String name,
    required double distance,
    required String method,
  }) async {
    try {
      final collection = _db.collection('classes').doc(code).collection('attendance');
      await collection.add({
        'studentId': studentId,
        'name': name,
        'timestamp': FieldValue.serverTimestamp(),
        'distance': distance,
        'method': method,
      });
      debugPrint('Recorded attendance for $studentId under class $code');
    } catch (e) {
      debugPrint('Error recordAttendance: $e');
      rethrow;
    }
  }
}