import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:habit_tracker/models/speech_model.dart';

class SpeechVaultPage extends StatefulWidget {
  const SpeechVaultPage({super.key});

  @override
  State<SpeechVaultPage> createState() => _SpeechVaultPageState();
}

class _SpeechVaultPageState extends State<SpeechVaultPage> {
  late Box<SpeechModel> vaultBox;

  @override
  void initState() {
    super.initState();
    vaultBox = Hive.box<SpeechModel>('speech_vault');
    if (vaultBox.isEmpty) {
      _loadInitialIntelligence();
    }
  }

  void _loadInitialIntelligence() {
    final List<SpeechModel> initialSpeeches = [
      SpeechModel(id: 's1', title: 'The Psychology of Self-Motivation', speaker: 'Scott Geller', youtubeVideoId: '7sxpKhIbr0E', thumbnailUrl: 'https://img.youtube.com/vi/7sxpKhIbr0E/hqdefault.jpg', durationLabel: '15:20'),
      SpeechModel(id: 's2', title: 'Achieve Your Most Ambitious Goals', speaker: 'Stephen Duneier', youtubeVideoId: 'TQMbvJNRpkk', thumbnailUrl: 'https://img.youtube.com/vi/TQMbvJNRpkk/hqdefault.jpg', durationLabel: '18:35'),
      SpeechModel(id: 's3', title: 'The Secret to Self Control', speaker: 'Jonathan Bricker', youtubeVideoId: 'MSy685vNqYk', thumbnailUrl: 'https://img.youtube.com/vi/MSy685vNqYk/hqdefault.jpg', durationLabel: '20:15'),
      SpeechModel(id: 's4', title: 'Why You Should Talk to Strangers', speaker: 'Kio Stark', youtubeVideoId: 'U8-SnoI5l4s', thumbnailUrl: 'https://img.youtube.com/vi/U8-SnoI5l4s/hqdefault.jpg', durationLabel: '12:45'),
    ];
    for (var s in initialSpeeches) vaultBox.add(s);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("K N O W L E D G E   V A U L T", style: TextStyle(letterSpacing: 2, fontSize: 16)),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_link, color: Colors.tealAccent),
            onPressed: () => _showAddVideoDialog(context),
          )
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: vaultBox.listenable(),
        builder: (context, Box<SpeechModel> box, _) {
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, 
              childAspectRatio: 0.8, 
              crossAxisSpacing: 16, 
              mainAxisSpacing: 16,
            ),
            itemCount: box.length,
            itemBuilder: (context, index) => _buildIntelligenceCard(context, box.getAt(index)!),
          );
        },
      ),
    );
  }

  void _showAddVideoDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text("DECRYPT NEW STREAM", style: TextStyle(color: Colors.tealAccent, fontSize: 14)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: "Paste YouTube Link", hintStyle: TextStyle(color: Colors.white24)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          TextButton(
            onPressed: () {
              final videoId = YoutubePlayer.convertUrlToId(controller.text);
              if (videoId != null) {
                vaultBox.add(SpeechModel(
                  id: videoId, title: "Recovered Intelligence", speaker: "External Source",
                  youtubeVideoId: videoId, thumbnailUrl: 'https://img.youtube.com/vi/$videoId/hqdefault.jpg', durationLabel: '??:??',
                ));
                Navigator.pop(context);
              }
            },
            child: const Text("ENCRYPT", style: TextStyle(color: Colors.tealAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildIntelligenceCard(BuildContext context, SpeechModel speech) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SamsungVideoAssistant(speech: speech))),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E).withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Expanded(child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(15)), child: Image.network(speech.thumbnailUrl, fit: BoxFit.cover, width: double.infinity))),
            Padding(padding: const EdgeInsets.all(10), child: Text(speech.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
          ],
        ),
      ),
    );
  }
}

// THE MISSING CLASS THAT RESOLVES THE UNDEFINED METHOD ERROR
class SamsungVideoAssistant extends StatefulWidget {
  final SpeechModel speech;
  const SamsungVideoAssistant({super.key, required this.speech});

  @override
  State<SamsungVideoAssistant> createState() => _SamsungVideoAssistantState();
}

class _SamsungVideoAssistantState extends State<SamsungVideoAssistant> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.speech.youtubeVideoId,
      flags: const YoutubePlayerFlags(autoPlay: true, hideControls: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(child: YoutubePlayer(controller: _controller)),
          
          // Samsung Style Glass Overlay
          Positioned(
            bottom: 40, left: 20, right: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.replay_10, color: Colors.white), 
                        onPressed: () => _controller.seekTo(_controller.value.position - const Duration(seconds: 10)),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _controller.value.isPlaying ? _controller.pause() : _controller.play();
                          });
                        },
                        child: Icon(
                          _controller.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, 
                          color: Colors.tealAccent, size: 54,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.forward_10, color: Colors.white), 
                        onPressed: () => _controller.seekTo(_controller.value.position + const Duration(seconds: 10)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          Positioned(
            top: 50, left: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30), 
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}