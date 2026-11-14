import 'package:sentry_flutter/sentry_flutter.dart';

/// Crash + error reporting (§9). Configured by --dart-define so a build without
/// a DSN simply runs without telemetry instead of failing.
const String sentryDsn = String.fromEnvironment('SENTRY_DSN');
const String nexusRelease = 'nexus@1.4.2+5';

/// Connectivity failures are expected offline behaviour, not crashes.
bool isConnectivityNoise(String text) =>
    text.contains('RequestCancelled') ||
    text.contains('SocketException') ||
    text.contains('ClientException');

/// Telemetry configuration, separate from [SentryFlutter.init] so the options
/// can be asserted without opening a transport.
SentryOptions sentryOptions({
  required String dsn,
  String environment = 'production',
}) => SentryOptions()
  ..dsn = dsn
  ..release = nexusRelease
  ..environment = environment
  ..tracesSampleRate = 0.1
  ..sendDefaultPii = false
  ..beforeSend = (event, hint) {
    final text = event.exceptions?.map((e) => '${e.value}').join(' ') ?? '';
    return isConnectivityNoise(text) ? null : event;
  };

Future<void> startTelemetry(Future<void> Function() appRunner) async {
  if (sentryDsn.isEmpty) {
    await appRunner();
    return;
  }
  await SentryFlutter.init(
    (_) => sentryOptions(
      dsn: sentryDsn,
      environment: const String.fromEnvironment(
        'NEXUS_ENV',
        defaultValue: 'production',
      ),
    ),
    appRunner: appRunner,
  );
}
