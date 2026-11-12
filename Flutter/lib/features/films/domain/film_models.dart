/// One film of the server's Film section, as the website's «Фильмы» page
/// shows it: poster, Kinopoisk description, year, genres and director.
class Film {
  const Film({
    required this.id,
    required this.title,
    required this.raw,
    this.description = '',
    this.year = 0,
    this.genres = '',
    this.director = '',
    this.durationMinutes = 0,
    this.isFinished = false,
    this.isDownloadingOnServer = false,
  });

  final int id;
  final String title;
  final String description;
  final int year;
  final String genres;
  final String director;
  final int durationMinutes;
  final bool isFinished;

  /// The server is still fetching the torrent, so the file is incomplete.
  final bool isDownloadingOnServer;

  /// The server row as received; the catalog and downloads reuse it.
  final Map<String, dynamic> raw;

  factory Film.fromJson(Map<String, dynamic> map) {
    final String title = _text(map['displayName']).isNotEmpty
        ? _text(map['displayName'])
        : _text(map['name']);
    return Film(
      id: _int(map['id']),
      title: title.isEmpty ? 'Без названия' : title,
      description: _text(map['description']),
      year: _int(map['year']),
      genres: _text(map['genres']),
      director: _text(map['director']),
      durationMinutes: _int(map['durationMinutes']),
      isFinished: map['isFinished'] == true,
      isDownloadingOnServer: map['isDownloading'] == true,
      raw: Map<String, dynamic>.from(map),
    );
  }

  Film copyWith({bool? isFinished}) {
    return Film(
      id: id,
      title: title,
      description: description,
      year: year,
      genres: genres,
      director: director,
      durationMinutes: durationMinutes,
      isFinished: isFinished ?? this.isFinished,
      isDownloadingOnServer: isDownloadingOnServer,
      raw: <String, dynamic>{
        ...raw,
        if (isFinished != null) 'isFinished': isFinished,
      },
    );
  }

  /// «1 час 45 минут», the way the website writes it.
  String get durationLabel {
    if (durationMinutes <= 0) {
      return '';
    }
    final int hours = durationMinutes ~/ 60;
    final int minutes = durationMinutes % 60;
    final String hoursLabel = switch (hours) {
      0 => '',
      1 => '1 час',
      2 || 3 || 4 => '$hours часа',
      _ => '$hours часов',
    };
    if (hoursLabel.isEmpty) {
      return '$minutes мин';
    }
    return minutes == 0 ? hoursLabel : '$hoursLabel $minutes мин';
  }

  static String _text(Object? value) => (value ?? '').toString().trim();

  static int _int(Object? value) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(_text(value)) ?? 0;
  }
}

/// A decade-like bucket of the website's «Годы» filter.
class FilmYearRange {
  const FilmYearRange(this.start, this.end);

  final int start;
  final int end;

  bool contains(int year) => year >= start && year <= end;

  String get label => start == 0 ? 'до $end' : '$start–$end';

  @override
  bool operator ==(Object other) =>
      other is FilmYearRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// The genre and year choices of the website's film filters, newest first.
abstract final class FilmFilterOptions {
  static const List<String> genres = <String>[
    'комедия',
    'драма',
    'боевик',
    'детектив',
    'фантастика',
    'биография',
    'фэнтези',
    'приключения',
    'мелодрама',
  ];

  static const List<FilmYearRange> yearRanges = <FilmYearRange>[
    FilmYearRange(2011, 2030),
    FilmYearRange(2001, 2010),
    FilmYearRange(1991, 2000),
    FilmYearRange(1981, 1990),
    FilmYearRange(1971, 1980),
    FilmYearRange(1951, 1970),
    FilmYearRange(0, 1950),
  ];
}

class FilmFilter {
  const FilmFilter({
    this.query = '',
    this.genres = const <String>{},
    this.yearRanges = const <FilmYearRange>{},
    this.showWatched = false,
  });

  final String query;
  final Set<String> genres;
  final Set<FilmYearRange> yearRanges;

  /// Off by default, as on the website: watched films are hidden.
  final bool showWatched;

  FilmFilter copyWith({
    String? query,
    Set<String>? genres,
    Set<FilmYearRange>? yearRanges,
    bool? showWatched,
  }) {
    return FilmFilter(
      query: query ?? this.query,
      genres: genres ?? this.genres,
      yearRanges: yearRanges ?? this.yearRanges,
      showWatched: showWatched ?? this.showWatched,
    );
  }

  /// Films that pass every filter, newest year first.
  ///
  /// A film matches the genre filter when it has any of the chosen genres,
  /// and the year filter when its year falls in any of the chosen ranges.
  List<Film> apply(List<Film> films) {
    final String needle = query.trim().toLowerCase();
    final List<Film> result = films.where((Film film) {
      if (!showWatched && film.isFinished) {
        return false;
      }
      if (needle.isNotEmpty && !film.title.toLowerCase().contains(needle)) {
        return false;
      }
      if (genres.isNotEmpty) {
        final String filmGenres = film.genres.toLowerCase();
        if (!genres.any((String genre) => filmGenres.contains(genre))) {
          return false;
        }
      }
      if (yearRanges.isNotEmpty &&
          !yearRanges.any((FilmYearRange range) => range.contains(film.year))) {
        return false;
      }
      return true;
    }).toList();
    result.sort((Film a, Film b) {
      final int byYear = b.year.compareTo(a.year);
      return byYear != 0 ? byYear : a.title.compareTo(b.title);
    });
    return result;
  }
}
