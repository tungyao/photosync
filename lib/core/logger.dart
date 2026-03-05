import 'dart:developer' as developer;

class AppLogger {
  const AppLogger._();

  static void info(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(message, name: 'PhotoSync', error: error, stackTrace: stackTrace);
  }
}
