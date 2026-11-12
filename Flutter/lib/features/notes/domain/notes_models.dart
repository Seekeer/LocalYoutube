/// Video notes: Topics, Review, Extended Description, Answers and local Drafts.
/// Terms follow CONTEXT.md, section "Video classification and notes".
library;

Map<String, dynamic> notesJsonMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((dynamic key, dynamic item) => MapEntry('$key', item));
  }
  return <String, dynamic>{};
}

List<Map<String, dynamic>> notesJsonList(Object? value) {
  if (value is! List) {
    return const <Map<String, dynamic>>[];
  }
  return value
      .whereType<Map<dynamic, dynamic>>()
      .map(notesJsonMap)
      .toList(growable: false);
}

String _string(Object? value) => value == null ? '' : value.toString();

String? _nullableString(Object? value) {
  final String text = _string(value);
  return text.isEmpty ? null : text;
}

int _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(_string(value)) ?? 0;
}

bool _bool(Object? value) => value == true || _string(value) == 'true';

DateTime? _date(Object? value) => DateTime.tryParse(_string(value));

class NoteTopic {
  const NoteTopic({required this.id, required this.name, this.definition = ''});

  final int id;
  final String name;
  final String definition;

  factory NoteTopic.fromJson(Map<String, dynamic> json) => NoteTopic(
        id: _int(json['id']),
        name: _string(json['name']),
        definition: _string(json['definition']),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'definition': definition,
      };
}

class SuggestedTopic {
  const SuggestedTopic({required this.name, required this.isNew});

  final String name;
  final bool isNew;

  factory SuggestedTopic.fromJson(Map<String, dynamic> json) => SuggestedTopic(
        name: _string(json['name']),
        isNew: _bool(json['isNew']),
      );
}

class NoteAnswer {
  const NoteAnswer({
    required this.id,
    required this.query,
    required this.answer,
    required this.status,
    required this.error,
    this.createdDate,
    this.completedDate,
  });

  final int id;
  final String query;
  final String answer;
  final String status;
  final String error;
  final DateTime? createdDate;
  final DateTime? completedDate;

  factory NoteAnswer.fromJson(Map<String, dynamic> json) => NoteAnswer(
        id: _int(json['id']),
        query: _string(json['query']),
        answer: _string(json['answer']),
        status: _string(json['status']),
        error: _string(json['error']),
        createdDate: _date(json['createdDate']),
        completedDate: _date(json['completedDate']),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'query': query,
        'answer': answer,
        'status': status,
        'error': error,
        'createdDate': createdDate?.toIso8601String(),
        'completedDate': completedDate?.toIso8601String(),
      };
}

class VideoNotes {
  const VideoNotes({
    required this.videoId,
    this.topics = const <NoteTopic>[],
    this.noTopics = false,
    this.review,
    this.reviewUpdatedDate,
    this.description,
    this.descriptionEdited = false,
    this.descriptionStatus,
    this.descriptionError,
    this.answers = const <NoteAnswer>[],
    this.aiAvailable = false,
    this.speechAvailable = false,
    this.telegramLinked = false,
    this.postViewing,
  });

  final int videoId;
  final List<NoteTopic> topics;
  final bool noTopics;
  final String? review;
  final DateTime? reviewUpdatedDate;
  final String? description;
  final bool descriptionEdited;

  /// null, pending, waitingTranscript, ready or failed.
  final String? descriptionStatus;
  final String? descriptionError;
  final List<NoteAnswer> answers;
  final bool aiAvailable;
  final bool speechAvailable;
  final bool telegramLinked;

  /// Whether the post-viewing menu applies to this video (ExternalVideo or Courses).
  /// null when the server does not say; the client then asks the Triage Queue.
  final bool? postViewing;

  bool get isClassified => topics.isNotEmpty || noTopics;

  factory VideoNotes.fromJson(Map<String, dynamic> json) {
    return VideoNotes(
      videoId: _int(json['videoId']),
      topics: notesJsonList(json['topics'])
          .map(NoteTopic.fromJson)
          .toList(growable: false),
      noTopics: _bool(json['noTopics']),
      review: _nullableString(json['review']),
      reviewUpdatedDate: _date(json['reviewUpdatedDate']),
      description: _nullableString(json['description']),
      descriptionEdited: _bool(json['descriptionEdited']),
      descriptionStatus: _nullableString(json['descriptionStatus']),
      descriptionError: _nullableString(json['descriptionError']),
      answers: notesJsonList(json['answers'])
          .map(NoteAnswer.fromJson)
          .toList(growable: false),
      aiAvailable: _bool(json['aiAvailable']),
      speechAvailable: _bool(json['speechAvailable']),
      telegramLinked: _bool(json['telegramLinked']),
      postViewing: _postViewing(json),
    );
  }

  static bool? _postViewing(Map<String, dynamic> json) {
    if (json.containsKey('postViewing')) {
      return _bool(json['postViewing']);
    }
    final Object? type = json['videoType'] ?? json['type'];
    if (type == null) {
      return null;
    }
    if (type is num) {
      // FileStore.Domain.Models.VideoType: Courses = 8, ExternalVideo = 10.
      return type.toInt() == 8 || type.toInt() == 10;
    }
    final String name = type.toString().toLowerCase();
    return name == 'courses' || name == 'externalvideo';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'videoId': videoId,
        'topics': topics.map((NoteTopic t) => t.toJson()).toList(),
        'noTopics': noTopics,
        'review': review,
        'reviewUpdatedDate': reviewUpdatedDate?.toIso8601String(),
        'description': description,
        'descriptionEdited': descriptionEdited,
        'descriptionStatus': descriptionStatus,
        'descriptionError': descriptionError,
        'answers': answers.map((NoteAnswer a) => a.toJson()).toList(),
        'aiAvailable': aiAvailable,
        'speechAvailable': speechAvailable,
        'telegramLinked': telegramLinked,
        if (postViewing != null) 'postViewing': postViewing,
      };

  VideoNotes copyWith({List<NoteTopic>? topics, bool? noTopics}) {
    return VideoNotes(
      videoId: videoId,
      topics: topics ?? this.topics,
      noTopics: noTopics ?? this.noTopics,
      review: review,
      reviewUpdatedDate: reviewUpdatedDate,
      description: description,
      descriptionEdited: descriptionEdited,
      descriptionStatus: descriptionStatus,
      descriptionError: descriptionError,
      answers: answers,
      aiAvailable: aiAvailable,
      speechAvailable: speechAvailable,
      telegramLinked: telegramLinked,
      postViewing: postViewing,
    );
  }
}

class FormulatedAction {
  const FormulatedAction({required this.action, this.position});

  final String action;
  final double? position;

  factory FormulatedAction.fromJson(Map<String, dynamic> json) {
    final Object? position = json['position'];
    return FormulatedAction(
      action: _string(json['action']),
      position: position is num ? position.toDouble() : null,
    );
  }
}

class TriageItem {
  const TriageItem({
    required this.videoId,
    required this.title,
    this.seriesName = '',
    this.watchedDate,
    this.reason = 'classify',
  });

  final int videoId;
  final String title;
  final String seriesName;
  final DateTime? watchedDate;

  /// classify (no Topics yet) or drafts (local Drafts await confirmation).
  final String reason;

  factory TriageItem.fromJson(Map<String, dynamic> json) => TriageItem(
        videoId: _int(json['videoId']),
        title: _string(json['title']),
        seriesName: _string(json['seriesName']),
        watchedDate: _date(json['watchedDate']),
        reason: _string(json['reason']).isEmpty
            ? 'classify'
            : _string(json['reason']),
      );
}

/// What a Draft holds.
enum NoteDraftKind {
  review,
  action,
  query,

  /// A dictated or typed phrase to be matched against the Vocabulary.
  topicsPhrase,

  /// Topics the person already selected offline. They are applied on
  /// reconnect without another confirmation: selecting them was the confirmation.
  topics,
}

enum NoteDraftStatus {
  /// A clip waits for speech recognition.
  pendingRecognition,

  /// Recognition failed; the clip stays until the person retries or deletes it.
  recognitionFailed,

  /// Text is ready and waits for the person's confirmation.
  ready,
}

NoteDraftKind? parseNoteDraftKind(String value) {
  for (final NoteDraftKind kind in NoteDraftKind.values) {
    if (kind.name == value) {
      return kind;
    }
  }
  return null;
}

NoteDraftStatus parseNoteDraftStatus(String value) {
  for (final NoteDraftStatus status in NoteDraftStatus.values) {
    if (status.name == value) {
      return status;
    }
  }
  return NoteDraftStatus.ready;
}

class NoteDraft {
  const NoteDraft({
    required this.id,
    required this.videoId,
    required this.kind,
    required this.status,
    this.text = '',
    this.clipPath,
    this.error = '',
    this.title = '',
    required this.createdAt,
  });

  final int id;
  final int videoId;
  final NoteDraftKind kind;
  final NoteDraftStatus status;
  final String text;
  final String? clipPath;
  final String error;

  /// Video title remembered for the home shelf.
  final String title;
  final DateTime createdAt;

  bool get hasClip => clipPath != null && clipPath!.isNotEmpty;

  /// Whether the person has to do something about it. Topics selected
  /// offline apply on their own; only Topics the server refused need them.
  bool get needsPerson => kind != NoteDraftKind.topics || error.isNotEmpty;

  static NoteDraft? fromRow(Map<String, Object?> row) {
    final NoteDraftKind? kind = parseNoteDraftKind(_string(row['kind']));
    if (kind == null) {
      return null;
    }
    return NoteDraft(
      id: _int(row['id']),
      videoId: _int(row['video_id']),
      kind: kind,
      status: parseNoteDraftStatus(_string(row['status'])),
      text: _string(row['text']),
      clipPath: _nullableString(row['clip_path']),
      error: _string(row['error']),
      title: _string(row['title']),
      createdAt: _date(row['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// Notes of a video as the section shows them.
class NotesSnapshot {
  const NotesSnapshot({
    required this.notes,
    required this.drafts,
    required this.offline,
  });

  /// null when nothing is known about the video (offline and never loaded).
  final VideoNotes? notes;
  final List<NoteDraft> drafts;

  /// Saved notes are shown read-only while this is true.
  final bool offline;
}

/// A video on the home shelf «Заметки».
class NotesShelfItem {
  const NotesShelfItem({
    required this.videoId,
    required this.title,
    this.seriesName = '',
    this.needsClassification = false,
    this.hasDrafts = false,
  });

  final int videoId;
  final String title;
  final String seriesName;

  /// In the Triage Queue because it has no Topics yet («разобрать»).
  final bool needsClassification;

  /// Has local Drafts awaiting confirmation («черновики»).
  final bool hasDrafts;

  String get reasonLabel {
    if (needsClassification && hasDrafts) {
      return 'разобрать · черновики';
    }
    return hasDrafts ? 'черновики' : 'разобрать';
  }
}

class NotesShelfData {
  const NotesShelfData({required this.items});

  final List<NotesShelfItem> items;

  int get count => items.length;
}

/// Outcome of a dictation clip.
class DictationResult {
  const DictationResult({this.text, this.failure, this.keptAsDraft = false});

  /// Recognized text, when recognition happened right away.
  final String? text;
  final NotesFailure? failure;

  /// The clip stays on the device as a Draft (offline or recognition failed).
  final bool keptAsDraft;
}

/// A failure the notes section can show as is.
class NotesFailure implements Exception {
  const NotesFailure(
    this.message, {
    this.offline = false,
    this.timedOut = false,
  });

  final String message;

  /// The server could not be reached; the work was kept as a Draft where possible.
  final bool offline;

  /// The request went out but no answer came in time. It may still have been
  /// carried out, so it is never silently turned into a Draft.
  final bool timedOut;

  @override
  String toString() => message;
}
