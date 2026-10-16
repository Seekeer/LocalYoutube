import '../../../core/db/daos/bookmarks_dao.dart';
import '../../../core/db/daos/downloads_dao.dart';
import '../../../core/db/daos/playback_positions_dao.dart';
import '../../../core/db/daos/session_meta_dao.dart';
import '../../../core/db/daos/videos_cache_dao.dart';

class OfflineAvailabilityProbe {
  OfflineAvailabilityProbe({
    required SessionMetaDao sessionMetaDao,
    required VideosCacheDao videosCacheDao,
    required DownloadsDao downloadsDao,
    required PlaybackPositionsDao playbackPositionsDao,
    required BookmarksDao bookmarksDao,
  })  : _sessionMetaDao = sessionMetaDao,
        _videosCacheDao = videosCacheDao,
        _downloadsDao = downloadsDao,
        _playbackPositionsDao = playbackPositionsDao,
        _bookmarksDao = bookmarksDao;

  final SessionMetaDao _sessionMetaDao;
  final VideosCacheDao _videosCacheDao;
  final DownloadsDao _downloadsDao;
  final PlaybackPositionsDao _playbackPositionsDao;
  final BookmarksDao _bookmarksDao;

  Future<bool> canEnterOfflineFallback() async {
    final bool hasSessionFootprint = await _hasSessionFootprint();
    if (!hasSessionFootprint) {
      return false;
    }
    return _hasLocalShellData();
  }

  Future<bool> _hasSessionFootprint() async {
    final String? userName =
        await _sessionMetaDao.readValue(AuthLocalSessionKeys.userNameKey);
    final String? lastLoginAt =
        await _sessionMetaDao.readValue(AuthLocalSessionKeys.lastLoginAtKey);
    return (userName ?? '').trim().isNotEmpty ||
        (lastLoginAt ?? '').trim().isNotEmpty;
  }

  Future<bool> _hasLocalShellData() async {
    if (await _videosCacheDao.hasAnyItems()) {
      return true;
    }
    if (await _downloadsDao.hasAnyDownloads()) {
      return true;
    }
    if (await _playbackPositionsDao.hasAnyPositions()) {
      return true;
    }
    if (await _bookmarksDao.hasAnyBookmarks()) {
      return true;
    }
    return false;
  }
}

abstract final class AuthLocalSessionKeys {
  static const String userNameKey = 'user_name';
  static const String lastLoginAtKey = 'last_login_at';
}
