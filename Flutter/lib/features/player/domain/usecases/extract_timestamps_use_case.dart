import '../player_models.dart';
import '../video_chapters.dart';

/// Chapters from a video description, by the server's rule (issue #137):
/// only lines that start with a timestamp and go on with a title, such as
/// «01:25 Очень увлекательный сезон». Ordinary text and links that merely
/// contain a time are not chapters.
class ExtractTimestampsUseCase {
  List<VideoTimestamp> call(String description) {
    if (description.trim().isEmpty) {
      return const <VideoTimestamp>[];
    }
    return chaptersFromDescription(description);
  }
}
