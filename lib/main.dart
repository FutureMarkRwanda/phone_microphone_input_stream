// // main.dart
// import 'dart:typed_data';
// import 'package:flutter/material.dart';
// import 'package:flutter_sound/flutter_sound.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'dart:async';
// import 'dart:io';
// import 'package:audio_session/audio_session.dart';
//
// void main() {
//   runApp(const MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   const MyApp({super.key}); // Using super.key
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Audio Streamer',
//       theme: ThemeData(
//         primarySwatch: Colors.blue,
//       ),
//       home: const AudioStreamerPage(),
//     );
//   }
// }
//
// class AudioStreamerPage extends StatefulWidget {
//   const AudioStreamerPage({super.key}); // Using super.key
//
//   @override
//   State<AudioStreamerPage> createState() => _AudioStreamerPageState();
// }
//
// class _AudioStreamerPageState extends State<AudioStreamerPage> {
//   final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
//   bool _isRecording = false;
//   RawDatagramSocket? _socket;
//   StreamSubscription<Uint8List>? _recordingDataSubscription;
//   final String _raspberryPiAddress = '192.168.4.1'; // Replace with your Raspberry Pi's IP
//   final int _port = 12345;
//
//   @override
//   void initState() {
//     super.initState();
//     _initializeRecorder();
//   }
//
//   Future<void> _initializeRecorder() async {
//     // Request microphone permission first.
//     if (await Permission.microphone.request().isGranted) {
//       // Initialize audio session for proper iOS/Android behavior.
//       final session = await AudioSession.instance;
//       await session.configure(AudioSessionConfiguration(
//         avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
//         avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.allowBluetooth,
//         avAudioSessionMode: AVAudioSessionMode.spokenAudio,
//         avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
//         avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
//         androidAudioAttributes: const AndroidAudioAttributes(
//           contentType: AndroidAudioContentType.speech,
//           flags: AndroidAudioFlags.none,
//           usage: AndroidAudioUsage.voiceCommunication,
//         ),
//         androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
//         androidWillPauseWhenDucked: true,
//       ));
//
//       await _recorder.openRecorder();
//       await _recorder.setSubscriptionDuration(const Duration(milliseconds: 100));
//     } else {
//       throw RecordingPermissionException('Microphone permission not granted');
//     }
//   }
//
//   Future<void> _startRecording() async {
//     try {
//       // Bind a UDP socket to send data.
//       _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
//
//       // Create a StreamController that will output Uint8List data.
//       var recordingController = StreamController<Uint8List>();
//
//       // Start the recorder and send the recorded data to the controller's sink.
//       await _recorder.startRecorder(
//         toStream: recordingController.sink,
//         codec: Codec.pcm16,
//         numChannels: 1,
//         sampleRate: 16000,
//       );
//
//       setState(() {
//         _isRecording = true;
//       });
//
//       // Listen to the recorder's stream and send each buffer via UDP.
//       _recordingDataSubscription = recordingController.stream.listen((buffer) {
//         if (_socket != null) {
//           _socket!.send(
//             buffer,
//             InternetAddress(_raspberryPiAddress),
//             _port,
//           );
//         }
//       });
//     } catch (e) {
//       print('Error starting recording: $e');
//     }
//   }
//
//   Future<void> _stopRecording() async {
//     try {
//       await _recordingDataSubscription?.cancel();
//       await _recorder.stopRecorder();
//       _socket?.close();
//
//       setState(() {
//         _isRecording = false;
//       });
//     } catch (e) {
//       print('Error stopping recording: $e');
//     }
//   }
//
//   @override
//   void dispose() {
//     _recorder.closeRecorder();
//     _socket?.close();
//     _recordingDataSubscription?.cancel();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Audio Streamer'),
//       ),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Text(
//               _isRecording ? 'Recording...' : 'Not Recording',
//               style: Theme.of(context).textTheme.headlineSmall,
//             ),
//             const SizedBox(height: 20),
//             ElevatedButton(
//               onPressed: _isRecording ? _stopRecording : _startRecording,
//               child: Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:io';
import 'package:audio_session/audio_session.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice Stream',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF003366),
          primary: const Color(0xFF003366),
          secondary: const Color(0xFF4D88B8),
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Color(0xFF003366),
          contentTextStyle: TextStyle(color: Colors.white),
        ),
      ),
      home: const AudioStreamerPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AudioStreamerPage extends StatefulWidget {
  const AudioStreamerPage({super.key});

  @override
  State<AudioStreamerPage> createState() => _AudioStreamerPageState();
}

class _AudioStreamerPageState extends State<AudioStreamerPage> with SingleTickerProviderStateMixin {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecording = false;
  bool _isInitialized = false;
  bool _isConnected = false;
  String _statusMessage = 'Ready to connect';
  RawDatagramSocket? _socket;
  StreamSubscription<Uint8List>? _recordingDataSubscription;
  final String _raspberryPiAddress = '192.168.4.1'; // Replace with your Raspberry Pi's IP
  final int _port = 12345;

  // For animation
  late AnimationController _animationController;
  Timer? _connectionCheckTimer;
  int _dataPacketsSent = 0;

  @override
  void initState() {
    super.initState();
    _initializeRecorder();

    // Setup animation controller for the recording indicator
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.info_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'OK',

          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  Future<void> _initializeRecorder() async {
    try {
      // Request microphone permission first.
      if (await Permission.microphone.request().isGranted) {
        // Initialize audio session for proper iOS/Android behavior.
        final session = await AudioSession.instance;
        await session.configure(AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.allowBluetooth,
          avAudioSessionMode: AVAudioSessionMode.spokenAudio,
          avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            flags: AndroidAudioFlags.none,
            usage: AndroidAudioUsage.voiceCommunication,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: true,
        ));

        await _recorder.openRecorder();
        await _recorder.setSubscriptionDuration(const Duration(milliseconds: 100));

        setState(() {
          _isInitialized = true;
          _statusMessage = 'Ready to stream';
        });
      } else {
        setState(() {
          _statusMessage = 'Awaiting permissions';
        });
        // Show permission error in snackbar
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showSnackBar('Microphone permission denied. Please grant permission in settings.', isError: true);
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Ready to connect';
      });
      // Show initialization error in snackbar
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSnackBar('Initialization error: $e', isError: true);
      });
    }
  }

  Future<void> _checkConnection() async {
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.send(
        Uint8List.fromList([0, 1, 2, 3]), // Test packet
        InternetAddress(_raspberryPiAddress),
        _port,
      );

      // Wait for a small amount of time to see if the connection works
      await Future.delayed(const Duration(milliseconds: 500));

      socket.close();

      setState(() {
        _isConnected = true;
        _statusMessage = 'Connected to receiver';
      });
    } catch (e) {
      setState(() {
        _isConnected = false;
        _statusMessage = 'Ready to connect';
      });
      // Show connection error in snackbar
      _showSnackBar('Cannot connect to receiver at $_raspberryPiAddress:$_port. Please check your connection.', isError: true);
      throw Exception('Connection failed');
    }
  }

  Future<void> _startRecording() async {
    if (!_isInitialized) {
      _showSnackBar('Recorder not initialized. Please restart the app.', isError: true);
      return;
    }

    try {
      // Check connection first
      await _checkConnection();

      // Bind a UDP socket to send data.
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

      // Create a StreamController that will output Uint8List data.
      var recordingController = StreamController<Uint8List>();

      // Start the recorder and send the recorded data to the controller's sink.
      await _recorder.startRecorder(
        toStream: recordingController.sink,
        codec: Codec.pcm16,
        numChannels: 1,
        sampleRate: 16000,
      );

      setState(() {
        _isRecording = true;
        _statusMessage = 'Streaming audio...';
        _dataPacketsSent = 0;
      });

      // Show success snackbar
      _showSnackBar('Audio streaming started successfully');

      // Start timer to update UI with packet count
      _connectionCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _statusMessage = 'Sent: $_dataPacketsSent packets';
        });
      });

      // Listen to the recorder's stream and send each buffer via UDP.
      _recordingDataSubscription = recordingController.stream.listen((buffer) {
        if (_socket != null) {
          _socket!.send(
            buffer,
            InternetAddress(_raspberryPiAddress),
            _port,
          );
          _dataPacketsSent++;
        }
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Ready to connect';
      });
      // Already showing connection error in snackbar from _checkConnection
      if (e.toString() != 'Exception: Connection failed') {
        _showSnackBar('Error starting recording: $e', isError: true);
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _recordingDataSubscription?.cancel();
      await _recorder.stopRecorder();
      _socket?.close();
      _connectionCheckTimer?.cancel();

      setState(() {
        _isRecording = false;
        _statusMessage = 'Ready to connect';
      });

      // Show success snackbar
      _showSnackBar('Audio streaming stopped');
    } catch (e) {
      setState(() {
        _statusMessage = 'Ready to connect';
      });
      // Show error in snackbar
      _showSnackBar('Error stopping recording: $e', isError: true);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _recorder.closeRecorder();
    _socket?.close();
    _recordingDataSubscription?.cancel();
    _connectionCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Voice Stream',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF003366),
        centerTitle: true,
        elevation: 2,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE8F1F8), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                // Status card
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isConnected ? Icons.wifi : Icons.wifi_off,
                              color: _isConnected ? Colors.green : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Status: $_statusMessage',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        if (_isRecording) ...[
                          const SizedBox(height: 16),
                          // Audio visualization (simplified)
                          SizedBox(
                            height: 60,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(
                                7,
                                    (index) => AnimatedBuilder(
                                  animation: _animationController,
                                  builder: (context, child) {
                                    return Container(
                                      width: 4,
                                      height: 10 + (index % 3 + 1) * 10 *
                                          (0.5 + (_animationController.value *
                                              (index % 2 == 0 ? 1 : 0.7))),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF003366),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // Connection info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.router, color: Color(0xFF003366)),
                          const SizedBox(width: 8),
                          Text(
                            'Receiver: $_raspberryPiAddress',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.settings_ethernet, color: Color(0xFF003366)),
                          const SizedBox(width: 8),
                          Text(
                            'Port: $_port',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Record button
                GestureDetector(
                  onTap: _isRecording ? _stopRecording : _startRecording,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: _isRecording ? Colors.red : const Color(0xFF003366),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          spreadRadius: 2,
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: _isRecording ? 40 : 50,
                        height: _isRecording ? 40 : 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: _isRecording ? BoxShape.rectangle : BoxShape.circle,
                          borderRadius: _isRecording ? BorderRadius.circular(4) : null,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Record status text
                Text(
                  _isRecording ? 'Tap to stop streaming' : 'Tap to start streaming',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}