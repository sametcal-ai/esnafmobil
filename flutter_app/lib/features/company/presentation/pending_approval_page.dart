import 'package:flutter/material.dart';

class PendingApprovalPage extends StatelessWidget {
  const PendingApprovalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_empty, size: 48),
            SizedBox(height: 16),
            Text(
              'Üyelik onayı bekleniyor',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Firma yöneticisi üyeliğinizi onayladıktan sonra uygulamayı kullanabilirsiniz.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
