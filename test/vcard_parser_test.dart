import 'package:openbubbles_contact_bridge/src/vcard_parser.dart';
import 'package:test/test.dart';

void main() {
  test('parses folded Google vCard fields and stable UID', () {
    const source = 'BEGIN:VCARD\r\n'
        'VERSION:3.0\r\n'
        'UID:google-contact-123\r\n'
        'FN:Private\\, Person\r\n'
        'item1.TEL;TYPE=CELL:+1 (555) 010-2000\r\n'
        'item2.EMAIL;TYPE=HOME:Private@Example.Test\r\n'
        'NOTE:this is folded\r\n'
        ' across lines\r\n'
        'END:VCARD\r\n';
    final contact = parseVCard(
      source,
      Uri.parse('https://www.googleapis.com/carddav/contact/123'),
    );
    expect(contact.stableId, 'carddav-uid:google-contact-123');
    expect(contact.displayName, 'Private, Person');
    expect(contact.phones, <String>['+1 (555) 010-2000']);
    expect(contact.emails, <String>['Private@Example.Test']);
    expect(contact.usedUid, isTrue);
  });

  test('uses href when UID is absent and builds a structured name', () {
    final href = Uri.parse('https://www.googleapis.com/carddav/contact/456');
    final contact = parseVCard(
      'BEGIN:VCARD\nVERSION:3.0\nN:Family;Given;Middle;Dr.;Jr.\nEND:VCARD\n',
      href,
    );
    expect(contact.stableId, 'carddav-href:$href');
    expect(contact.displayName, 'Dr. Given Middle Family Jr.');
    expect(contact.usedUid, isFalse);
  });

  test('splits a Google Contacts export containing multiple cards', () {
    const bundle = 'BEGIN:VCARD\r\nVERSION:3.0\r\nUID:one\r\n'
        'FN:Private One\r\nEND:VCARD\r\n'
        'BEGIN:VCARD\r\nVERSION:3.0\r\nUID:two\r\n'
        'FN:Private Two\r\nEND:VCARD\r\n';
    final contacts = parseVCardBundle(
      bundle,
      Uri.parse('https://local-export.invalid/openbubbles/'),
    );
    expect(contacts.length, 2);
    expect(contacts.map((contact) => contact.stableId),
        <String>['carddav-uid:one', 'carddav-uid:two']);
  });

  test('rejects a file without vCards', () {
    expect(
      () => parseVCardBundle(
        'not a vcard',
        Uri.parse('https://local-export.invalid/openbubbles/'),
      ),
      throwsFormatException,
    );
  });
}
