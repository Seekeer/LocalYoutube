import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/features/films/domain/film_models.dart';

Film _film(
  int id, {
  String title = 'Film',
  int year = 2000,
  String genres = '',
  bool isFinished = false,
}) {
  return Film.fromJson(<String, dynamic>{
    'id': id,
    'name': title,
    'year': year,
    'genres': genres,
    'isFinished': isFinished,
  });
}

void main() {
  test('parses the server row the website shows', () {
    final Film film = Film.fromJson(<String, dynamic>{
      'id': 7,
      'name': 'raw name',
      'displayName': 'Сталкер',
      'description': 'Зона',
      'year': 1979,
      'genres': 'фантастика, драма',
      'director': 'Андрей Тарковский',
      'durationMinutes': 163,
      'isFinished': true,
      'isDownloading': true,
    });

    expect(film.id, 7);
    expect(film.title, 'Сталкер');
    expect(film.description, 'Зона');
    expect(film.year, 1979);
    expect(film.director, 'Андрей Тарковский');
    expect(film.durationLabel, '2 часа 43 мин');
    expect(film.isFinished, isTrue);
    expect(film.isDownloadingOnServer, isTrue);
  });

  test('duration label covers short and whole-hour films', () {
    expect(
      Film.fromJson(<String, dynamic>{'id': 1, 'durationMinutes': 45})
          .durationLabel,
      '45 мин',
    );
    expect(
      Film.fromJson(<String, dynamic>{'id': 1, 'durationMinutes': 60})
          .durationLabel,
      '1 час',
    );
    expect(
      Film.fromJson(<String, dynamic>{'id': 1, 'durationMinutes': 300})
          .durationLabel,
      '5 часов',
    );
    expect(Film.fromJson(<String, dynamic>{'id': 1}).durationLabel, '');
  });

  test('watched films are hidden until asked for, newest year first', () {
    final List<Film> films = <Film>[
      _film(1, year: 1990),
      _film(2, year: 2020, isFinished: true),
      _film(3, year: 2010),
    ];

    expect(
      const FilmFilter().apply(films).map((Film f) => f.id),
      <int>[3, 1],
    );
    expect(
      const FilmFilter(showWatched: true).apply(films).map((Film f) => f.id),
      <int>[2, 3, 1],
    );
  });

  test('title search ignores case', () {
    final List<Film> films = <Film>[
      _film(1, title: 'Иван Васильевич меняет профессию'),
      _film(2, title: 'Операция «Ы»'),
    ];

    expect(
      const FilmFilter(query: '  ИВАН ').apply(films).map((Film f) => f.id),
      <int>[1],
    );
  });

  test('a film passes the genre filter with any chosen genre', () {
    final List<Film> films = <Film>[
      _film(1, genres: 'Комедия, мелодрама'),
      _film(2, genres: 'драма'),
      _film(3, genres: 'боевик'),
      _film(4),
    ];

    expect(
      const FilmFilter(genres: <String>{'комедия', 'драма'})
          .apply(films)
          .map((Film f) => f.id)
          .toSet(),
      <int>{1, 2},
    );
  });

  test('a film passes the year filter inside any chosen range', () {
    final List<Film> films = <Film>[
      _film(1, year: 1945),
      _film(2, year: 1975),
      _film(3, year: 2015),
    ];

    expect(
      FilmFilter(
        yearRanges: <FilmYearRange>{
          FilmYearRange(0, 1950),
          FilmYearRange(2011, 2030),
        },
      ).apply(films).map((Film f) => f.id),
      <int>[3, 1],
    );
    expect(const FilmYearRange(0, 1950).label, 'до 1950');
    expect(const FilmYearRange(1971, 1980).label, '1971–1980');
  });
}
