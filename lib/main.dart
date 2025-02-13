// main.dart
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
  const MyApp({super.key}); // Using super.key

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audio Streamer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const AudioStreamerPage(),
    );
  }
}

class AudioStreamerPage extends StatefulWidget {
  const AudioStreamerPage({super.key}); // Using super.key

  @override
  State<AudioStreamerPage> createState() => _AudioStreamerPageState();
}

class _AudioStreamerPageState extends State<AudioStreamerPage> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecording = false;
  RawDatagramSocket? _socket;
  StreamSubscription<Uint8List>? _recordingDataSubscription;
  final String _raspberryPiAddress = '192.168.4.1'; // Replace with your Raspberry Pi's IP
  final int _port = 12345;

  @override
  void initState() {
    super.initState();
    _initializeRecorder();
  }

  Future<void> _initializeRecorder() async {
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
    } else {
      throw RecordingPermissionException('Microphone permission not granted');
    }
  }

  Future<void> _startRecording() async {
    try {
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
      });

      // Listen to the recorder's stream and send each buffer via UDP.
      _recordingDataSubscription = recordingController.stream.listen((buffer) {
        if (_socket != null) {
          _socket!.send(
            buffer,
            InternetAddress(_raspberryPiAddress),
            _port,
          );
        }
      });
    } catch (e) {
      print('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _recordingDataSubscription?.cancel();
      await _recorder.stopRecorder();
      _socket?.close();

      setState(() {
        _isRecording = false;
      });
    } catch (e) {
      print('Error stopping recording: $e');
    }
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    _socket?.close();
    _recordingDataSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Streamer'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _isRecording ? 'Recording...' : 'Not Recording',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isRecording ? _stopRecording : _startRecording,
              child: Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
            ),
          ],
        ),
      ),
    );
  }
}
