import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class KeyManager {
  final _storage = const FlutterSecureStorage();
  List<String> _geminiKeys = [];
  int _currentIndex = 0;
  String? _githubPat;

  // Singleton pattern for global access
  static final KeyManager _instance = KeyManager._internal();
  factory KeyManager() => _instance;
  KeyManager._internal();

  String? get currentGeminiKey => _geminiKeys.isNotEmpty ? _geminiKeys[_currentIndex] : null;
  String? get githubPat => _githubPat;

  /// Load keys from Secure Storage on startup
  Future<void> init() async {
    final savedKeys = await _storage.read(key: 'gemini_keys');
    if (savedKeys != null && savedKeys.isNotEmpty) {
      _geminiKeys = savedKeys.split(',');
    }
    _githubPat = await _storage.read(key: 'github_pat');
  }

  /// Adds a new key and persists it
  Future<void> addGeminiKey(String key) async {
    if (!_geminiKeys.contains(key)) {
      _geminiKeys.add(key);
      await _storage.write(key: 'gemini_keys', value: _geminiKeys.join(','));
    }
  }

  Future<void> setGithubPat(String pat) async {
    _githubPat = pat;
    await _storage.write(key: 'github_pat', value: pat);
  }

  /// Rotates to the next key in the list
  void rotateKey() {
    if (_geminiKeys.length > 1) {
      _currentIndex = (_currentIndex + 1) % _geminiKeys.length;
    }
  }

  bool get hasKeys => _geminiKeys.isNotEmpty && _githubPat != null;
}