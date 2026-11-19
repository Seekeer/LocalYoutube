import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:localtube_flutter/app/router/app_routes.dart';
import 'package:localtube_flutter/features/notes/data/notes_repository.dart';
import 'package:localtube_flutter/features/notes/domain/notes_models.dart';
import 'package:localtube_flutter/features/notes/presentation/notes_page.dart';

NotesShelfData shelf(int listed, {int? count}) => NotesShelfData(
      items: List<NotesShelfItem>.generate(
        listed,
        (int i) => NotesShelfItem(
          videoId: i + 1,
          title: 'Видео ${i + 1}',
          seriesName: 'Канал',
          needsClassification: true,
          hasDrafts: i == 0,
        ),
      ),
      count: count,
    );

Future<List<String>> pumpNotesPage(
  WidgetTester tester,
  NotesShelfData data,
) async {
  final List<String> opened = <String>[];
  final GoRouter router = GoRouter(
    initialLocation: AppRoutes.notes,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.notes,
        builder: (_, __) => const NotesPage(),
      ),
      GoRoute(
        path: '${AppRoutes.player}/:videoId',
        builder: (_, GoRouterState state) {
          opened.add(state.pathParameters['videoId']!);
          return const Scaffold(body: Text('player'));
        },
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        notesShelfProvider.overrideWith((Ref ref) async => data),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return opened;
}

void main() {
  testWidgets('lists the queue with the server count and what is left out',
      (WidgetTester tester) async {
    final List<String> opened = await pumpNotesPage(tester, shelf(2, count: 140));

    expect(find.text('Заметки · 140'), findsOneWidget);
    expect(find.text('Видео 1'), findsOneWidget);
    expect(find.text('Видео 2'), findsOneWidget);
    expect(find.text('Нужна тема'), findsNWidgets(2));
    expect(find.text('Черновик'), findsOneWidget);
    expect(find.text('Ещё 138 появятся, когда разберёте эти'), findsOneWidget);

    await tester.tap(find.text('Видео 2'));
    await tester.pumpAndSettle();
    expect(opened, <String>['2']);
  });

  testWidgets('a mouse wheel scrolls the list', (WidgetTester tester) async {
    await pumpNotesPage(tester, shelf(40));
    expect(find.text('Видео 40'), findsNothing);

    final TestPointer mouse = TestPointer(1, PointerDeviceKind.mouse);
    final Offset over = tester.getCenter(find.byKey(const Key('notes-list')));
    await tester.sendEventToBinding(mouse.hover(over));
    for (int i = 0; i < 20; i++) {
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, 400)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('Видео 40'), findsOneWidget);
    expect(find.text('Видео 1'), findsNothing);
  });

  testWidgets('says so when there is nothing to sort',
      (WidgetTester tester) async {
    await pumpNotesPage(tester, shelf(0));

    expect(find.text('Заметки'), findsOneWidget);
    expect(find.text('Разбирать нечего'), findsOneWidget);
    expect(find.byKey(const Key('notes-more')), findsNothing);
  });
}
