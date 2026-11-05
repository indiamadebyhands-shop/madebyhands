import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madebyhands/features/auth/presentation/widgets/account_switch_confirmation.dart';

void main() {
  testWidgets('account switch requires an explicit confirmation', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await confirmAccountSwitch(
                context,
                targetSide: 'creator',
              );
            },
            child: const Text('Switch accounts'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Switch accounts'));
    await tester.pumpAndSettle();
    expect(
      find.text('Are you sure you want to switch to the creator side?'),
      findsOneWidget,
    );

    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();
    expect(result, isFalse);

    await tester.tap(find.text('Switch accounts'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes switch'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('new role uses account creation confirmation copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => confirmAccountSwitch(
              context,
              targetSide: 'creator',
              isCreatingAccount: true,
            ),
            child: const Text('Make a creator account'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Make a creator account'));
    await tester.pumpAndSettle();
    expect(find.text('Create creator account?'), findsOneWidget);
    expect(
      find.text(
        'This will add a creator account to the same email address. Continue?',
      ),
      findsOneWidget,
    );
    expect(find.text('Yes create'), findsOneWidget);
  });

  testWidgets('panel color is applied to both dialog buttons', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 690));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const maroon = Color(0xFF8B261D);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => confirmAccountSwitch(
              context,
              targetSide: 'creator',
              confirmColor: maroon,
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    final title = tester.widget<Text>(find.text('Switch accounts?'));
    final noButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'No'),
    );
    final yesButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Yes switch'),
    );
    expect(dialog.backgroundColor, const Color(0xFFFFF3E2));
    expect(dialog.shape, isA<RoundedRectangleBorder>());
    expect(title.style?.color, maroon);
    expect(title.style?.fontSize, 18);
    expect(title.style?.fontWeight, FontWeight.w900);
    expect(noButton.style?.foregroundColor?.resolve({}), maroon);
    expect(noButton.style?.side?.resolve({})?.color, maroon);
    expect(noButton.style?.shape?.resolve({}), isA<StadiumBorder>());
    expect(noButton.style?.minimumSize?.resolve({}), const Size(0, 40));
    expect(yesButton.style?.backgroundColor?.resolve({}), maroon);
    expect(yesButton.style?.foregroundColor?.resolve({}), Colors.white);
    expect(yesButton.style?.shape?.resolve({}), isA<StadiumBorder>());
    expect(yesButton.style?.minimumSize?.resolve({}), const Size(0, 40));
    expect(
      tester.getSize(find.widgetWithText(OutlinedButton, 'No')).width,
      tester.getSize(find.widgetWithText(FilledButton, 'Yes switch')).width,
    );
  });
}
