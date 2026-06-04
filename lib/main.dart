// ignore_for_file: unnecessary_null_comparison

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
// import 'package:audioplayers/audioplayers.dart';




import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'attendance_sync.dart';

const String kClassId = 'currentClass'; // change per real classroom

// ==================== [ FAKE STUDENTS ] ====================
final List<Map<String, String>> fakeStudents = List.generate(20, (i) {
  final id = 'S${1001 + i}';
  final names = [
    'Ahmed Khan', 'Maria Garcia', 'John Smith', 'Li Wei', 'Sofia Patel',
    'James Brown', 'Aisha Rahman', 'Carlos Lopez', 'Emma Wilson', 'Raj Singh',
    'Fatima Ali', 'David Kim', 'Isabella Chen', 'Mohammed Yusuf', 'Olivia Taylor',
    'Arjun Mehta', 'Zara Khan', 'Lucas Silva', 'Hana Yamamoto', 'Noah Davis',
  ];
  return {'id': id, 'name': names[i]};
});

// ==================== [ ATTENDANCE RECORD ] ====================
class AttendanceRecord {
  final String studentId;
  final String name;
  final DateTime time;
  final double distance;
  final String method;

  const AttendanceRecord({
    required this.studentId,
    required this.name,
    required this.time,
    required this.distance,
    required this.method,
  });
}

// ==================== [ GLOBAL STATE ] ====================
List<String> attendanceList = [];
List<AttendanceRecord> attendanceRecords = [];
String currentCode = '------';
Position? lecturerLocation;
bool isLecturerActive = false;
String? lecturerBluetoothId;
String? currentLecturerEmail;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform); // ensure google-services.json / plist is present
  runApp(const AttendanceProApp());
}

class AttendanceProApp extends StatelessWidget {
  const AttendanceProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Presence Pro',
      theme: ThemeData(useMaterial3: true),
      home: const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ==================== [ LOGIN SCREEN ] ====================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _error = '';

  final Map<String, String> _lecturerCredentials = {
    'demo@lecturer.com': '123',
    'smith@university.edu': 'pass123',
  };

  void _login(bool isLecturer) {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() => _error = '');

    if (isLecturer) {
      if (_lecturerCredentials.containsKey(email) && _lecturerCredentials[email] == password) {
        if (isLecturerActive) {
          setState(() => _error = 'Another lecturer is already active. Please wait or restart the app.');
        } else {
          isLecturerActive = true;
          currentLecturerEmail = email;
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LecturerScreen()));
        }
      } else {
        setState(() => _error = 'Invalid lecturer credentials');
      }
    } else {
      if (RegExp(r'^[S|s]\d+$|^[0-9]+$').hasMatch(email)) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => StudentScreen(studentId: email)));
      } else {
        setState(() => _error = 'Student ID must be S123 or 12345');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6), Color(0xFF60A5FA)],
          ),
        ),
        child: Center(
          child: GlassCard(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.school_rounded, size: 80, color: Colors.white),
                  const SizedBox(height: 20),
                  const Text('Presence Pro', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 10),
                  const Text('Log in to continue', style: TextStyle(fontSize: 18, color: Colors.white70)),
                  const SizedBox(height: 30),
                  TextField(
                    controller: _emailController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Email or Student ID',
                      hintStyle: TextStyle(color: Colors.white.withAlpha(150)),
                      filled: true,
                      fillColor: Colors.white.withAlpha(26),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Password (lecturer only)',
                      hintStyle: TextStyle(color: Colors.white.withAlpha(150)),
                      filled: true,
                      fillColor: Colors.white.withAlpha(26),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_error.isNotEmpty)
                    Text(_error, style: const TextStyle(color: Colors.redAccent, fontSize: 14), textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _login(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Login as Lecturer', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _login(false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Login as Student', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

// ==================== [ LECTURER SCREEN ] ====================
class LecturerScreen extends StatefulWidget {
  const LecturerScreen({super.key});
  @override
  State<LecturerScreen> createState() => _LecturerScreenState();
}

class _LecturerScreenState extends State<LecturerScreen> {
  String code = '------';
  late DateTime expiry;
  StreamSubscription<List<Map<String, dynamic>>>? _attendanceSubscription;

  @override
  void initState() {
    super.initState();
    // Start GPS immediately
    _getLecturerLocation();

    generateNewCode();
    _startBluetoothBeacon();

    // Listen for attendance records from Firestore
    _attendanceSubscription = AttendanceSync.watchAttendance(kClassId).listen((attendanceData) {
      if (mounted) {
        setState(() {
          attendanceList.clear();
          attendanceRecords.clear();
          for (final record in attendanceData) {
            final studentId = record['studentId'] as String;
            final name = record['name'] as String;
            final timestamp = (record['timestamp'] as Timestamp).toDate();
            final distance = (record['distance'] as num).toDouble();
            final method = record['method'] as String;
            attendanceList.add('$name ($studentId)');
            attendanceRecords.add(AttendanceRecord(
              studentId: studentId,
              name: name,
              time: timestamp,
              distance: distance,
              method: method,
            ),);
          }
        });
      }
    }, onError: (e) {
      debugPrint('Attendance watch error: $e');
    },);
  }

  Future<void> _getLecturerLocation() async {
    try {
      // Request location permission first
      final status = await Permission.location.request();
      if (status.isDenied) {
        if (mounted) setState(() => code = 'GPS DENIED');
        return;
      }

      // Check if GPS is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => code = 'GPS OFF');
        // Show dialog to open GPS settings
        if (mounted) {
          await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('GPS Required'),
              content: const Text('Please enable GPS to start attendance'),
              actions: [
                TextButton(
                  onPressed: () => Geolocator.openLocationSettings(),
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );
        }
        return;
      }

      // Get location with timeout
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('GPS timeout'),
      );

      lecturerLocation = position; // Set global location
      if (mounted) {
        generateNewCode();
      }
    } catch (e) {
      debugPrint('GPS Error: $e');
      if (mounted) setState(() => code = 'GPS ERR');
    }
  }

  Future<void> _startBluetoothBeacon() async {
    try {
      if (!await FlutterBluePlus.isSupported) return;

      // Check Permissions for Android 12+
      if (Platform.isAndroid) {
        await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.bluetoothAdvertise,
          Permission.location,
        ].request();
      }

      lecturerBluetoothId = 'LECTURER_${DateTime.now().millisecondsSinceEpoch % 100000}';

      if (Platform.isAndroid) {
        final advertiseData = AdvertiseData(localName: lecturerBluetoothId);
        final peripheral = FlutterBlePeripheral();
        await peripheral.start(advertiseData: advertiseData);
      }
    } catch (e) {
      debugPrint('Bluetooth advertise error: $e');
      lecturerBluetoothId = null;
    }
  }

  void generateNewCode() {
    if (!mounted) return;
    final now = DateTime.now();
    final seed = (now.hour * 3600 + now.minute * 60 + now.second) ~/ 60;
    final random = (seed * 1103515245 + 12345) % 1000000;
    final newCode = random.toString().padLeft(6, '0');
    final newExpiry = DateTime(now.year, now.month, now.day, now.hour, now.minute).add(const Duration(minutes: 2));

    setState(() {
      code = newCode;
      expiry = newExpiry;
      currentCode = newCode;
    });

    // publish to Firestore so other devices can read it (document id = code)
    AttendanceSync.publishCode(
      classId: kClassId,
      code: newCode,
      expiry: newExpiry,
      latitude: lecturerLocation?.latitude,
      longitude: lecturerLocation?.longitude,
      lecturerEmail: currentLecturerEmail,
    )
      .catchError((e) {
        debugPrint('Failed to publish code: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to publish code')));
        }
      });
  }



  Future<void> _exportToCsv() async {
    if (attendanceRecords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No attendance to export')));
      return;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final now = DateTime.now();
      final fileName = 'attendance_${now.year}-${now.month}-${now.day}_${now.hour}-${now.minute}.csv';
      final file = File('${directory.path}/$fileName');

      final csvData = [
        ['Student ID', 'Name', 'Time', 'Distance', 'Method'],
        ...attendanceRecords.map((r) => [
          r.studentId,
          r.name,
          r.time.toIso8601String(),
          '${r.distance.toStringAsFixed(0)}m',
          r.method,
        ],),
      ];

      final csv = const ListToCsvConverter().convert(csvData);
      await file.writeAsString(csv);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved to: ${file.path}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  @override
  void dispose() {
    _attendanceSubscription?.cancel();
    // ignore: invalid_return_type_for_catch_error
    FlutterBlePeripheral().stop().catchError((e) => debugPrint('Stop advertising error: $e'));
    isLecturerActive = false;
    lecturerBluetoothId = null;
    currentLecturerEmail = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: GlassCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Share Code', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.white)),
                  const SizedBox(height: 30),
                  Wrap(
                    spacing: 8,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: code.split('').map((digit) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 50,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(38),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Center(
                          child: Text(digit, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    onPressed: generateNewCode,
                    icon: const Icon(Icons.refresh),
                    label: const Text('New Code', style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyan,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: _exportToCsv,
                    icon: const Icon(Icons.download, color: Colors.white),
                    label: const Text('Export CSV', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text('Attendees: ${attendanceList.length}', style: const TextStyle(fontSize: 18, color: Colors.white70)),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 200),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white.withAlpha(26), borderRadius: BorderRadius.circular(12)),
                    child: attendanceList.isEmpty
                        ? const Text('No one yet...', style: TextStyle(color: Colors.white54), textAlign: TextAlign.center)
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: attendanceList.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                                    const SizedBox(width: 8),
                                    Text(attendanceList[index], style: const TextStyle(color: Colors.white, fontSize: 16)),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    },
                    icon: const Icon(Icons.logout, color: Colors.white),
                    label: const Text('Logout', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== [ STUDENT SCREEN ] ====================
class StudentScreen extends StatefulWidget {
  final String studentId;  // Add this field
  const StudentScreen({
    super.key,
    required this.studentId,  // Add required parameter
  });

  @override
  State<StudentScreen> createState() => _StudentScreenState();
}

class _StudentScreenState extends State<StudentScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  String _status = '';
  String? _publishedCode;
  StreamSubscription<String?>? _codeSubscription;
  StreamSubscription<List<ScanResult>>? _scanSub;

  @override
  void initState() {
    super.initState();
    // No need to rely on in-memory currentCode only — Firestore is authoritative

    // Listen for published code from Firestore (watchCurrentCode must be defined)
    try {
      _codeSubscription = AttendanceSync.watchCurrentCode(kClassId).listen((code) {
        if (mounted) {
          setState(() {
            _publishedCode = code;
            currentCode = code ?? '------';
          });
        }
      }, onError: (e) {
        debugPrint('watchCurrentCode error: $e');
      },);
    } catch (e) {
      debugPrint('Subscribe error: $e');
    }

    // Start BLE scanning (best-effort)
    _startBluetoothScanning();
  }

  Future<void> _startBluetoothScanning() async {
    try {
      if (!await FlutterBluePlus.isSupported) return;

      if (Platform.isAndroid) {
        await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.location,
        ].request();
      }

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

      _scanSub = FlutterBluePlus.scanResults.listen((results) async {
        for (final r in results) {
          final advName = r.advertisementData.advName;
          if (advName != null && RegExp(r'^\d{6}$').hasMatch(advName)) {
            await _setDetectedCode(advName);
            return;
          }

          for (final bytes in r.advertisementData.serviceData.values) {
            if (bytes != null && bytes.isNotEmpty) {
              final code = String.fromCharCodes(bytes);
              if (RegExp(r'^\d{6}$').hasMatch(code)) {
                await _setDetectedCode(code);
                return;
              }
            }
          }

          for (final bytes in r.advertisementData.manufacturerData.values) {
            if (bytes != null && bytes.isNotEmpty) {
              final code = String.fromCharCodes(bytes);
              if (RegExp(r'^\d{6}$').hasMatch(code)) {
                await _setDetectedCode(code);
                return;
              }
            }
          }
        }
      });
    } catch (e) {
      debugPrint('Bluetooth scan error: $e');
    }
  }

  Future<void> _setDetectedCode(String code) async {
    debugPrint('BLE found code: $code');
    if (!mounted) return;
    setState(() => _publishedCode = code);
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    await _scanSub?.cancel();
    _scanSub = null;
  }

  Future<void> _submitCode() async {
    setState(() {
      _isLoading = true;
      _status = '';
    });

    try {
      final input = _codeController.text.trim();
      if (input.length != 6 || int.tryParse(input) == null) {
        throw Exception('Invalid code format');
      }

      final expected = _publishedCode ?? currentCode;
      if (expected == null || expected == '------') {
        throw Exception('Waiting for lecturer code...');
      }

      final valid = await AttendanceSync.isCodeValid(classId: kClassId, code: input);
      if (!valid) {
        throw Exception('Invalid or expired code');
      }

      if (input != expected) {
        throw Exception('Wrong code');
      }

      // Proximity Check
      setState(() => _status = 'Verifying location...');
      final studentPos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 10));

      final classDoc = await FirebaseFirestore.instance.collection('classes').doc(kClassId).get();
      final classData = classDoc.data();
      double distance = 0.0;

      if (classData != null && classData['latitude'] != null && classData['longitude'] != null) {
        distance = Geolocator.distanceBetween(
          studentPos.latitude,
          studentPos.longitude,
          classData['latitude'] as double,
          classData['longitude'] as double,
        );

        if (distance > 50) { // 50 meters threshold
          throw Exception('Too far from lecturer (${distance.toStringAsFixed(0)}m)');
        }
      } else {
        debugPrint('Lecturer location not available in Firestore');
      }

      // Record attendance to Firebase
      await AttendanceSync.recordAttendance(
        classId: kClassId,
        studentId: widget.studentId,
        name: 'Student ${widget.studentId}',
        distance: distance,
        method: 'Code + GPS',
      );

      setState(() {
        _status = 'Attendance marked successfully!';
        _codeController.clear();
      });
    } catch (e) {
      setState(() => _status = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _codeSubscription?.cancel();
    _scanSub?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student Mode')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_publishedCode != null) ...[
              Text('Detected code: $_publishedCode', style: const TextStyle(color: Colors.green)),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: 'Enter 6-digit code',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              maxLength: 6,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isLoading ? null : _submitCode,
              child: _isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Submit'),
            ),
            const SizedBox(height: 12),
            Text(_status),
          ],
        ),
      ),
    );
  }
}

// ==================== [ GLASS CARD ] ====================
class GlassCard extends StatelessWidget {
  final Widget child;
  const GlassCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(51)),
      ),
      child: child,
    );
  }
}