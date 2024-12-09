import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:logger/logger.dart';
import 'package:file_picker/file_picker.dart';
import 'api_service.dart';

class TranscribePage extends StatefulWidget {
  const TranscribePage({super.key, required this.title});

  final String title;

  @override
  State<TranscribePage> createState() => _TranscribePageState();
}

class _TranscribePageState extends State<TranscribePage> {
  final _recorder = FlutterSoundRecorder(logLevel: Level.error);
  final _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isComplete = true;

  bool _isRecording = false;
  String _transcription = '';
  bool isRecorderReady = false;
  bool _isLoading = false;
  final _secretToken = 'ct_202310026@_raffles'; // Your secret token
  String _audioFilePath = '';
  final color_bg = const Color.fromRGBO(147, 96, 242, 1);

  @override
  void initState() {
    super.initState();
    initRecorder();
    setAudio();
    _audioPlayer.onDurationChanged.listen((newDuration) {
      setState(() {
        _duration = newDuration;
      });
    });

    _audioPlayer.onPositionChanged.listen((position) {
      setState(() {
        _position = position;
      });
    });

    // Automatically reset play icon when audio finishes
    _audioPlayer.onPlayerComplete.listen((_) {
      setState(() {
        _isComplete = true;
        _isPlaying = false;
        setAudio();
      });
    });
  }

  Future<void> setAudio() async {
    if (_audioFilePath.isEmpty) return;
    _audioPlayer.setVolume(1);
    _audioPlayer.setSource(DeviceFileSource(_audioFilePath));
  }

  Future initRecorder() async {
    final status = await Permission.microphone.request();

    if (status != PermissionStatus.granted) {
      throw RecordingPermissionException('Microphone permission not granted');
    }
    await _recorder.openRecorder();
    _recorder.setSubscriptionDuration(
      const Duration(milliseconds: 500),
    );
    setState(() {
      isRecorderReady = true;
    });
  }

  Future<void> _startRecording() async {
    if (!isRecorderReady) return;
    _audioFilePath = 'temp_audio.wav'; // Set your path
    await _recorder.startRecorder(toFile: _audioFilePath);
    await _audioPlayer.stop();
    setState(() {
      _duration = Duration.zero;
      _transcription = '';
      _isRecording = true;
      _isComplete = true;
      _isPlaying = false;
    });
  }

  Future<void> _toggleAudioPlayback() async {
    if (_audioFilePath.isEmpty || _isRecording) return;
    if (_isPlaying) {
      await _audioPlayer.pause(); // Pause audio instead of stop
      setState(() {
        _isPlaying = false;
        _isComplete = false;
      });
    } else {
      await _audioPlayer.setVolume(1);
      await _audioPlayer.resume();
      setState(() {
        _isPlaying = true;
        _isComplete = false;
      });
    }
  }

  Future<void> _stopRecording() async {
    if (!isRecorderReady) return;
    final path = await _recorder.stopRecorder();
    _audioFilePath = path!;
    debugPrint('Recording saved to: $_audioFilePath');

    // To set the duration of the audio file
    await _audioPlayer.play(DeviceFileSource(_audioFilePath));
    await _audioPlayer.stop();
    setState(() {
      _isRecording = false;
      setAudio();
    });
    _transcribeAudio();
  }

  Future<void> _transcribeAudio() async {
    try {
      setState(() {
        _isLoading = true; // Show loader
      });
      ApiService apiService = ApiService();
      String transcription =
          await apiService.transcribeAudio(File(_audioFilePath), _secretToken);
      setState(() {
        _transcription = transcription;
        _isLoading = false; // Hide loader
      });
    } catch (e) {
      setState(() {
        _transcription = 'Error: $e';
        _isLoading = false; // Hide loader
      });
    }
  }

  Future<void> _selectAudioFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'aac', 'm4a', 'flac', 'ogg', 'amr'],
    );
    if (result != null) {
      File file = File(result.files.single.path!);
      _audioFilePath = file.path;
      setAudio();
      _transcribeAudio();
    }
  }

  String formatTime(Duration duration) {
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            backgroundColor: Colors.transparent,
            centerTitle: true,
            title: Text(widget.title,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [
                      Color.fromRGBO(62, 52, 133, 1),
                      Color.fromRGBO(65, 54, 139, 1),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 1.0],
                    tileMode: TileMode.clamp),
              ),
            )),
        body: SafeArea(
            child: CustomScrollView(slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
                // Add a container to hold the gradient background
                child: Container(
                    decoration: const BoxDecoration(
                        gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.fromRGBO(65, 54, 139, 1),
                        Color.fromRGBO(88, 73, 194, 1),
                      ],
                    )),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 10),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        // container to hold the buttons
                        children: [
                          // Record Button with Timer
                          const SizedBox(height: 60),
                          Center(
                              child: GestureDetector(
                                  onTap: _isLoading
                                      ? null
                                      : (_isRecording
                                          ? _stopRecording
                                          : _startRecording),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withOpacity(0.2), // Shadow color
                                          spreadRadius: 2, // Spread radius
                                          blurRadius: 4, // Blur radius
                                          offset: const Offset(
                                              4, 4), // Shadow position
                                        ),
                                      ],
                                    ),
                                    child: CircleAvatar(
                                      radius: 70,
                                      backgroundColor: color_bg,
                                      child: Icon(
                                        _isRecording ? Icons.stop : Icons.mic,
                                        size: 70,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ))),
                          const SizedBox(height: 20),
                          // Add Timer
                          StreamBuilder<RecordingDisposition>(
                              stream: _recorder.onProgress,
                              builder: (context, snapshot) {
                                final duration = snapshot.hasData
                                    ? snapshot.data!.duration
                                    : Duration.zero;
                                String twoDigits(int n, int pad_n) =>
                                    n.toString().padLeft(pad_n, '0');
                                final String twoDigitMinutes = twoDigits(
                                    duration.inMinutes.remainder(60), 1);
                                final twoDigitSeconds = twoDigits(
                                    duration.inSeconds.remainder(60), 2);
                                return Text(
                                    _isRecording
                                        ? '$twoDigitMinutes:$twoDigitSeconds'
                                        : '',
                                    style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white));
                              }),
                          const SizedBox(height: 30),
                          // Audio Select Button
                          Container(
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black
                                      .withOpacity(0.2), // Shadow color
                                  spreadRadius: 1,
                                  blurRadius: 3,
                                  offset: const Offset(4,
                                      2), // Shadow position (right and bottom)
                                ),
                              ],
                              borderRadius: BorderRadius.circular(
                                  20), // Match button radius
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                _selectAudioFile();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: color_bg,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Audio',
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(
                                      width:
                                          5), // Spacing between text and icon
                                  Icon(
                                    Icons.music_note_rounded, // Music note icon
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 60),
                          const Spacer(),
                          // Transcription Section
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Transcription',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Audio Playback Controls
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                              decoration: BoxDecoration(
                                color: color_bg,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      _isPlaying
                                          ? Icons.pause
                                          : Icons.play_arrow,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                    onPressed: _toggleAudioPlayback,
                                  ),
                                  Text(
                                    _isPlaying || !_isComplete
                                        ? formatTime(_position)
                                        : formatTime(
                                            _duration), // Replace with actual duration if available
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Expanded(
                                    // Wrap Slider in Expanded to make it longer
                                    child: Slider(
                                      min: 0,
                                      max: _duration.inSeconds.toDouble(),
                                      value: _isPlaying || !_isComplete
                                          ? _position.inSeconds.toDouble()
                                          : const Duration(seconds: 0)
                                              .inSeconds
                                              .toDouble(),
                                      onChanged: (value) async {
                                        final _position =
                                            Duration(seconds: value.toInt());
                                        await _audioPlayer.seek(_position);
                                        await _audioPlayer.resume();
                                        setState(() {
                                          _isPlaying = true;
                                          _isComplete = false;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              )),
                          const SizedBox(height: 20),

                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 30, vertical: 30),
                            width: double.infinity,
                            constraints: const BoxConstraints(
                              minHeight: 150,
                              maxHeight: 150, // Set a maximum height as needed
                            ),
                            decoration: BoxDecoration(
                              color: color_bg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: _isLoading
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      color: Color.fromARGB(126, 255, 255, 255),
                                      strokeWidth: 2.0,
                                    ),
                                  )
                                : SingleChildScrollView(
                                    child: Text(
                                    _transcription.isNotEmpty
                                        ? _transcription
                                        : 'No transcription yet.',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                  )),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ))),
          )
        ])));
  }
}
