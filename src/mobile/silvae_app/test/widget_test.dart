import 'package:flutter_test/flutter_test.dart';
import 'package:silvae_app/app/silvae_app.dart';

void main() {
  testWidgets('renders the Silvae landing page', (tester) async {
    await tester.pumpWidget(const SilvaeApp());
    await tester.pump();

    expect(find.text('Silvae'), findsOneWidget);
    expect(
      find.text('Il lavoro sul campo,\nfinalmente in ordine.'),
      findsOneWidget,
    );
    expect(find.text('Inizia'), findsOneWidget);
  });
}
