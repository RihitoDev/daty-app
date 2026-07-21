import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_dates/shared/widgets/contract_rule_tile.dart';
import 'package:magic_dates/shared/widgets/pressable_scale.dart';

void main() {
  testWidgets('ContractRuleTile alterna su estado al tocarlo', (tester) async {
    var isChecked = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => ContractRuleTile(
              value: isChecked,
              text: 'Aceptar el compromiso',
              accent: Colors.purple,
              textColor: Colors.black,
              onChanged: (value) => setState(() => isChecked = value),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Aceptar el compromiso'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNothing);

    await tester.tap(find.text('Aceptar el compromiso'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(isChecked, isTrue);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('PressableScale ejecuta la acción configurada', (tester) async {
    var tapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PressableScale(
            semanticsLabel: 'Abrir aventura',
            onTap: () => tapCount++,
            child: const Text('Aventura'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Aventura'));
    await tester.pump(const Duration(milliseconds: 150));

    expect(tapCount, 1);
  });
}
