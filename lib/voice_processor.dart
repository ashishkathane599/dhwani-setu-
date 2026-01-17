import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/material.dart';

// Traffic Light Status
enum VoiceStatus { idle, listening, processing, success, error }

class VoiceProcessor extends ChangeNotifier {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  
  VoiceStatus _status = VoiceStatus.idle;
  String _lastWords = "";
  
  VoiceStatus get status => _status;
  String get lastWords => _lastWords;

  VoiceProcessor() {
    _initTts();
  }

  void _initTts() async {
    await _flutterTts.setLanguage("hi-IN");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5); // Slower for rural users
  }

  Future<void> speak(String text) async {
    await _flutterTts.speak(text);
  }

  Future<void> listen({required Function(String) onResult}) async {
    bool available = await _speech.initialize();
    if (available) {
      _status = VoiceStatus.listening;
      notifyListeners();
      
      _speech.listen(
        onResult: (val) {
          _lastWords = val.recognizedWords;
          notifyListeners();
          if (val.finalResult) {
            _status = VoiceStatus.processing;
            notifyListeners();
            onResult(_lastWords);
          }
        },
        localeId: "hi_IN", // Force Hindi Input
        listenFor: const Duration(seconds: 10),
      );
    } else {
      _status = VoiceStatus.error;
      notifyListeners();
      speak("Mic kaam nahi kar raha hai.");
    }
  }

  void setStatus(VoiceStatus status) {
    _status = status;
    notifyListeners();
  }

  // --- NLP LOGIC (Hindi) ---
  
  // Extract Amount: "Ramesh ko 500 bhejo" -> returns 500.0
  double? extractAmount(String command) {
    final RegExp regex = RegExp(r'[0-9]+');
    final match = regex.firstMatch(command);
    if (match != null) {
      return double.tryParse(match.group(0)!);
    }
    return null;
  }

  // Extract Name: Simplistic logic - assumes name is first word or before 'ko'
  String? extractName(String command) {
    // Example: "Ramesh ko bhejo"
    if (command.contains(" ko ")) {
      return command.split(" ko ")[0].trim();
    }
    return null; 
  }
}