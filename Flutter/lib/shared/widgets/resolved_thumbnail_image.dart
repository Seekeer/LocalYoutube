import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/bootstrap/bootstrap_providers.dart';
import '../../core/network/api_route.dart';

/// Shows a local thumbnail when one exists, otherwise a network thumbnail.
///
/// Network thumbnails are resolved through [ApiRoute] before they are handed
/// to [Image.network], because Flutter's image loader bypasses Dio and would
/// otherwise always request the public API origin.
class ResolvedThumbnailImage extends ConsumerStatefulWidget {
  const ResolvedThumbnailImage({
    super.key,
    required this.width,
    required this.height,
    this.localPath,
    this.networkUrl,
    this.allowNetworkFallback = false,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
  });

  final double width;
  final double height;
  final String? localPath;
  final String? networkUrl;
  final bool allowNetworkFallback;
  final BoxFit fit;
  final Alignment alignment;

  @override
  ConsumerState<ResolvedThumbnailImage> createState() =>
      _ResolvedThumbnailImageState();
}

class _ResolvedThumbnailImageState
    extends ConsumerState<ResolvedThumbnailImage> {
  String? _routedNetworkUrl;
  bool _routeFallbackScheduled = false;

  @override
  void initState() {
    super.initState();
    _resolveNetworkUrl();
  }

  @override
  void didUpdateWidget(ResolvedThumbnailImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.networkUrl != widget.networkUrl) {
      _resolveNetworkUrl();
    }
  }

  Future<void> _resolveNetworkUrl() async {
    final String? rawUrl = _normalize(widget.networkUrl);
    if (rawUrl == null) {
      if (mounted && _routedNetworkUrl != null) {
        setState(() => _routedNetworkUrl = null);
      }
      return;
    }
    String resolved = rawUrl;
    try {
      final ApiRoute route = ref.read(apiRouteProvider);
      resolved = (await route.routeMediaUri(Uri.parse(rawUrl))).toString();
    } catch (_) {
      resolved = rawUrl;
    }
    if (!mounted || _normalize(widget.networkUrl) != rawUrl) {
      return;
    }
    if (_routedNetworkUrl != resolved) {
      setState(() => _routedNetworkUrl = resolved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? normalizedLocalPath = _normalize(widget.localPath);
    if (normalizedLocalPath != null) {
      return Image.file(
        File(normalizedLocalPath),
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        alignment: widget.alignment,
        errorBuilder: (_, __, ___) => _buildThumbnail(context),
      );
    }
    return _buildThumbnail(context);
  }

  Widget _buildThumbnail(BuildContext context) {
    final String? networkUrl = _routedNetworkUrl;
    if (widget.allowNetworkFallback && networkUrl != null) {
      return _buildNetworkImage(context, networkUrl);
    }
    if (widget.allowNetworkFallback && _normalize(widget.networkUrl) != null) {
      return _buildProgress(context);
    }
    return _buildPlaceholder(context);
  }

  Widget _buildNetworkImage(BuildContext context, String url) {
    return Image.network(
      url,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      alignment: widget.alignment,
      errorBuilder: (_, Object error, __) {
        _handleNetworkError(url, error);
        return _buildPlaceholder(context);
      },
      loadingBuilder: (
        BuildContext loadingContext,
        Widget child,
        ImageChunkEvent? loadingProgress,
      ) {
        if (loadingProgress == null) {
          return child;
        }
        return _buildProgress(loadingContext);
      },
    );
  }

  void _handleNetworkError(String url, Object error) {
    final String? originalUrl = _normalize(widget.networkUrl);
    final bool transportFailure =
        error is IOException || error is TimeoutException;
    if (originalUrl == null ||
        url == originalUrl ||
        _routeFallbackScheduled ||
        !transportFailure) {
      return;
    }
    _routeFallbackScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _routeFallbackScheduled = false;
      if (!mounted || _normalize(widget.networkUrl) != originalUrl) {
        return;
      }
      setState(() => _routedNetworkUrl = originalUrl);
    });
  }

  Widget _buildProgress(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: const Center(
          child: Icon(Icons.movie_outlined),
        ),
      ),
    );
  }

  String? _normalize(String? value) {
    final String normalized = (value ?? '').trim();
    return normalized.isEmpty ? null : normalized;
  }
}
