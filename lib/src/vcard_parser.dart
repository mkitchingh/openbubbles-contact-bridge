import 'stable_id.dart';

class FetchedContact {
  const FetchedContact({
    required this.stableId,
    required this.displayName,
    required this.phones,
    required this.emails,
    required this.usedUid,
  });

  final String stableId;
  final String displayName;
  final List<String> phones;
  final List<String> emails;
  final bool usedUid;
}

FetchedContact parseVCard(String source, Uri href) {
  final unfolded = source.replaceAll(RegExp(r'\r?\n[ \t]'), '');
  final values = <String, List<String>>{};
  for (final line in unfolded.split(RegExp(r'\r?\n'))) {
    final separator = line.indexOf(':');
    if (separator <= 0) continue;
    final descriptor = line.substring(0, separator);
    var property = descriptor.split(';').first.toUpperCase();
    if (property.contains('.')) property = property.split('.').last;
    final raw = line.substring(separator + 1);
    values.putIfAbsent(property, () => <String>[]).add(_decodeValue(raw));
  }

  final phones = (values['TEL'] ?? const <String>[])
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList(growable: false);
  final emails = (values['EMAIL'] ?? const <String>[])
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList(growable: false);
  var displayName = (_first(values['FN']) ?? '').trim();
  if (displayName.isEmpty) {
    final structured = _first(values['N']) ?? '';
    final parts = structured.split(';');
    displayName = <String>[
      if (parts.length > 3) parts[3],
      if (parts.length > 1) parts[1],
      if (parts.length > 2) parts[2],
      if (parts.isNotEmpty) parts[0],
      if (parts.length > 4) parts[4],
    ].where((part) => part.trim().isNotEmpty).join(' ').trim();
  }
  if (displayName.isEmpty) {
    displayName = _first(phones) ?? _first(emails) ?? '';
  }
  final stableId = stableContactId(source, href);
  return FetchedContact(
    stableId: stableId,
    displayName: displayName,
    phones: phones,
    emails: emails,
    usedUid: stableId.startsWith('carddav-uid:'),
  );
}

String _decodeValue(String value) => value
    .replaceAll(r'\n', '\n')
    .replaceAll(r'\N', '\n')
    .replaceAll(r'\,', ',')
    .replaceAll(r'\;', ';')
    .replaceAll(r'\\', r'\');

T? _first<T>(Iterable<T>? values) =>
    values == null || values.isEmpty ? null : values.first;
