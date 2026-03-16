import 'package:flutter/material.dart';

class NoCompanyPage extends StatelessWidget {
  const NoCompanyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.business_outlined, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Henüz bir firmaya bağlı değilsiniz',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Firma oluşturma / davet kodu ile katılma akışı bu adımda placeholder olarak bırakıldı.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: null,
              child: const Text('Firma oluştur (placeholder)'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: null,
              child: const Text('Davet kodu ile katıl (placeholder)'),
            ),
          ],
        ),
      ),
    );
  }
}
