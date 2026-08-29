import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silvae_app/app/theme.dart';
import 'package:silvae_app/app/ui.dart';
import 'package:silvae_app/features/authentication/presentation/login_page.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(theme: silvaeTheme(Brightness.light), home: child),
);

void main() {
  // Una scheda dentro una lista non conosce ancora la propria altezza: la
  // banda colorata di fianco ha già rotto tutto una volta, chiedendo di
  // essere alta infinito.
  testWidgets('SurfaceCard con la banda si dispone in altezza libera', (
    tester,
  ) async {
    await _pump(
      tester,
      const Scaffold(
        body: PageBody(
          children: [
            SurfaceCard(accent: Color(0xFF7A5210), child: Text('Conflitto')),
            gapCards,
            SurfaceCard(child: Text('Normale')),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Conflitto'), findsOneWidget);
  });

  testWidgets('gli stati vuoti e di errore si disegnano nel tema', (
    tester,
  ) async {
    await _pump(
      tester,
      const Scaffold(
        body: PageBody(
          children: [
            EmptyState(
              icon: Icons.description_outlined,
              title: 'Niente qui',
              message: 'Il primo si crea dal pulsante in basso.',
            ),
            gapSections,
            ErrorState(title: 'Non leggibile', detail: 'connessione rifiutata'),
            gapSections,
            LoadingList(rows: 2),
            gapSections,
            StatusPill(label: 'Bozza', tone: Tone.neutral),
            Facts([(Icons.event_outlined, '29/08/2026')]),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Niente qui'), findsOneWidget);
    expect(find.text('connessione rifiutata'), findsOneWidget);
  });

  testWidgets('l\'accesso rifiuta i campi vuoti senza chiamare la rete', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginPage())),
    );

    await tester.tap(find.text('Accedi'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Inserisci email e password.'), findsOneWidget);
  });
}
