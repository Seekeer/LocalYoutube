enum CatalogSection { latest, fresh, history, series, playlists }

CatalogSection parseCatalogSection(
  String? rawKey, {
  CatalogSection fallback = CatalogSection.latest,
}) {
  final String key = (rawKey ?? '').trim().toLowerCase();
  for (final CatalogSection section in CatalogSection.values) {
    if (section.key == key) {
      return section;
    }
  }
  return fallback;
}

extension CatalogSectionX on CatalogSection {
  String get key {
    switch (this) {
      case CatalogSection.latest:
        return 'latest';
      case CatalogSection.fresh:
        return 'fresh';
      case CatalogSection.history:
        return 'history';
      case CatalogSection.series:
        return 'series';
      case CatalogSection.playlists:
        return 'playlists';
    }
  }

  String get title {
    switch (this) {
      case CatalogSection.latest:
        return '\u041f\u043e\u0441\u043b\u0435\u0434\u043d\u0438\u0435';
      case CatalogSection.fresh:
        return '\u041d\u043e\u0432\u0438\u043d\u043a\u0438';
      case CatalogSection.history:
        return '\u0418\u0441\u0442\u043e\u0440\u0438\u044f';
      case CatalogSection.series:
        return '\u0421\u0435\u0440\u0438\u0438/\u0441\u0435\u0437\u043e\u043d\u044b';
      case CatalogSection.playlists:
        return '\u041f\u043b\u0435\u0439\u043b\u0438\u0441\u0442\u044b';
    }
  }
}

class CatalogItem {
  const CatalogItem({required this.id, required this.title, required this.raw});

  final int id;
  final String title;
  final Map<String, dynamic> raw;

  String get description {
    final Object? value = raw['description'];
    return value?.toString() ?? '';
  }

  String get remoteUrl => '/api/files/getFileById?fileId=$id';

  CatalogItem copyWith({int? id, String? title, Map<String, dynamic>? raw}) {
    return CatalogItem(
      id: id ?? this.id,
      title: title ?? this.title,
      raw: raw ?? this.raw,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        ...raw,
        'id': id,
        'title': title,
      };

  factory CatalogItem.fromJson(Map<String, dynamic> map) {
    final int id = (map['id'] as num?)?.toInt() ?? 0;
    final String title = (map['name'] ?? map['title'] ?? 'Untitled').toString();
    return CatalogItem(
      id: id,
      title: title,
      raw: Map<String, dynamic>.from(map),
    );
  }

  factory CatalogItem.fromPlaylist(
    PlaylistSummary playlist, {
    String? description,
  }) {
    return CatalogItem(
      id: playlist.id,
      title: playlist.name,
      raw: <String, dynamic>{
        ...playlist.toJson(),
        if (description != null) 'description': description,
      },
    );
  }
}

class CatalogLoadResult {
  const CatalogLoadResult({
    required this.items,
    this.fromCache = false,
    this.errorMessage,
  });

  final List<CatalogItem> items;
  final bool fromCache;
  final String? errorMessage;
}

class PlaylistSummary {
  const PlaylistSummary({required this.id, required this.name});

  final int id;
  final String name;

  factory PlaylistSummary.fromJson(Map<String, dynamic> map) {
    final int id = (map['id'] as num?)?.toInt() ?? 0;
    final String name = (map['name'] ?? map['title'] ?? '').toString().trim();
    return PlaylistSummary(id: id, name: name.isEmpty ? 'Playlist $id' : name);
  }

  factory PlaylistSummary.fromCatalogItem(CatalogItem item) {
    return PlaylistSummary(id: item.id, name: item.title);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{'id': id, 'name': name};
}
