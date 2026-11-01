import 'package:openbubbles_contact_bridge/src/google_oauth.dart';
import 'package:test/test.dart';

void main() {
  test('accepts Google downloaded desktop-client JSON shape', () {
    final config = GoogleOAuthClientConfig.fromJson(<String, Object?>{
      'installed': <String, Object?>{
        'client_id': '123.apps.googleusercontent.com',
        'client_secret': 'not-logged',
      },
    });
    expect(config.clientId, '123.apps.googleusercontent.com');
    expect(config.clientSecret, 'not-logged');
  });

  test('rejects a non-Google client identifier', () {
    expect(
      () => GoogleOAuthClientConfig.fromJson(<String, Object?>{
        'client_id': 'not-google.example',
      }),
      throwsFormatException,
    );
  });
}
