import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localtube_flutter/features/player/presentation/player_navigation_result.dart';

void main() {
  testWidgets('shows post-navigation success snackbar for player delete result',
      (
    WidgetTester tester,
  ) async {
    late BuildContext capturedContext;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    showPlayerNavigationResultSnackBar(
      capturedContext,
      PlayerNavigationResult.deletedEverywhere,
    );
    await tester.pump();

    expect(find.text('Файл удалён отовсюду'), findsOneWidget);
  });
}
