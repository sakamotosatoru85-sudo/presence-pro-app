import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AttendanceSync {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Publish a lecturer code as a document under `classes/{classId}`.
  /// classId here should be the class identifier (e.g. course id / room id).
  static Future<void> publishCode({
    required String classId,
    required String code,
    required DateTime expiry,
    double? latitude,
    double? longitude,
    String? lecturerEmail,
  }) async {
    try {
      final docRef = _db.collection('classes').doc(classId);
      await docRef.set({
        'currentCode': code,
        'expiresAt': Timestamp.fromDate(expiry.toUtc()),
        'latitude': latitude,
        'longitude': longitude,
        'lecturerEmail': lecturerEmail,
        'publishedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true),);
      debugPrint('Published code $code for class $classId');
    } catch (e) {
      debugPrint('Error publishCode: $e');
      rethrow;
    }
  }

  /// One-shot validation: returns true if code exists and is not expired.
  static Future<bool> isCodeValid({
    required String classId,
    required String code,
  }) async {
    try {
      final doc = await _db.collection('classes').doc(classId).get();
      if (!doc.exists) return false;
      final data = doc.data();
      if (data == null) return false;
      final storedCode = data['currentCode'] as String?;
      if (storedCode == null || storedCode != code) return false;
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

  /// Record attendance under `classes/{classId}/attendance/`
  static Future<void> recordAttendance({
    required String classId,
    required String studentId,
    required String name,
    required double distance,
    required String method,
  }) async {
    try {
      final collection = _db.collection('classes').doc(classId).collection('attendance');
      await collection.add({
        'studentId': studentId,
        'name': name,
        'timestamp': FieldValue.serverTimestamp(),
        'distance': distance,
        'method': method,
      });
      debugPrint('Recorded attendance for $studentId in $classId');
    } catch (e) {
      debugPrint('Error recordAttendance: $e');
      rethrow;
    }
  }

  /// Stream helper: observe the currentCode for the class (optional)
  static Stream<String?> watchCurrentCode(String classId) {
    return _db.collection('classes').doc(classId).snapshots().map((snap) {
      if (!snap.exists) return null;
      final data = snap.data();
      if (data == null) return null;
      final expires = data['expiresAt'] as Timestamp?;
      if (expires != null && expires.toDate().isBefore(DateTime.now().toUtc())) return null;
      return data['currentCode'] as String?;
    });
  }

  /// Stream helper: observe attendance records for the class
  static Stream<List<Map<String, dynamic>>> watchAttendance(String classId) {
    return _db.collection('classes').doc(classId).collection('attendance').snapshots().map((querySnap) {
      return querySnap.docs.map((doc) => doc.data()).toList();
    });
  }
}