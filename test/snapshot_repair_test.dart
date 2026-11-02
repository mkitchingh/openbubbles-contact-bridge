import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:openbubbles_contact_bridge/src/database_inspector.dart';
import 'package:openbubbles_contact_bridge/src/dry_run_planner.dart';
import 'package:openbubbles_contact_bridge/src/openbubbles_objectbox.g.dart';
import 'package:openbubbles_contact_bridge/src/openbubbles_objectbox_models.dart';
import 'package:openbubbles_contact_bridge/src/snapshot_repair.dart';
import 'package:openbubbles_contact_bridge/src/vcard_parser.dart';
import 'package:test/test.dart';

void main() {
  test('repairs and verifies only a marked snapshot', () async {
    final root = await Directory.systemTemp.createTemp('ob-rehearsal-');
    addTearDown(() => root.delete(recursive: true));
    final database = Directory('${root.path}${Platform.pathSeparator}objectbox')
      ..createSync(recursive: true);
    final store = Store(getObjectBoxModel(), directory: database.path);
    late int brokenId;
    late int sharedId;
    try {
      final contactBox = store.box<Contact>();
      brokenId = contactBox.put(Contact(
        id: '',
        displayName: 'Old Private Name',
        phones: const <String>['+15550102000'],
        emails: const <String>['old-private@example.test'],
      ));
      sharedId = contactBox.put(Contact(
        id: 'shared:preserved',
        displayName: 'Shared Private Name',
        phones: const <String>['+15550103000'],
        isShared: true,
      ));
      final handle = Handle(address: '+1 555 010 2000');
      handle.contactRelation.targetId = brokenId;
      store.box<Handle>().put(handle);
    } finally {
      store.close();
    }
    final dataFile = File('${database.path}${Platform.pathSeparator}data.mdb');
    final beforeHash = (await sha256.bind(dataFile.openRead()).first).toString();
    await File('${root.path}${Platform.pathSeparator}$inspectionMarkerName')
        .writeAsString(jsonEncode(<String, Object?>{
      'markerVersion': 1,
      'databaseRelativeDirectory': 'objectbox',
      'dataSha256': beforeHash,
      'packageVersion': 'fixture',
    }));

    final fetched = parseVCard(
      'BEGIN:VCARD\nVERSION:3.0\nUID:private-uid\nFN:New Private Name\n'
      'TEL:+15550102000\nEMAIL:new-private@example.test\nEND:VCARD\n',
      Uri.parse('https://www.googleapis.com/carddav/contact/private'),
    );
    final report = await repairInspectionSnapshot(
      root,
      CardDavSourceSummary(
        addressBookCount: 1,
        vcardCount: 1,
        contacts: <FetchedContact>[fetched],
      ),
    );
    final encoded = jsonEncode(report);
    final result = report['result'] as Map<String, int>;
    expect(report['mode'], 'snapshot-rehearsal');
    expect(report['liveDatabaseOpened'], isFalse);
    expect(result['removedEmptyNonSharedContacts'], 1);
    expect(result['insertedStableContacts'], 1);
    expect(result['handlesRelinked'], 1);
    expect(encoded, isNot(contains('Private')));
    expect(encoded, isNot(contains('+15550102000')));
    expect(encoded, isNot(contains('example.test')));

    final reopened = Store(getObjectBoxModel(), directory: database.path);
    try {
      final contacts = reopened.box<Contact>().getAll();
      expect(contacts.any((contact) => contact.dbId == brokenId), isFalse);
      expect(contacts.any((contact) => contact.dbId == sharedId), isTrue);
      final inserted = contacts.singleWhere(
          (contact) => contact.id == 'carddav-uid:private-uid');
      expect(reopened.box<Handle>().getAll().single.contactRelation.targetId,
          inserted.dbId);
    } finally {
      reopened.close();
    }
  });
}
