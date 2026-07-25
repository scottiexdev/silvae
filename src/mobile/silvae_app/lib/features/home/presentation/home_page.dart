import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Brand(),
                  const Spacer(),
                  Text(
                    'Il lavoro sul campo,\nfinalmente in ordine.',
                    style: textTheme.displayMedium?.copyWith(
                      color: const Color(0xFF183A29),
                      fontWeight: FontWeight.w700,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Cantieri, rapportini e squadre in un’unica app, '
                    'anche quando la connessione non c’è.',
                    style: textTheme.titleLarge?.copyWith(
                      color: const Color(0xFF4C6356),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.arrow_forward),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('Inizia'),
                    ),
                  ),
                  const Spacer(flex: 2),
                  const Text(
                    'Prima fondazione applicativa',
                    style: TextStyle(color: Color(0xFF718078)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.forest, color: Color(0xFF246B45), size: 32),
        SizedBox(width: 10),
        Text(
          'Silvae',
          style: TextStyle(
            color: Color(0xFF183A29),
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
