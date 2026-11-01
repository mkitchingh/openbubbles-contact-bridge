import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

class GoogleOAuthClientConfig {
  const GoogleOAuthClientConfig({required this.clientId, this.clientSecret});

  final String clientId;
  final String? clientSecret;

  factory GoogleOAuthClientConfig.fromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException('OAuth configuration must be a JSON object.');
    }
    final root = Map<String, dynamic>.from(value);
    final installed = root['installed'];
    final source = installed is Map
        ? Map<String, dynamic>.from(installed)
        : root;
    final clientId = source['client_id'];
    final clientSecret = source['client_secret'];
    if (clientId is! String ||
        clientId.isEmpty ||
        !clientId.endsWith('.apps.googleusercontent.com')) {
      throw const FormatException(
          'OAuth configuration has no valid desktop client_id.');
    }
    if (clientSecret != null && clientSecret is! String) {
      throw const FormatException('OAuth client_secret must be a string.');
    }
    return GoogleOAuthClientConfig(
      clientId: clientId,
      clientSecret:
          clientSecret is String && clientSecret.isNotEmpty ? clientSecret : null,
    );
  }
}

typedef BrowserLauncher = Future<void> Function(Uri uri);

class GoogleDesktopOAuth {
  GoogleDesktopOAuth({
    required this.config,
    BrowserLauncher? browserLauncher,
    HttpClient? httpClient,
  })  : _browserLauncher = browserLauncher ?? _launchBrowser,
        _http = httpClient ?? HttpClient();

  final GoogleOAuthClientConfig config;
  final BrowserLauncher _browserLauncher;
  final HttpClient _http;

  static const cardDavScope = 'https://www.googleapis.com/auth/carddav';

  Future<String> authorize() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final redirectUri = Uri.parse(
        'http://127.0.0.1:${server.port}/oauth/callback');
    final state = _randomUrlSafe(32);
    final verifier = _randomUrlSafe(64);
    final challenge = base64Url
        .encode(sha256.convert(ascii.encode(verifier)).bytes)
        .replaceAll('=', '');
    final authorization = Uri.https(
      'accounts.google.com',
      '/o/oauth2/v2/auth',
      <String, String>{
        'client_id': config.clientId,
        'redirect_uri': redirectUri.toString(),
        'response_type': 'code',
        'scope': cardDavScope,
        'state': state,
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
        'access_type': 'online',
      },
    );

    final callback = Completer<Uri>();
    late final StreamSubscription<HttpRequest> subscription;
    subscription = server.listen((request) async {
      if (request.uri.path != '/oauth/callback') {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }
      request.response.headers.contentType = ContentType.html;
      request.response.write(
          '<!doctype html><title>OpenBubbles Contact Bridge</title>'
          '<h1>Authorization received</h1>'
          '<p>You may close this browser tab and return to the bridge.</p>');
      await request.response.close();
      if (!callback.isCompleted) callback.complete(request.uri);
    });

    try {
      await _browserLauncher(authorization);
      final responseUri = await callback.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () => throw TimeoutException(
            'Google authorization was not completed within five minutes.'),
      );
      if (responseUri.queryParameters['state'] != state) {
        throw StateError('Google authorization state verification failed.');
      }
      final error = responseUri.queryParameters['error'];
      if (error != null) {
        throw StateError('Google authorization was not granted ($error).');
      }
      final code = responseUri.queryParameters['code'];
      if (code == null || code.isEmpty) {
        throw StateError('Google authorization returned no code.');
      }
      return _exchangeCode(code, verifier, redirectUri);
    } finally {
      await subscription.cancel();
      await server.close(force: true);
    }
  }

  Future<String> _exchangeCode(
      String code, String verifier, Uri redirectUri) async {
    final parameters = <String, String>{
      'client_id': config.clientId,
      if (config.clientSecret != null) 'client_secret': config.clientSecret!,
      'code': code,
      'code_verifier': verifier,
      'redirect_uri': redirectUri.toString(),
      'grant_type': 'authorization_code',
    };
    final request = await _http.postUrl(
        Uri.parse('https://oauth2.googleapis.com/token'));
    request.headers.contentType =
        ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
    request.write(parameters.entries
        .map((entry) =>
            '${Uri.encodeQueryComponent(entry.key)}='
            '${Uri.encodeQueryComponent(entry.value)}')
        .join('&'));
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode != HttpStatus.ok) {
      throw StateError(
          'Google token exchange failed with HTTP ${response.statusCode}.');
    }
    final decoded = jsonDecode(body);
    final token = decoded is Map<String, dynamic> ? decoded['access_token'] : null;
    if (token is! String || token.isEmpty) {
      throw StateError('Google token exchange returned no access token.');
    }
    return token;
  }

  static Future<void> _launchBrowser(Uri uri) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('Google browser authorization requires Windows.');
    }
    final process = await Process.start(
      'rundll32.exe',
      <String>['url.dll,FileProtocolHandler', uri.toString()],
      mode: ProcessStartMode.detached,
    );
    if (process.pid <= 0) throw StateError('Could not open the web browser.');
  }
}

String _randomUrlSafe(int bytes) {
  final random = Random.secure();
  final value = List<int>.generate(bytes, (_) => random.nextInt(256));
  return base64Url.encode(value).replaceAll('=', '');
}
