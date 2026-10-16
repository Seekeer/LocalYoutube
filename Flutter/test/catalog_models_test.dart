import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/features/catalog/domain/catalog_models.dart';

void main() {
  test('catalog section keys are stable', () {
    expect(CatalogSection.latest.key, 'latest');
    expect(CatalogSection.fresh.key, 'fresh');
    expect(CatalogSection.history.key, 'history');
    expect(CatalogSection.series.key, 'series');
    expect(CatalogSection.playlists.key, 'playlists');
  });

  test('catalog item parses id and title', () {
    final CatalogItem item = CatalogItem.fromJson(<String, dynamic>{
      'id': 10,
      'name': 'Demo',
      'description': 'Text',
    });

    expect(item.id, 10);
    expect(item.title, 'Demo');
    expect(item.description, 'Text');
  });

  test('playlist summary parses id and name', () {
    final PlaylistSummary playlist = PlaylistSummary.fromJson(<String, dynamic>{
      'id': 7,
      'name': 'Favorites',
    });

    expect(playlist.id, 7);
    expect(playlist.name, 'Favorites');
  });

  test('catalog item can be created from playlist summary', () {
    const PlaylistSummary playlist = PlaylistSummary(
      id: 4,
      name: 'Watch later',
    );

    final CatalogItem item = CatalogItem.fromPlaylist(
      playlist,
      description: 'Created just now',
    );

    expect(item.id, 4);
    expect(item.title, 'Watch later');
    expect(item.description, 'Created just now');
  });
}
