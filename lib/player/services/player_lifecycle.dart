import 'dart:async';

import 'package:media_kit/media_kit.dart';

/// Owns the final release operation for media_kit players.
///
/// Screens must cancel their stream subscriptions before calling this helper.
abstract final class PlayerLifecycle {
  static void dispose(Player? player) {
    if (player == null) return;
    unawaited(_disposeSafely(player));
  }

  static Future<void> _disposeSafely(Player player) async {
    try {
      await player.dispose();
    } catch (_) {
      // Disposal is best-effort during route teardown; never crash the UI.
    }
  }
}
