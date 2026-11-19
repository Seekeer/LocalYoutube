import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import 'resolved_thumbnail_image.dart';

/// A video in a phone list: the 16:9 cover on the left (with its length, how
/// far it was watched and whether it is on the phone), the title and details
/// on the right. Rows like this let a 6.8" screen show five or six videos at
/// once, where a full-width cover showed one and a half.
class PortraitVideoListItem extends StatelessWidget {
  const PortraitVideoListItem({
    super.key,
    this.localImagePath,
    this.imageUrl,
    required this.title,
    required this.metadataLine,
    required this.watchedFraction,
    required this.isDownloaded,
    required this.onTap,
    this.allowNetworkFallback = false,
    this.durationLabel,
    this.secondaryLine,
    this.accentLine,
    this.accentColor,
    this.accentIcon,
    this.trailing,
    this.dimmed = false,
    this.badge,
    this.footer,
  });

  /// Anything else on the last line, such as status tags.
  final Widget? footer;

  final String? localImagePath;
  final String? imageUrl;
  final String title;

  /// Series and season, or whatever places the video; empty hides the line.
  final String metadataLine;
  final double? watchedFraction;
  final bool isDownloaded;
  final VoidCallback onTap;
  final bool allowNetworkFallback;

  /// The video's length, shown on the cover.
  final String? durationLabel;

  /// A third line under the details, such as when it was last watched.
  final String? secondaryLine;

  /// A short status in colour, such as «осталось 32 мин» or «Просмотрено».
  final String? accentLine;
  final Color? accentColor;

  /// A small icon before the state, such as a crossed-out cloud.
  final IconData? accentIcon;

  /// A small chip after the details, such as «не скачано».
  final String? badge;

  /// An action at the end of the row, such as a menu.
  final Widget? trailing;

  /// Greys the cover out, for a video that cannot be played right now. The
  /// text keeps its contrast so the row stays readable.
  final bool dimmed;

  static const double _thumbnailWidth = 136;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextTheme text = theme.textTheme;
    final String meta = metadataLine.trim() == '-' ? '' : metadataLine.trim();
    final String secondary = (secondaryLine ?? '').trim();
    final String accent = (accentLine ?? '').trim();
    final ColorScheme colors = theme.colorScheme;

    final Widget cover = VideoCover(
      width: _thumbnailWidth,
      localImagePath: localImagePath,
      imageUrl: imageUrl,
      allowNetworkFallback: allowNetworkFallback,
      watchedFraction: watchedFraction,
      isDownloaded: isDownloaded,
      durationLabel: durationLabel,
      greyed: dimmed,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            LtSizes.gutter,
            8,
            trailing == null ? LtSizes.gutter : 4,
            8,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              cover,
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        keepShortWordsTogether(title),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleSmall?.copyWith(
                          fontSize: 14.5,
                          height: 1.3,
                        ),
                      ),
                      if (meta.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall,
                        ),
                      ],
                      if (secondary.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          secondary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (footer != null) ...<Widget>[
                        const SizedBox(height: 6),
                        footer!,
                      ],
                      if (accent.isNotEmpty || badge != null) ...<Widget>[
                        const SizedBox(height: 6),
                        Row(
                          children: <Widget>[
                            if (accent.isNotEmpty && accentIcon != null) ...<Widget>[
                              Icon(
                                accentIcon,
                                size: 14,
                                color: accentColor ?? colors.primary,
                              ),
                              const SizedBox(width: 4),
                            ],
                            if (accent.isNotEmpty)
                              Flexible(
                                child: Text(
                                  accent,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.labelMedium?.copyWith(
                                    color: accentColor ?? colors.primary,
                                  ),
                                ),
                              ),
                            if (badge != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(color: colors.outline),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  badge!,
                                  style: text.labelSmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Trailing actions centre on the cover.
              if (trailing != null)
                SizedBox(
                  height: _thumbnailWidth * 9 / 16,
                  child: Center(child: trailing),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A rounded 16:9 cover with the video's length, a watched-progress bar along
/// its bottom edge and a mark when the file is on this device.
class VideoCover extends StatelessWidget {
  const VideoCover({
    super.key,
    required this.width,
    required this.watchedFraction,
    required this.isDownloaded,
    this.localImagePath,
    this.imageUrl,
    this.allowNetworkFallback = false,
    this.durationLabel,
    this.greyed = false,
  });

  final double width;
  final double? watchedFraction;
  final bool isDownloaded;
  final String? localImagePath;
  final String? imageUrl;
  final bool allowNetworkFallback;
  final String? durationLabel;

  /// Shows the picture in grey and faded, for a video that cannot be played
  /// now; the length stays readable on it.
  final bool greyed;

  @override
  Widget build(BuildContext context) {
    final double height = width * 9 / 16;
    final String duration = (durationLabel ?? '').trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(LtSizes.radiusM),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (greyed)
              Opacity(
                opacity: 0.7,
                child: ColorFiltered(
                  colorFilter: const ColorFilter.matrix(<double>[
                    0.33, 0.59, 0.11, 0, 0, //
                    0.33, 0.59, 0.11, 0, 0, //
                    0.33, 0.59, 0.11, 0, 0, //
                    0, 0, 0, 1, 0,
                  ]),
                  child: ResolvedThumbnailImage(
                    width: width,
                    height: height,
                    localPath: localImagePath,
                    networkUrl: imageUrl,
                    allowNetworkFallback: allowNetworkFallback,
                    fit: BoxFit.cover,
                  ),
                ),
              )
            else
              ResolvedThumbnailImage(
                width: width,
                height: height,
                localPath: localImagePath,
                networkUrl: imageUrl,
                allowNetworkFallback: allowNetworkFallback,
                fit: BoxFit.cover,
              ),
            if (Theme.of(context).brightness == Brightness.dark)
              const ColoredBox(color: Color(0x24000000)),
            if (duration.isNotEmpty)
              Positioned(
                right: 6,
                bottom: 8,
                child: _DurationChip(label: duration),
              ),
            DownloadedBadge(isVisible: isDownloaded),
            WatchedMaskOverlay(watchedFraction: watchedFraction),
          ],
        ),
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  const _DurationChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xD910121F),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            height: 1.3,
            fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

/// The older, smaller cover used by landscape lists.
class VideoThumbnail extends StatelessWidget {
  const VideoThumbnail({
    super.key,
    required this.width,
    required this.height,
    required this.watchedFraction,
    required this.isDownloaded,
    this.localImagePath,
    this.imageUrl,
    this.allowNetworkFallback = false,
  });

  final double width;
  final double height;
  final double? watchedFraction;
  final bool isDownloaded;
  final String? localImagePath;
  final String? imageUrl;
  final bool allowNetworkFallback;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(LtSizes.radiusS),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ResolvedThumbnailImage(
              width: width,
              height: height,
              localPath: localImagePath,
              networkUrl: imageUrl,
              allowNetworkFallback: allowNetworkFallback,
              fit: BoxFit.cover,
            ),
            DownloadedBadge(isVisible: isDownloaded, compact: true),
            WatchedMaskOverlay(watchedFraction: watchedFraction),
          ],
        ),
      ),
    );
  }
}

/// A small mint mark in the corner of a cover: the video is on this device.
class DownloadedBadge extends StatelessWidget {
  const DownloadedBadge({
    super.key,
    required this.isVisible,
    this.compact = false,
  });

  final bool isVisible;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!isVisible) {
      return const SizedBox.shrink();
    }
    return Positioned(
      top: compact ? 4 : 6,
      left: compact ? 4 : 6,
      child: Tooltip(
        message: 'Скачано на телефон',
        child: DecoratedBox(
          // The same deep mint in both themes, so the white check always reads.
          decoration: BoxDecoration(
            color: LtColors.mint,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: Padding(
            padding: EdgeInsets.all(compact ? 2 : 3),
            child: Icon(
              Icons.download_done_rounded,
              size: compact ? 12 : 14,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// How far the video was watched: a coral bar along the bottom of the cover,
/// the way video sites show it.
class WatchedMaskOverlay extends StatelessWidget {
  const WatchedMaskOverlay({
    super.key,
    required this.watchedFraction,
  });

  final double? watchedFraction;

  @override
  Widget build(BuildContext context) {
    final double fraction = (watchedFraction ?? 0).clamp(0.0, 1.0).toDouble();
    if (fraction <= 0) {
      return const SizedBox.shrink();
    }
    return Align(
      alignment: Alignment.bottomLeft,
      child: SizedBox(
        height: 4,
        width: double.infinity,
        child: ColoredBox(
          color: const Color(0x66FFFFFF),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: fraction,
            // Watched to the end: mint, the colour «Просмотрено» uses.
            child: ColoredBox(
              color: fraction >= 0.95 ? LtColors.subtle : LtColors.coral,
            ),
          ),
        ),
      ),
    );
  }
}

/// Russian typesetting for a title in a narrow column:
/// - a dash stays with the word before it, so no line starts with «—»;
/// - a one-letter word («с», «и», «в») and a number («14.») stay with the
///   word after them;
/// - the last word, when short, stays with the one before it, so a line
///   never ends a title with one short word alone.
/// «Angular с нуля — 14. Сервисы и DI» breaks as
/// «Angular с нуля — / 14. Сервисы и DI».
String keepShortWordsTogether(String title) {
  const String nbsp = '\u00a0';
  String text = title.trim().replaceAll(RegExp(r'\s+'), ' ');
  text = text.replaceAll(' — ', '$nbsp— ');
  text = text.replaceAllMapped(
    RegExp(r'(^|[ \u00a0])(\p{L}) ', unicode: true),
    (Match m) => '${m[1]}${m[2]}$nbsp',
  );
  text = text.replaceAllMapped(
    RegExp(r'(^|[ \u00a0])(\d+\.?) '),
    (Match m) => '${m[1]}${m[2]}$nbsp',
  );
  final List<String> words = text.split(' ');
  if (words.length < 3) {
    return text;
  }
  final String last = words.removeLast();
  if (last.length > 4) {
    return text;
  }
  final String previous = words.removeLast();
  return <String>[...words, '$previous$nbsp$last'].join(' ');
}
