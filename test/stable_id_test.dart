import 'package:openbubbles_contact_bridge/openbubbles_contact_bridge.dart';
import 'package:test/test.dart';

void main() {
  group('stableContactId', () {
    test('uses UID case-insensitively', () {
      final id = stableContactId(
        'BEGIN:VCARD\r\nuid:abc-123\r\nEND:VCARD\r\n',
        Uri.parse('https://example.test/a.vcf'),
      );
      expect(id, 'carddav-uid:abc-123');
    });

    test('unfolds a folded UID', () {
      final id = stableContactId(
        'BEGIN:VCARD\r\nUID:abc-\r\n 123\r\nEND:VCARD\r\n',
        Uri.parse('https://example.test/a.vcf'),
      );
      expect(id, 'carddav-uid:abc-123');
    });

    test('falls back to href', () {
      final id = stableContactId(
        'BEGIN:VCARD\r\nFN:Example\r\nEND:VCARD\r\n',
        Uri.parse('https://example.test/a.vcf'),
      );
      expect(id, 'carddav-href:https://example.test/a.vcf');
    });
  });

  test('normalizes email and phone addresses', () {
    expect(normalizeAddress(' User@Example.COM '), 'user@example.com');
    expect(normalizeAddress(' +1 (555) 010-2000 '), '+15550102000');
  });
}

