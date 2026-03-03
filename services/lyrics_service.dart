import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:habit_tracker/models/song_model.dart'; // Import this, NOT lyrics_model.dart

class LyricsService {
  static Future<List<LyricLine>?> fetchLyrics(String trackName, String artistName) async {
    try {
      final url = Uri.parse('https://lrclib.net/api/get?artist_name=$artistName&track_name=$trackName');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String? lrcContent = data['syncedLyrics'] ?? data['plainLyrics'];
        
        if (lrcContent != null) {
          return _parseLrc(lrcContent);
        }
      }
    } catch (e) {
      print("Lyrics Service Error: $e");
    }
    return null;
  }

  static List<LyricLine> _parseLrc(String lrc) {
    final List<LyricLine> lines = [];
    final RegExp regExp = RegExp(r'\[(\d+):(\d+\.\d+)\](.*)');

    for (var line in lrc.split('\n')) {
      final match = regExp.firstMatch(line);
      if (match != null) {
        final min = int.parse(match.group(1)!);
        final sec = double.parse(match.group(2)!);
        final text = match.group(3)!.trim();
        
        lines.add(LyricLine(
          startTime: Duration(milliseconds: (min * 60000 + sec * 1000).toInt()),
          text: text,
        ));
      }
    }
    return lines;
  }
}