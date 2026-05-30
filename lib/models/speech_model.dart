import 'package:hive/hive.dart';

part 'speech_model.g.dart';

@HiveType(typeId: 4)
class SpeechModel extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String title;
  @HiveField(2)
  final String speaker;
  @HiveField(3)
  final String youtubeVideoId;
  @HiveField(4)
  final String thumbnailUrl;
  @HiveField(5)
  final String durationLabel;

  SpeechModel({
    required this.id,
    required this.title,
    required this.speaker,
    required this.youtubeVideoId,
    required this.thumbnailUrl,
    required this.durationLabel,
  });
}
