import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:agency_management/main.dart';

void main() {
  testWidgets('App boots without throwing', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AgencyManagementApp()));
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
