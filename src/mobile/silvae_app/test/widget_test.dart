import 'package:flutter_test/flutter_test.dart';
import 'package:silvae_app/app/silvae_app.dart';

void main() {
  testWidgets('shows safe configuration instructions without secrets', (
    tester,
  ) async {
    await tester.pumpWidget(const SilvaeApp());
    await tester.pump();

    expect(find.text('Silvae'), findsOneWidget);
    expect(find.textContaining('Configura Supabase'), findsOneWidget);
  });
}
