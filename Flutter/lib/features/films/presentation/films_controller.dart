import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/bootstrap/bootstrap_providers.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../core/logging/log_service.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/domain/catalog_models.dart';
import '../data/films_remote_data_source.dart';
import '../domain/film_models.dart';

class FilmsState {
  const FilmsState({
    this.films = const <Film>[],
    this.filter = const FilmFilter(),
    this.isLoading = false,
    this.hasLoaded = false,
    this.error,
  });

  /// Every film the server returned; [visibleFilms] is what the filters keep.
  final List<Film> films;
  final FilmFilter filter;
  final bool isLoading;
  final bool hasLoaded;
  final Failure? error;

  List<Film> get visibleFilms => filter.apply(films);

  FilmsState copyWith({
    List<Film>? films,
    FilmFilter? filter,
    bool? isLoading,
    bool? hasLoaded,
    Failure? error,
    bool clearError = false,
  }) {
    return FilmsState(
      films: films ?? this.films,
      filter: filter ?? this.filter,
      isLoading: isLoading ?? this.isLoading,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class FilmsController extends StateNotifier<FilmsState> {
  FilmsController({
    required FilmsRemoteDataSource remoteDataSource,
    required CatalogRepository catalogRepository,
    required LogService logService,
  })  : _remoteDataSource = remoteDataSource,
        _catalogRepository = catalogRepository,
        _logService = logService,
        super(const FilmsState());

  final FilmsRemoteDataSource _remoteDataSource;
  final CatalogRepository _catalogRepository;
  final LogService _logService;
  int _lastLoadId = 0;

  Future<void> load() async {
    final int loadId = ++_lastLoadId;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final List<Film> films = await _remoteDataSource.loadFilms();
      if (loadId != _lastLoadId || !mounted) {
        return;
      }
      state = state.copyWith(films: films, isLoading: false, hasLoaded: true);
    } catch (error, stackTrace) {
      _logService.error('loadFilms failed', error, stackTrace);
      if (loadId != _lastLoadId || !mounted) {
        return;
      }
      state = state.copyWith(
        isLoading: false,
        hasLoaded: true,
        error: mapToFailure(error),
      );
    }
  }

  void setQuery(String query) {
    state = state.copyWith(filter: state.filter.copyWith(query: query));
  }

  void toggleGenre(String genre) {
    final Set<String> genres = <String>{...state.filter.genres};
    if (!genres.remove(genre)) {
      genres.add(genre);
    }
    state = state.copyWith(filter: state.filter.copyWith(genres: genres));
  }

  void toggleYearRange(FilmYearRange range) {
    final Set<FilmYearRange> ranges = <FilmYearRange>{
      ...state.filter.yearRanges,
    };
    if (!ranges.remove(range)) {
      ranges.add(range);
    }
    state = state.copyWith(filter: state.filter.copyWith(yearRanges: ranges));
  }

  void setShowWatched(bool value) {
    state = state.copyWith(filter: state.filter.copyWith(showWatched: value));
  }

  /// Puts the film file into the app's download queue for offline viewing.
  Future<Failure?> download(Film film) {
    return _catalogRepository.queueDownload(_toCatalogItem(film));
  }

  Future<Failure?> markWatched(Film film) async {
    try {
      await _remoteDataSource.markWatched(film.id);
    } catch (error, stackTrace) {
      _logService.error('markWatched(${film.id}) failed', error, stackTrace);
      return mapToFailure(error);
    }
    if (mounted) {
      state = state.copyWith(
        films: state.films
            .map(
              (Film item) =>
                  item.id == film.id ? item.copyWith(isFinished: true) : item,
            )
            .toList(growable: false),
      );
    }
    return null;
  }

  /// Deletes the film from the server database and disk, as the website does.
  Future<Failure?> deleteFromServer(Film film) async {
    final Failure? failure = await _catalogRepository.deleteServer(film.id);
    if (failure == null && mounted) {
      state = state.copyWith(
        films: state.films
            .where((Film item) => item.id != film.id)
            .toList(growable: false),
      );
    }
    return failure;
  }

  CatalogItem _toCatalogItem(Film film) {
    return CatalogItem(
      id: film.id,
      title: film.title,
      raw: <String, dynamic>{
        ...film.raw,
        'description': film.description,
      },
    );
  }
}

final Provider<FilmsRemoteDataSource> filmsRemoteDataSourceProvider =
    Provider<FilmsRemoteDataSource>(
  (Ref ref) => FilmsRemoteDataSource(ref.watch(dioProvider)),
);

final AutoDisposeStateNotifierProvider<FilmsController, FilmsState>
    filmsControllerProvider =
    StateNotifierProvider.autoDispose<FilmsController, FilmsState>(
  (Ref ref) => FilmsController(
    remoteDataSource: ref.watch(filmsRemoteDataSourceProvider),
    catalogRepository: ref.watch(catalogRepositoryProvider),
    logService: ref.watch(logServiceProvider),
  ),
);
