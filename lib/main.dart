import 'package:flutter/material.dart';
import 'services/github_service.dart';
import 'services/gemini_service.dart';

void main() => runApp(const VibiMApp());

class VibiMApp extends StatelessWidget {
  const VibiMApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        theme: ThemeData.dark(),
        home: const TerminalInterface(),
      );
}

class TerminalInterface extends StatefulWidget {
  const TerminalInterface({super.key});
  @override
  State<TerminalInterface> createState() => _TerminalInterfaceState();
}

class _TerminalInterfaceState extends State<TerminalInterface> {
  // CONFIGURATION: Put your keys here
  final String githubToken = "YOUR_GITHUB_PAT"; 
  final String geminiKey = "YOUR_GEMINI_API_KEY";

  final TextEditingController _urlController = TextEditingController(text: "owner/repo");
  final TextEditingController _pathController = TextEditingController(text: "lib/main.dart");
  final TextEditingController _promptController = TextEditingController();
  
  final List<String> _logs = ["VibiM System Initialized... Ready for input."];
  bool _isLoading = false;

  void _log(String msg) => setState(() => _logs.add("> $msg"));

  Future<void> _execute() async {
    setState(() { _isLoading = true; });
    
    try {
      final gh = GitHubService(githubToken);
      final gemini = GeminiService(geminiKey);
      
      final repoParts = _urlController.text.split('/');
      final owner = repoParts[0];
      final repo = repoParts[1];
      final path = _pathController.text;

      _log("Fetching $path from $owner/$repo...");
      final originalCode = await gh.fetchFile(owner, repo, path);

      _log("Sending code to Gemini 1.5 Flash for refactoring...");
      final transformedCode = await gemini.processCodeTransformation(originalCode, _promptController.text);

      _log("Code transformation complete. Initiating GitHub Dance...");
      final branchName = "vibim-patch-${DateTime.now().millisecondsSinceEpoch}";
      
      final prUrl = await gh.commitAndOpenPR(
        owner: owner,
        repo: repo,
        branchName: branchName,
        filePath: path,
        newContent: transformedCode,
        prTitle: _promptController.text,
      );

      _log("SUCCESS! Pull Request created: $prUrl");
    } catch (e) {
      _log("ERROR: ${e.toString()}");
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("VibiM Terminal"), backgroundColor: Colors.grey[900]),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _logs.length,
              itemBuilder: (ctx, i) => Text(_logs[i], style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace')),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[900],
            child: Column(
              children: [
                TextField(controller: _urlController, decoration: const InputDecoration(labelText: "Repo (owner/repo)")),
                TextField(controller: _pathController, decoration: const InputDecoration(labelText: "File Path")),
                TextField(controller: _promptController, decoration: const InputDecoration(labelText: "Instructions")),
                const SizedBox(height: 10),
                _isLoading 
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _execute, 
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: const Text("EXECUTE TRANSFORMATION"),
                    ),
              ],
            ),
          )
        ],
      ),
    );
  }
}