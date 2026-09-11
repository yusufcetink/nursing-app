import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

extension VisibleControls on WidgetTester {
  /// Settle layout, then center controls so fixed navigation cannot cover them.
  Future<void> reveal(Finder finder, double delta) async {
    await scrollUntilVisible(
      finder,
      delta,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 60,
    );
    await pumpAndSettle();
    await Scrollable.ensureVisible(element(finder), alignment: .5);
    await pumpAndSettle();
  }
}
