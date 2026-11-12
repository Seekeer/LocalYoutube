import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/bootstrap/bootstrap_providers.dart';
import '../../../app/router/app_routes.dart';
import '../../../core/errors/failure.dart';
import '../../../shared/widgets/resolved_thumbnail_image.dart';
import '../../../shared/widgets/state_feedback.dart';
import '../../downloads/domain/download_models.dart';
import '../../downloads/domain/download_service.dart';
import '../../player/presentation/player_navigation_result.dart';
import '../domain/film_models.dart';
import 'films_controller.dart';

/// The Films menu entry is part of the Windows edition.
bool get filmsMenuAvailable =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

final AutoDisposeStreamProvider<Map<int, DownloadItem>>
    _filmDownloadsByVideoIdProvider =
    StreamProvider.autoDispose<Map<int, DownloadItem>>((Ref ref) async* {
  final DownloadService downloadService = ref.read(downloadServiceProvider);
  await for (final List<DownloadItem> items
      in downloadService.watchDownloads()) {
    yield <int, DownloadItem>{
      for (final DownloadItem item in items) item.videoId: item,
    };
  }
});

/// The website's «Фильмы» page: posters with Kinopoisk details, filters by
/// title, genre, years and watched state; a film plays in the app's player
/// or downloads to this computer for offline viewing.
class FilmsPage extends ConsumerStatefulWidget {
  const FilmsPage({super.key});

  @override
  ConsumerState<FilmsPage> createState() => _FilmsPageState();
}

class _FilmsPageState extends ConsumerState<FilmsPage> {
  static const double _cardMinWidth = 540;
  static const double _gridSpacing = 16;
  static const double _cardHeight = 330;

  /// A narrow card wraps its buttons onto more rows, so it gets more height.
  static const double _narrowCardHeight = 440;

  final TextEditingController _searchController = TextEditingController();
  final Set<int> _busyFilmIds = <int>{};

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(filmsControllerProvider.notifier).load(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final FilmsState state = ref.watch(filmsControllerProvider);
    final Map<int, DownloadItem> downloads =
        ref.watch(_filmDownloadsByVideoIdProvider).valueOrNull ??
            const <int, DownloadItem>{};
    final List<Film> films = state.visibleFilms;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Фильмы'),
        actions: <Widget>[
          IconButton(
            key: const Key('films-downloads-button'),
            tooltip: 'Скачиваемое',
            onPressed: () => context.push(AppRoutes.downloads),
            icon: const Icon(Icons.download),
          ),
          IconButton(
            key: const Key('films-refresh-button'),
            tooltip: 'Обновить',
            onPressed: state.isLoading
                ? null
                : () => ref.read(filmsControllerProvider.notifier).load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(child: _buildFilters(context, state)),
          if (state.isLoading)
            const SliverToBoxAdapter(child: LinearProgressIndicator()),
          if (state.error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: StateFeedbackBanner(
                  message: 'Не удалось загрузить фильмы: '
                      '${state.error!.message}',
                  tone: StateFeedbackTone.error,
                ),
              ),
            ),
          if (films.isEmpty && state.hasLoaded && !state.isLoading)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: StateFeedbackPlaceholder(
                  icon: Icons.movie_filter_outlined,
                  title:
                      state.films.isEmpty ? 'Фильмов нет' : 'Ничего не найдено',
                  message: state.films.isEmpty
                      ? 'На сервере пока нет фильмов.'
                      : 'Измените поиск или фильтры.',
                  actionLabel: 'Обновить',
                  onAction: () =>
                      ref.read(filmsControllerProvider.notifier).load(),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverLayoutBuilder(
                builder:
                    (BuildContext context, SliverConstraints constraints) =>
                        SliverGrid(
                  gridDelegate: _gridDelegateFor(constraints.crossAxisExtent),
                  delegate: SliverChildBuilderDelegate(
                    (BuildContext context, int index) {
                      final Film film = films[index];
                      return _FilmCard(
                        key: ValueKey<int>(film.id),
                        film: film,
                        posterUrl: _posterUrl(film.id),
                        download: downloads[film.id],
                        isBusy: _busyFilmIds.contains(film.id),
                        onPlay: () => _play(film),
                        onDownload: () => _download(film),
                        onMarkWatched: () => _markWatched(film),
                        onDelete: () => _delete(film),
                      );
                    },
                    childCount: films.length,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context, FilmsState state) {
    final FilmsController controller =
        ref.read(filmsControllerProvider.notifier);
    final TextTheme textTheme = Theme.of(context).textTheme;
    final FilmFilter filter = state.filter;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: TextField(
                  key: const Key('films-search-field'),
                  controller: _searchController,
                  onChanged: controller.setQuery,
                  decoration: InputDecoration(
                    labelText: 'Название',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: filter.query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Очистить',
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              controller.setQuery('');
                            },
                          ),
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Switch(
                    key: const Key('films-show-watched-switch'),
                    value: filter.showWatched,
                    onChanged: controller.setShowWatched,
                  ),
                  const SizedBox(width: 4),
                  const Flexible(child: Text('Показать просмотренное')),
                ],
              ),
              if (state.hasLoaded)
                Text(
                  'Найдено: ${state.visibleFilms.length} из ${state.films.length}',
                  style: textTheme.bodySmall,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Жанры', style: textTheme.labelLarge),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final String genre in FilmFilterOptions.genres)
                FilterChip(
                  label: Text(genre),
                  selected: filter.genres.contains(genre),
                  onSelected: (_) => controller.toggleGenre(genre),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Годы', style: textTheme.labelLarge),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final FilmYearRange range in FilmFilterOptions.yearRanges)
                FilterChip(
                  label: Text(range.label),
                  selected: filter.yearRanges.contains(range),
                  onSelected: (_) => controller.toggleYearRange(range),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// As many columns as fit with every card at least [_cardMinWidth] wide;
  /// a window narrower than one such card gets one taller column.
  SliverGridDelegate _gridDelegateFor(double width) {
    final int columns =
        ((width + _gridSpacing) / (_cardMinWidth + _gridSpacing))
            .floor()
            .clamp(1, 6)
            .toInt();
    final bool isNarrow = width < _cardMinWidth;
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      mainAxisExtent: isNarrow ? _narrowCardHeight : _cardHeight,
      crossAxisSpacing: _gridSpacing,
      mainAxisSpacing: _gridSpacing,
    );
  }

  String _posterUrl(int videoId) {
    final Uri baseUri = Uri.parse(ref.read(appConfigProvider).apiBaseUrl);
    return baseUri.resolve('/api/files/getImage?fileId=$videoId').toString();
  }

  Future<void> _play(Film film) async {
    final String description = film.description.trim();
    final PlayerNavigationResult? result =
        await context.push<PlayerNavigationResult>(
      '${AppRoutes.player}/${film.id}',
      extra: <String, String>{
        'title': film.title,
        if (description.isNotEmpty) 'description': description,
      },
    );
    if (!mounted) {
      return;
    }
    showPlayerNavigationResultSnackBar(context, result);
    // Watching changes the watched state and the player can delete the file.
    unawaited(ref.read(filmsControllerProvider.notifier).load());
  }

  Future<void> _download(Film film) {
    return _runForFilm(
      film,
      () => ref.read(filmsControllerProvider.notifier).download(film),
      successMessage: '«${film.title}» поставлен на скачивание',
    );
  }

  Future<void> _markWatched(Film film) {
    return _runForFilm(
      film,
      () => ref.read(filmsControllerProvider.notifier).markWatched(film),
      successMessage: '«${film.title}» отмечен просмотренным',
    );
  }

  Future<void> _delete(Film film) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Удалить фильм?'),
        content: Text(
          '«${film.title}» будет удалён из базы и с диска сервера.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            key: const Key('films-delete-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await _runForFilm(
      film,
      () => ref.read(filmsControllerProvider.notifier).deleteFromServer(film),
      successMessage: '«${film.title}» удалён с сервера',
    );
  }

  Future<void> _runForFilm(
    Film film,
    Future<Failure?> Function() action, {
    required String successMessage,
  }) async {
    if (_busyFilmIds.contains(film.id)) {
      return;
    }
    setState(() => _busyFilmIds.add(film.id));
    final Failure? failure;
    try {
      failure = await action();
    } finally {
      if (mounted) {
        setState(() => _busyFilmIds.remove(film.id));
      }
    }
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(failure?.message ?? successMessage)),
    );
  }
}

class _FilmCard extends StatelessWidget {
  const _FilmCard({
    super.key,
    required this.film,
    required this.posterUrl,
    required this.download,
    required this.isBusy,
    required this.onPlay,
    required this.onDownload,
    required this.onMarkWatched,
    required this.onDelete,
  });

  static const double _posterWidth = 200;
  static const double _posterHeight = 300;

  final Film film;
  final String posterUrl;
  final DownloadItem? download;
  final bool isBusy;
  final VoidCallback onPlay;
  final VoidCallback onDownload;
  final VoidCallback onMarkWatched;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;
    final List<String> meta = <String>[
      if (film.year > 0) '${film.year}',
      if (film.durationLabel.isNotEmpty) film.durationLabel,
    ];

    return Card(
      key: Key('film-card-${film.id}'),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            // Narrow windows give the text more room than the poster.
            final double posterWidth = constraints.maxWidth < 520
                ? constraints.maxWidth * 0.32
                : _posterWidth;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                InkWell(
                  onTap: onPlay,
                  child: Opacity(
                    // Watched films are dimmed, as on the website.
                    opacity: film.isFinished ? 0.45 : 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: ResolvedThumbnailImage(
                        width: posterWidth,
                        height: _posterHeight,
                        networkUrl: posterUrl,
                        allowNetworkFallback: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        film.title,
                        style: textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (meta.isNotEmpty || film.isFinished)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            <String>[
                              ...meta,
                              if (film.isFinished) 'просмотрено',
                            ].join(' · '),
                            style: textTheme.bodySmall,
                          ),
                        ),
                      if (film.genres.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            film.genres,
                            style: textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (film.director.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Режиссёр: ${film.director}',
                            style: textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: Text(
                          film.description,
                          style: textTheme.bodyMedium,
                          overflow: TextOverflow.fade,
                        ),
                      ),
                      _buildDownloadProgress(),
                      const SizedBox(height: 6),
                      _buildActions(),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDownloadProgress() {
    final DownloadItem? item = download;
    if (item == null || !item.status.isActive) {
      return const SizedBox.shrink();
    }
    final bool started =
        item.status == DownloadStatus.downloading || item.progress > 0;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: LinearProgressIndicator(value: started ? item.progress : null),
    );
  }

  Widget _buildActions() {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        FilledButton.icon(
          key: Key('film-play-${film.id}'),
          onPressed: onPlay,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Смотреть'),
        ),
        _buildDownloadButton(),
        if (!film.isFinished)
          TextButton.icon(
            key: Key('film-watched-${film.id}'),
            onPressed: isBusy ? null : onMarkWatched,
            icon: const Icon(Icons.done_all),
            label: const Text('Просмотрено'),
          ),
        IconButton(
          key: Key('film-delete-${film.id}'),
          tooltip: 'Удалить с сервера',
          onPressed: isBusy ? null : onDelete,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }

  Widget _buildDownloadButton() {
    final DownloadItem? item = download;
    final Key key = Key('film-download-${film.id}');
    if (item != null && item.status == DownloadStatus.completed) {
      return OutlinedButton.icon(
        key: key,
        onPressed: null,
        icon: const Icon(Icons.download_done),
        label: const Text('Скачано'),
      );
    }
    if (item != null && item.status.isActive) {
      final int percent = (item.progress * 100).round().clamp(0, 100).toInt();
      return OutlinedButton.icon(
        key: key,
        onPressed: null,
        icon: const Icon(Icons.downloading),
        label: Text(
          item.status == DownloadStatus.queued && item.progress <= 0
              ? 'В очереди'
              : 'Скачивается $percent%',
        ),
      );
    }
    final Widget button = OutlinedButton.icon(
      key: key,
      onPressed: isBusy || film.isDownloadingOnServer ? null : onDownload,
      icon: const Icon(Icons.download_outlined),
      label: Text(
        item == null || item.status == DownloadStatus.paused
            ? 'Скачать'
            : 'Скачать снова',
      ),
    );
    if (!film.isDownloadingOnServer) {
      return button;
    }
    return Tooltip(
      message: 'Фильм ещё скачивается на сервер',
      child: button,
    );
  }
}
