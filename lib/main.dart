import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'services/github_service.dart';
import 'services/gemini_service.dart';
import 'services/key_manager.dart';

void main() async {
  // Required for secure storage initialization
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load saved keys from encrypted storage
  await KeyManager().init();
  
  runApp(const VibiMApp());
}

class VibiMApp extends StatelessWidget {
  const VibiMApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VibiM AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        primaryColor: Colors.greenAccent,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          labelStyle: TextStyle(color: Colors.greenAccent),
        ),
      ),
      home: const TerminalInterface(),
    );
  }
}

class TerminalInterface extends StatefulWidget {
  const TerminalInterface({super.key});

  @override
  State<TerminalInterface> createState() => _TerminalInterfaceState();
}

class _TerminalInterfaceState extends State<TerminalInterface> {
  final TextEditingController _urlController = TextEditingController(text: "owner/repo");
  final TextEditingController _pathController = TextEditingController(text: "lib/main.dart");
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  final List<String> _logs = ["VibiM OS v1.0.0... Secure Storage Loaded.", "Ready for instruction."];
  bool _isLoading = false;

  void _log(String msg) {
    setState(() {
      _logs.add("${DateTime.now().hour}:${DateTime.now().minute}:${DateTime.now().second} > $msg");
    });
    // Auto-scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  /// The Main AI Logic Loop
  Future<void> _execute() async {
    if (!KeyManager().hasKeys) {
      _log("ERROR: Missing API Keys. Access Settings to configure.");
      _showSettings();
      return;
    }

    setState(() => _isLoading = true);
    final repoParts = _urlController.text.split('/');
    
    if (repoParts.length < 2) {
      _log("ERROR: Invalid Repo Format. Use 'owner/repo'.");
      setState(() => _isLoading = false);
      return;
    }

    try {
      final gh = GitHubService(KeyManager().githubPat!);
      final gemini = GeminiService(KeyManager());

      final owner = repoParts[0].trim();
      final repo = repoParts[1].trim();
      final path = _pathController.text.trim();

      _log("ACCESSING: $owner/$repo via GitHub REST API...");
      final originalCode = await gh.fetchFile(owner, repo, path);
      _log("FETCH SUCCESS. File size: ${originalCode.length} chars.");

      _log("THINKING: Requesting Gemini 1.5 Flash transformation...");
      final transformedCode = await gemini.processCodeTransformation(
        originalCode, 
        _promptController.text
      );

      _log("TRANSFORMATION COMPLETE. Starting GitHub flow...");
      final branchName = "vibim-patch-${DateTime.now().millisecondsSinceEpoch}";
      
      final prUrl = await gh.commitAndOpenPR(
        owner: owner,
        repo: repo,
        branchName: branchName,
        filePath: path,
        newContent: transformedCode,
        prTitle: "VibiM AI: ${_promptController.text}",
      );

      _log("SUCCESS! Pull Request created at:");
      _log(prUrl);
      _promptController.clear();
    } catch (e) {
      _log("FATAL ERROR: ${e.toString()}");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSettings() {
    final _keyInput = TextEditingController();
    final _patInput = TextEditingController(text: KeyManager().githubPat);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20, right: 20, top: 20
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("SECURITY SETTINGS", 
              style: TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
            const SizedBox(height: 15),
            TextField(
              controller: _patInput,
              decoration: const InputDecoration(labelText: "GitHub Personal Access Token"),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _keyInput,
              decoration: const InputDecoration(
                labelText: "Add Gemini API Key",
                helperText: "You can add multiple keys for rotation",
                helperStyle: TextStyle(color: Colors.white54)
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Keys Loaded: ${KeyManager().keyCount}", style: const TextStyle(color: Colors.white70)),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
                  onPressed: () async {
                    if (_patInput.text.isNotEmpty) await KeyManager().setGithubPat(_patInput.text);
                    if (_keyInput.text.isNotEmpty) await KeyManager().addGeminiKey(_keyInput.text);
                    Navigator.pop(context);
                    _log("Security Vault Updated.");
                  },
                  child: const Text("SAVE TO SECURE STORAGE"),
                ),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("VibiM Terminal", style: TextStyle(fontFamily: 'monospace')),
        backgroundColor: Colors.black,
        actions: [
          IconButton(icon: const Icon(Icons.security, color: Colors.greenAccent), onPressed: _showSettings),
        ],
      ),
      body: Column(
        children: [
          // Terminal Log Output
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.black,
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _logs.length,
                itemBuilder: (ctx, i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    _logs[i],
                    style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 13),
                  ),
                ),
              ),
            ),
          ),
          
          // Input Panel
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF151515),
              border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2))),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: TextField(controller: _urlController, decoration: const InputDecoration(labelText: "Repository (owner/repo)"))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: _pathController, decoration: const InputDecoration(labelText: "File Path"))),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _promptController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: "Instructions (e.g., 'Refactor this login function to use async/await')",
                    hintText: "What should the AI do?",
                  ),
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: _isLoading 
                    ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
                    : ElevatedButton(
                        onPressed: _execute, 
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent,
                          foregroundColor: Colors.black,
                          textStyle: const TextStyle(fontWeight: FontWeight.bold)
                        ),
                        child: const Text("EXECUTE TRANSFORMATION"),
                      ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          )
        ],
      ),
    );
  }
}