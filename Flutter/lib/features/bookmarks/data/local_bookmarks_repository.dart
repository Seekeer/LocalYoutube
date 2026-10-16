import '../../../core/db/daos/bookmarks_dao.dart';

class LocalBookmarksRepository {
  LocalBookmarksRepository(this._dao);

  final BookmarksDao _dao;

  Future<void> upsertBookmark({
    required int bookmarkId,
    required int videoId,
    required double positionSeconds,
    String? caption,
    DateTime? updatedAt,
  }) {
    return _dao.upsertBookmark(
      bookmarkId: bookmarkId,
      videoId: videoId,
      positionSeconds: positionSeconds,
      caption: caption,
      updatedAt: updatedAt,
    );
  }

  Future<List<Map<String, Object?>>> listForVideo(int videoId) {
    return _dao.readForVideo(videoId);
  }

  Future<Map<String, Object?>?> findById(int bookmarkId) {
    return _dao.readById(bookmarkId);
  }

  Future<void> deleteBookmark(int bookmarkId) {
    return _dao.deleteBookmark(bookmarkId);
  }
}
