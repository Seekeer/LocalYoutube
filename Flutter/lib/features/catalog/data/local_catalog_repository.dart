import '../../../core/db/daos/videos_cache_dao.dart';

class LocalCatalogRepository {
  LocalCatalogRepository(this._videosCacheDao);

  final VideosCacheDao _videosCacheDao;

  Future<void> saveSection(
    String sectionKey,
    List<Map<String, dynamic>> items,
  ) {
    return _videosCacheDao.saveSectionItems(sectionKey, items);
  }

  Future<List<Map<String, dynamic>>> readSection(String sectionKey) {
    return _videosCacheDao.readSectionItems(sectionKey);
  }
}
