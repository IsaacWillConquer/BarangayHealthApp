import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:barangay_health_portal/theme.dart';

void main() {
  testWidgets('renders the resident portal brand mark', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.build(), home: const _BrandOnly()),
    );

    expect(find.text('Barangay Health'), findsOneWidget);
    expect(find.text('Resident Portal'), findsOneWidget);
  });
}

class _BrandOnly extends StatelessWidget {
  const _BrandOnly();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [Text('Barangay Health'), Text('Resident Portal')],
        ),
      ),
    );
  }
}
