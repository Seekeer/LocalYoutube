import 'package:flutter/material.dart';

import 'resolved_thumbnail_image.dart';

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
  });

  final String? localImagePath;
  final String? imageUrl;
  final String title;
  final String metadataLine;
  final double? watchedFraction;
  final bool isDownloaded;
  final VoidCallback onTap;
  final bool allowNetworkFallback;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  ResolvedThumbnailImage(
                    width: double.infinity,
                    height: double.infinity,
                    localPath: localImagePath,
                    networkUrl: imageUrl,
                    allowNetworkFallback: allowNetworkFallback,
                    fit: BoxFit.cover,
                  ),
                  WatchedMaskOverlay(watchedFraction: watchedFraction),
                  DownloadedBadge(isVisible: isDownloaded),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Text(
                metadataLine,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const Divider(height: 1),
          ],
        ),
      ),
    );
  }
}

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
      borderRadius: BorderRadius.circular(8),
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
              fit: BoxFit.fitHeight,
              alignment: Alignment.topCenter,
            ),
            WatchedMaskOverlay(watchedFraction: watchedFraction),
            DownloadedBadge(isVisible: isDownloaded),
          ],
        ),
      ),
    );
  }
}

class DownloadedBadge extends StatelessWidget {
  const DownloadedBadge({
    super.key,
    required this.isVisible,
  });

  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    if (!isVisible) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 8,
      right: 8,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(999),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            Icons.download_done_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
      ),
    );
  }
}

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
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: fraction,
        child: const ColoredBox(
          color: Color(0x66000000),
        ),
      ),
    );
  }
}
