import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/core/config/server_connection.dart';
import 'package:localtube_flutter/features/server_connection/presentation/server_connection_page.dart';

void main() {
  testWidgets(
      'invalid address is rejected and valid settings require explicit save',
      (tester) async {
    ServerConnection? saved;
    await tester.pumpWidget(
        MaterialApp(home: ServerConnectionPage(onSave: (value) async {
      saved = value;
    })));
    await tester.tap(find.text('Сохранить и подключиться'));
    await tester.pump();
    expect(find.textContaining('Укажите адрес API'), findsOneWidget);
    expect(saved, isNull);
    await tester.enterText(
        find.byType(TextField).first, 'https://media.example:9999/');
    expect(saved, isNull);
    await tester.tap(find.text('Сохранить и подключиться'));
    await tester.pump();
    expect(saved!.apiBaseUrl, 'https://media.example:9999');
    expect(saved!.localApiHost, isEmpty);
    expect(find.text('Сохранить и подключиться'), findsOneWidget);
  });

  testWidgets(
      'existing connection is shown for review and storage errors remain editable',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: ServerConnectionPage(
      initial: ServerConnection(
          apiBaseUrl: 'https://media.example',
          localApiHost: '192.0.2.10',
          localApiPort: 55),
      onSave: (_) async => throw StateError('storage unavailable'),
    )));
    expect(find.text('https://media.example'), findsOneWidget);
    await tester.tap(find.text('Сохранить и подключиться'));
    await tester.pump();
    expect(find.textContaining('Не удалось прочитать или сохранить'),
        findsOneWidget);
    expect(find.text('Сохранить и подключиться'), findsOneWidget);
  });
}
