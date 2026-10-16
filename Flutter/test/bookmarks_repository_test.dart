import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/core/db/app_database.dart';
import 'package:localtube_flutter/core/db/daos/bookmarks_dao.dart';
import 'package:localtube_flutter/core/db/daos/sync_outbox_dao.dart';
import 'package:localtube_flutter/core/logging/log_service.dart';
import 'package:localtube_flutter/features/bookmarks/data/bookmarks_remote_data_source.dart';
import 'package:localtube_flutter/features/bookmarks/data/bookmarks_repository.dart';
import 'package:localtube_flutter/features/bookmarks/data/local_bookmarks_repository.dart';
import 'package:localtube_flutter/features/sync/data/local_sync_outbox_repository.dart';

void main() {
  late AppDatabase database;
  late LocalBookmarksRepository localBookmarksRepository;
  late LocalSyncOutboxRepository localSyncOutboxRepository;
  late _FakeBookmarksRemoteDataSource remoteDataSource;
  late BookmarksRepository repository;

  setUp(() async {
    database = AppDatabase(executor: NativeDatabase.memory());
    await database.initialize();

    localBookmarksRepository = LocalBookmarksRepository(BookmarksDao(database));
    localSyncOutboxRepository =
        LocalSyncOutboxRepository(SyncOutboxDao(database));
    remoteDataSource = _FakeBookmarksRemoteDataSource();
    repository = BookmarksRepository(
      remoteDataSource: remoteDataSource,
      localBookmarksRepository: localBookmarksRepository,
      localSyncOutboxRepository: localSyncOutboxRepository,
      logService: _NoopLogService(),
    );
  });

  test('stores failed add in outbox and retries successfully', () async {
    remoteDataSource.failAdd = true;

    final bool added = await repository.addBookmark(
      videoId: 10,
      positionSeconds: 42,
      caption: 'Bookmark',
    );

    expect(added, isTrue);

    List<Map<String, Object?>> outbox =
        await localSyncOutboxRepository.listPending(limit: 100);
    expect(outbox.length, 1);

    final int localId = (await repository.listLocalForVideo(10)).single.id;
    expect(localId, lessThan(0));

    remoteDataSource.failAdd = false;
    await repository.processOutbox();

    outbox = await localSyncOutboxRepository.listPending(limit: 100);
    expect(outbox, isEmpty);

    final List<int> bookmarkIds = (await repository.listLocalForVideo(10))
        .map((item) => item.id)
        .toList(growable: false);
    expect(bookmarkIds, hasLength(1));
    expect(bookmarkIds.single, greaterThan(0));
  });

  test('does not add duplicate bookmark inside 5 second window', () async {
    final bool firstAdd = await repository.addBookmark(
      videoId: 3,
      positionSeconds: 20,
      caption: 'Bookmark',
    );
    final bool duplicateAdd = await repository.addBookmark(
      videoId: 3,
      positionSeconds: 24.9,
      caption: 'Bookmark',
    );

    expect(firstAdd, isTrue);
    expect(duplicateAdd, isFalse);
    expect((await repository.listLocalForVideo(3)).length, 1);
  });

  test('skips stale add outbox operation if local bookmark was deleted',
      () async {
    remoteDataSource.failAdd = true;

    await repository.addBookmark(
      videoId: 77,
      positionSeconds: 15,
      caption: 'Bookmark',
    );
    final int localId = (await repository.listLocalForVideo(77)).single.id;
    expect(localId, lessThan(0));

    await repository.deleteBookmark(localId);
    expect(await repository.listLocalForVideo(77), isEmpty);

    remoteDataSource.failAdd = false;
    await repository.processOutbox();

    final List<Map<String, Object?>> outbox =
        await localSyncOutboxRepository.listPending(limit: 100);
    expect(outbox, isEmpty);
    expect(await repository.listLocalForVideo(77), isEmpty);
  });
}

class _FakeBookmarksRemoteDataSource extends BookmarksRemoteDataSource {
  _FakeBookmarksRemoteDataSource() : super(Dio());

  bool failAdd = false;
  bool failDelete = false;
  int _nextId = 1;
  final List<Map<String, dynamic>> _remote = <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> getAllForVideo(int videoId) async {
    return _remote
        .where((Map<String, dynamic> item) => item['dbFileId'] == videoId)
        .map((Map<String, dynamic> item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  @override
  Future<int> add({
    required int videoId,
    required double positionSeconds,
    required String caption,
  }) async {
    if (failAdd) {
      throw DioException(
        requestOptions: RequestOptions(path: '/marks/add'),
      );
    }

    final int id = _nextId++;
    _remote.add(
      <String, dynamic>{
        'id': id,
        'dbFileId': videoId,
        'position': positionSeconds,
        'caption': caption,
      },
    );
    return id;
  }

  @override
  Future<void> delete(int bookmarkId) async {
    if (failDelete) {
      throw DioException(
        requestOptions: RequestOptions(path: '/marks/$bookmarkId'),
      );
    }
    _remote.removeWhere(
      (Map<String, dynamic> item) => item['id'] == bookmarkId,
    );
  }
}

class _NoopLogService extends LogService {
  @override
  void debug(String message) {}

  @override
  void info(String message) {}

  @override
  void warn(String message) {}

  @override
  void error(String message, Object error, StackTrace stackTrace) {}
}
