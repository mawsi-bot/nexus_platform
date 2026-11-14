import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/data/api_client.dart';
import 'package:nexus/presentation/theme.dart';
import 'package:nexus/presentation/widgets/states.dart';

Widget wrap(Widget child) =>
    MaterialApp(theme: buildTheme(Brightness.light), home: Scaffold(body: child));

void main() {
  group('friendlyError', () {
    test('maps every failure family to customer copy', () {
      expect(friendlyError(TimeoutException('t')), contains('slow'));
      expect(friendlyError(const SocketException('down')), contains('offline'));
      expect(friendlyError(ApiException(401, 'LOGIN')), contains('sign in'));
      expect(friendlyError(ApiException(429, 'RATE')), contains('Too many'));
      expect(friendlyError(FormatException('unmapped route')), contains('not available'));
      expect(friendlyError(Exception('bad format')), contains('could not read'));
      expect(friendlyError(Exception('???')), contains('went wrong'));
    });

    test('never echoes the raw error', () {
      const raw = 'Unsupported operation: Platform._operatingSystem';
      expect(friendlyError(Exception(raw)), isNot(contains('Unsupported')));
    });
  });

  testWidgets('EmptyState renders copy and fires its CTA', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      wrap(
        EmptyState(
          title: 'Nothing here',
          message: 'Come back later',
          ctaLabel: 'Retry',
          onCta: () => tapped++,
        ),
      ),
    );
    expect(find.text('Nothing here'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(tapped, 1);
  });

  testWidgets('EmptyState without a CTA shows no button', (tester) async {
    await tester.pumpWidget(
      const MaterialAppWrapper(child: EmptyState(title: 't', message: 'm')),
    );
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('ErrorState uses friendly copy and retries', (tester) async {
    var retried = 0;
    await tester.pumpWidget(
      wrap(
        ErrorState(
          error: const SocketException('down'),
          onRetry: () => retried++,
        ),
      ),
    );
    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.textContaining('offline'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retried, 1);
  });

  testWidgets('ErrorState without a retry hides the CTA', (tester) async {
    await tester.pumpWidget(
      wrap(ErrorState(error: Exception('x'))),
    );
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('skeletons animate without settling', (tester) async {
    await tester.pumpWidget(
      wrap(const Column(children: [SkeletonCard(), SkeletonCard(media: false)])),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(Shimmer), findsNWidgets(2));
    expect(find.byType(SkeletonBox), findsWidgets);
  });

  testWidgets('Segmented reports the tapped segment', (tester) async {
    final picked = <String>[];
    await tester.pumpWidget(
      wrap(
        Segmented(
          items: const ['For You', 'Nearby'],
          value: 'foryou',
          onSelect: picked.add,
        ),
      ),
    );
    await tester.tap(find.text('Nearby'));
    await tester.pumpAndSettle();
    expect(picked, ['nearby']);
  });

  testWidgets('Segmented can size to its content', (tester) async {
    await tester.pumpWidget(
      wrap(
        Segmented(
          items: const ['A', 'B'],
          value: 'a',
          expand: false,
          onSelect: (_) {},
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('MetaPill and VerifiedBadge render their labels', (tester) async {
    await tester.pumpWidget(
      wrap(
        const Row(
          children: [
            MetaPill(label: '2.4 km'),
            MetaPill(label: 'Bahan', icon: Icons.map),
            VerifiedBadge(),
          ],
        ),
      ),
    );
    expect(find.text('2.4 km'), findsOneWidget);
    expect(find.text('Bahan'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });
}

/// Small helper so the CTA-less case does not depend on the scaffold wrapper.
class MaterialAppWrapper extends StatelessWidget {
  const MaterialAppWrapper({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: buildTheme(Brightness.light),
    home: Scaffold(body: child),
  );
}
