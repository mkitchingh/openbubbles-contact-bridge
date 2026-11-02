import 'dart:io';

import 'package:openbubbles_contact_bridge/src/carddav_client.dart';
import 'package:test/test.dart';

void main() {
  test('discovers Google address book and fetches vCards through HTTPS', () async {
    final requests = <String>[];
    Future<CardDavTransportResponse> transport(
      String method,
      Uri uri,
      String? body,
      Map<String, String> headers,
    ) async {
      requests.add('$method ${uri.path}');
      expect(uri.scheme, 'https');
      expect(headers[HttpHeaders.authorizationHeader], 'Bearer private-token');
      if (uri.path == '/.well-known/carddav') {
        return const CardDavTransportResponse(
          statusCode: 301,
          headers: <String, String>{
            'location': '/carddav/v1/principals/private-user',
          },
          body: '',
        );
      }
      if (uri.path == '/carddav/v1/principals/private-user') {
        return CardDavTransportResponse(
          statusCode: 207,
          headers: const <String, String>{},
          body: _multistatus(
            '<d:response><d:propstat><d:prop>'
            '<card:addressbook-home-set><d:href>/carddav/v1/principals/private-user/lists</d:href></card:addressbook-home-set>'
            '</d:prop></d:propstat></d:response>',
          ),
        );
      }
      if (uri.path == '/carddav/v1/principals/private-user/lists') {
        return CardDavTransportResponse(
          statusCode: 207,
          headers: const <String, String>{},
          body: _multistatus(
            '<d:response><d:href>/carddav/v1/principals/private-user/lists/default</d:href>'
            '<d:propstat><d:prop><d:resourcetype><d:collection/><card:addressbook/></d:resourcetype>'
            '</d:prop></d:propstat></d:response>',
          ),
        );
      }
      if (uri.path == '/carddav/v1/principals/private-user/lists/default') {
        return CardDavTransportResponse(
          statusCode: 207,
          headers: const <String, String>{},
          body: _multistatus(
            '<d:response><d:href>${uri.path}</d:href><d:propstat><d:prop>'
            '<d:resourcetype><d:collection/></d:resourcetype></d:prop></d:propstat></d:response>'
            '<d:response><d:href>${uri.path}/one</d:href><d:propstat><d:prop>'
            '<d:getetag>one</d:getetag></d:prop></d:propstat></d:response>'
            '<d:response><d:href>${uri.path}/two</d:href><d:propstat><d:prop>'
            '<d:getetag>two</d:getetag></d:prop></d:propstat></d:response>',
          ),
        );
      }
      if (uri.path.endsWith('/one') || uri.path.endsWith('/two')) {
        final id = uri.path.endsWith('/one') ? 'one' : 'two';
        return CardDavTransportResponse(
          statusCode: 200,
          headers: const <String, String>{},
          body: 'BEGIN:VCARD\nVERSION:3.0\nUID:$id\nFN:Private $id\nEND:VCARD\n',
        );
      }
      throw StateError('Unexpected request: $method $uri');
    }

    final result = await GoogleCardDavClient(
      accessToken: 'private-token',
      transport: transport,
      maxConcurrentDownloads: 2,
    ).fetchAll();
    expect(result.addressBookCount, 1);
    expect(result.vcardCount, 2);
    expect(result.contacts.map((contact) => contact.stableId),
        containsAll(<String>['carddav-uid:one', 'carddav-uid:two']));
    expect(requests.where((request) => request.startsWith('GET ')).length, 2);
  });

  test('refuses a redirect away from Google', () async {
    final client = GoogleCardDavClient(
      accessToken: 'private-token',
      transport: (method, uri, body, headers) async =>
          const CardDavTransportResponse(
        statusCode: 302,
        headers: <String, String>{'location': 'https://evil.example/steal'},
        body: '',
      ),
    );
    await expectLater(client.fetchAll(), throwsStateError);
  });

  test('translates a missing CardDAV grant without exposing response data', () async {
    final client = GoogleCardDavClient(
      accessToken: 'private-token',
      transport: (method, uri, body, headers) async =>
          const CardDavTransportResponse(
        statusCode: 403,
        headers: <String, String>{
          'www-authenticate': 'Bearer error="insufficient_scope"',
        },
        body: '{"private":"must-not-leak"}',
      ),
    );
    await expectLater(
      client.fetchAll(),
      throwsA(isA<StateError>().having(
        (error) => error.message,
        'message',
        allOf(contains('CardDAV scope'), isNot(contains('must-not-leak'))),
      )),
    );
  });

  test('translates a disabled CardDAV API response without leaking data', () async {
    final client = GoogleCardDavClient(
      accessToken: 'private-token',
      transport: (method, uri, body, headers) async =>
          const CardDavTransportResponse(
        statusCode: 403,
        headers: <String, String>{},
        body: '{"error":{"status":"PERMISSION_DENIED","details":['
            '{"reason":"SERVICE_DISABLED","metadata":{'
            '"service":"carddav.googleapis.com",'
            '"consumer":"projects/private-project-number"}}],'
            '"private":"must-not-leak"}}',
      ),
    );
    await expectLater(
      client.fetchAll(),
      throwsA(isA<StateError>().having(
        (error) => error.message,
        'message',
        allOf(
          contains('carddav.googleapis.com'),
          contains('Google Contacts CardDAV API'),
          isNot(contains('must-not-leak')),
          isNot(contains('private-project-number')),
        ),
      )),
    );
  });
}

String _multistatus(String body) =>
    '<?xml version="1.0" encoding="utf-8"?>'
    '<d:multistatus xmlns:d="DAV:" '
    'xmlns:card="urn:ietf:params:xml:ns:carddav">$body</d:multistatus>';
