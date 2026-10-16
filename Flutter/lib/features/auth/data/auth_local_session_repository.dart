import '../../../core/db/daos/session_meta_dao.dart';
import 'offline_availability_probe.dart';

class AuthLocalSessionRepository {
  AuthLocalSessionRepository(this._sessionMetaDao);

  final SessionMetaDao _sessionMetaDao;

  Future<void> saveSessionMeta({required String userName}) async {
    await _sessionMetaDao.upsertValue(
      key: AuthLocalSessionKeys.userNameKey,
      value: userName,
    );
    await _sessionMetaDao.upsertValue(
      key: AuthLocalSessionKeys.lastLoginAtKey,
      value: DateTime.now().toUtc().toIso8601String(),
    );
  }

  Future<String?> readLastUserName() {
    return _sessionMetaDao.readValue(AuthLocalSessionKeys.userNameKey);
  }

  Future<void> clearSessionMeta() {
    return _sessionMetaDao.clearAll();
  }
}
