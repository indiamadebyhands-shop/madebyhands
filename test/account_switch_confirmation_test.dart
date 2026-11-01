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
    await tester.tap(find.text('Yes, switch'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
