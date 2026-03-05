import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photosync/app.dart';

void main() {
  testWidgets('app renders home scaffold', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: PhotoSyncApp()));
    await tester.pumpAndSettle();

    expect(find.byType(ProviderScope), findsOneWidget);
    expect(find.byType(PhotoSyncApp), findsOneWidget);
  });
}
