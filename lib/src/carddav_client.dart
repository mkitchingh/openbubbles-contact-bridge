import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:xml/xml.dart';

import 'vcard_parser.dart';

class CardDavFetchResult {
  const CardDavFetchResult({
    required this.addressBookCount,
    required this.vcardCount,
    required this.contacts,
  });

  final int addressBookCount;
  final int vcardCount;
  final List<FetchedContact> contacts;
}

class CardDavTransportResponse {
  const CardDavTransportResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
  });
  final int statusCode;
  final Map<String, String> headers;
  final String body;
}

typedef CardDavTransport = Future<CardDavTransportResponse> Function(
  String method,
  Uri uri,
  String? body,
  Map<String, String> headers,
);

class GoogleCardDavClient {
  GoogleCardDavClient({
    required this.accessToken,
    HttpClient? httpClient,
    CardDavTransport? transport,
    this.maxConcurrentDownloads = 6,
  })  : _http = httpClient ?? HttpClient(),
        _transport = transport;

  final String accessToken;
  final HttpClient _http;
  final CardDavTransport? _transport;
  final int maxConcurrentDownloads;

  static final Uri discoveryUri =
      Uri.parse('https://www.googleapis.com/.well-known/carddav');

  Future<CardDavFetchResult> fetchAll() async {
    final home = await _discoverHome(discoveryUri);
    final books = await _listAddressBooks(home);
    final cards = <({Uri href, String vcard})>[];
    for (final book in books) {
      final hrefs = await _listVCardHrefs(book);
      cards.addAll(await _mapConcurrent(
        hrefs,
        maxConcurrentDownloads,
        (href) async => (href: href, vcard: await _getVCard(href)),
      ));
    }
    final contacts = cards
        .map((card) => parseVCard(card.vcard, card.href))
        .toList(growable: false);
    return CardDavFetchResult(
      addressBookCount: books.length,
      vcardCount: cards.length,
      contacts: contacts,
    );
  }

  Future<Uri> _discoverHome(Uri initial) async {
    final home = await _tryHome(initial);
    if (home != null) return home;
    final principalBody = _propfind(<String>[
      '<d:current-user-principal/>',
      '<d:principal-URL/>',
    ]);
    final principalResponse = await _request(
      'PROPFIND',
      initial,
      body: principalBody,
      headers: const <String, String>{'Depth': '0'},
    );
    final document = XmlDocument.parse(principalResponse.body);
    final principal = _firstHref(document, 'current-user-principal') ??
        _firstHref(document, 'principal-URL');
    if (principal == null) {
      throw StateError('Google CardDAV did not return a user principal.');
    }
    final discovered = await _tryHome(principalResponse.url.resolve(principal));
    if (discovered == null) {
      throw StateError('Google CardDAV did not return an address-book home.');
    }
    return discovered;
  }

  Future<Uri?> _tryHome(Uri uri) async {
    final response = await _request(
      'PROPFIND',
      uri,
      body: _propfind(const <String>['<card:addressbook-home-set/>']),
      headers: const <String, String>{'Depth': '0'},
    );
    final document = XmlDocument.parse(response.body);
    final href = _firstHref(document, 'addressbook-home-set');
    return href == null ? null : response.url.resolve(href);
  }

  Future<List<Uri>> _listAddressBooks(Uri home) async {
    final response = await _request(
      'PROPFIND',
      home,
      body: _propfind(const <String>[
        '<d:resourcetype/>',
        '<d:displayname/>',
      ]),
      headers: const <String, String>{'Depth': '1'},
    );
    final document = XmlDocument.parse(response.body);
    final books = <Uri>[];
    for (final item in document.findAllElements('response', namespace: 'DAV:')) {
      final isAddressBook = item
          .findAllElements('addressbook',
              namespace: 'urn:ietf:params:xml:ns:carddav')
          .isNotEmpty;
      if (!isAddressBook) continue;
      final href = item
          .findAllElements('href', namespace: 'DAV:')
          .map((element) => element.innerText.trim())
          .where((value) => value.isNotEmpty)
          .firstOrNull;
      if (href != null) books.add(response.url.resolve(href));
    }
    if (books.isEmpty) {
      throw StateError('Google CardDAV returned no address books.');
    }
    return books;
  }

  Future<List<Uri>> _listVCardHrefs(Uri book) async {
    final response = await _request(
      'PROPFIND',
      book,
      body: _propfind(const <String>['<d:getetag/>', '<d:resourcetype/>']),
      headers: const <String, String>{'Depth': '1'},
    );
    final document = XmlDocument.parse(response.body);
    final hrefs = <Uri>[];
    for (final item in document.findAllElements('response', namespace: 'DAV:')) {
      final isCollection = item
          .findAllElements('collection', namespace: 'DAV:')
          .isNotEmpty;
      if (isCollection) continue;
      final statuses = item
          .findAllElements('status', namespace: 'DAV:')
          .map((element) => element.innerText);
      if (statuses.any((value) =>
          value.contains(' 404 ') || value.contains(' 410 '))) {
        continue;
      }
      final href = item
          .findAllElements('href', namespace: 'DAV:')
          .map((element) => element.innerText.trim())
          .where((value) => value.isNotEmpty)
          .firstOrNull;
      if (href != null) hrefs.add(response.url.resolve(href));
    }
    return hrefs;
  }

  Future<String> _getVCard(Uri href) async {
    final response = await _request(
      'GET',
      href,
      headers: const <String, String>{
        'Accept': 'text/vcard, text/x-vcard, text/plain',
      },
    );
    return response.body;
  }

  Future<_CardDavResponse> _request(
    String method,
    Uri uri, {
    String? body,
    Map<String, String> headers = const <String, String>{},
    int redirects = 0,
  }) async {
    if (uri.scheme != 'https') {
      throw StateError('CardDAV refused a non-HTTPS URI.');
    }
    final requestHeaders = <String, String>{
      HttpHeaders.authorizationHeader: 'Bearer $accessToken',
      HttpHeaders.userAgentHeader: 'OpenBubbles-Contact-Bridge/0.2',
      ...headers,
    };
    final response = _transport == null
        ? await _send(method, uri, body, requestHeaders)
        : await _transport(method, uri, body, requestHeaders);
    if (response.statusCode >= 300 && response.statusCode < 400) {
      if (redirects >= 5) {
        throw StateError('CardDAV returned too many redirects.');
      }
      final location = response.headers[HttpHeaders.locationHeader];
      if (location == null) throw StateError('CardDAV redirect had no location.');
      final next = uri.resolve(location);
      if (next.scheme != 'https' || next.host != 'www.googleapis.com') {
        throw StateError('CardDAV refused a redirect outside Google HTTPS.');
      }
      return _request(method, next,
          body: body, headers: headers, redirects: redirects + 1);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('CardDAV $method failed with HTTP ${response.statusCode}.');
    }
    return _CardDavResponse(url: uri, body: response.body);
  }

  Future<CardDavTransportResponse> _send(
    String method,
    Uri uri,
    String? body,
    Map<String, String> headers,
  ) async {
    final request = await _http.openUrl(method, uri);
    request.followRedirects = false;
    headers.forEach(request.headers.set);
    if (body != null) {
      request.headers.contentType = ContentType('application', 'xml',
          charset: 'utf-8');
      request.write(body);
    }
    final response = await request.close();
    final responseBody = await utf8.decoder.bind(response).join();
    final responseHeaders = <String, String>{};
    response.headers.forEach((name, values) {
      if (values.isNotEmpty) responseHeaders[name.toLowerCase()] = values.first;
    });
    return CardDavTransportResponse(
      statusCode: response.statusCode,
      headers: responseHeaders,
      body: responseBody,
    );
  }

  String _propfind(List<String> properties) =>
      '<?xml version="1.0" encoding="utf-8"?>'
      '<d:propfind xmlns:d="DAV:" '
      'xmlns:card="urn:ietf:params:xml:ns:carddav">'
      '<d:prop>${properties.join()}</d:prop></d:propfind>';

  String? _firstHref(XmlDocument document, String property) => document
      .findAllElements(property)
      .expand((element) => element.findAllElements('href', namespace: 'DAV:'))
      .map((element) => element.innerText.trim())
      .where((value) => value.isNotEmpty)
      .firstOrNull;
}

class _CardDavResponse {
  const _CardDavResponse({required this.url, required this.body});
  final Uri url;
  final String body;
}

Future<List<T>> _mapConcurrent<S, T>(
  List<S> values,
  int concurrency,
  Future<T> Function(S value) task,
) async {
  if (values.isEmpty) return <T>[];
  final results = List<T?>.filled(values.length, null);
  var next = 0;
  Future<void> worker() async {
    while (true) {
      final index = next++;
      if (index >= values.length) return;
      results[index] = await task(values[index]);
    }
  }

  await Future.wait(List<void>.generate(
    concurrency.clamp(1, values.length).toInt(),
    (_) => worker(),
  ));
  return results.cast<T>();
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
