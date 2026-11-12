import 'dart:async';
import 'dart:io';

/// Converts transport/parser failures into safe, actionable UI messages.
/// Raw exception text is intentionally not exposed because URLs can contain
/// provider credentials.
abstract final class AppErrorMapper {
  static String toUserMessage(
    Object error, {
    required String fallback,
  }) {
    if (error is TimeoutException) {
      return 'انتهت مهلة الاتصال. تحقق من الإنترنت ثم أعد المحاولة.';
    }
    if (error is SocketException || error is HandshakeException) {
      return 'تعذر الاتصال بالخادم. تحقق من الشبكة أو إعدادات الاتصال.';
    }
    if (error is FormatException) {
      return 'وصلت بيانات غير صالحة من الخادم. حاول مجدداً لاحقاً.';
    }
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    if (message.isNotEmpty &&
        message.length <= 120 &&
        !message.contains('://') &&
        !message.contains('password=') &&
        !message.contains('username=')) {
      return message;
    }
    return fallback;
  }
}
