import 'package:openbubbles_contact_bridge/openbubbles_contact_bridge.dart';
import 'package:test/test.dart';

void main() {
  test('removes broken rows, preserves row IDs, and links handles', () {
    const stored = [
      ContactRecord(dbId: 10, stableId: '', displayName: 'Broken'),
      ContactRecord(
        dbId: 11,
        stableId: 'carddav-uid:a',
        displayName: 'Old Name',
        phones: ['+1 555 0100'],
      ),
      ContactRecord(
        dbId: 12,
        stableId: 'shared:x',
        displayName: 'Shared',
        isShared: true,
      ),
    ];
    const fetched = [
      ContactRecord(
        stableId: 'carddav-uid:a',
        displayName: 'New Name',
        phones: ['+1 (555) 0100'],
      ),
      ContactRecord(
        stableId: 'carddav-uid:b',
        displayName: 'New Contact',
        emails: ['new@example.com'],
      ),
    ];
    const handles = [
      HandleRecord(dbId: 20, address: '+15550100', contactDbId: 10),
      HandleRecord(dbId: 21, address: 'nobody@example.com', contactDbId: 10),
    ];

    final result = reconcileContacts(
      storedContacts: stored,
      fetchedContacts: fetched,
      handles: handles,
    );

    expect(result.removedContactDbIds, {10});
    expect(result.updatedStableIds, {'carddav-uid:a'});
    expect(result.insertedStableIds, {'carddav-uid:b'});
    expect(
      result.contacts.singleWhere((c) => c.stableId == 'carddav-uid:a').dbId,
      11,
    );
    expect(result.contacts.any((c) => c.isShared && c.dbId == 12), isTrue);
    expect(result.handles[0].contactDbId, 11);
    expect(result.handles[1].contactDbId, isNull);
  });

  test('leaves ambiguous handle links unchanged', () {
    const contacts = [
      ContactRecord(dbId: 1, stableId: 'a', displayName: 'A', emails: ['x@y.z']),
      ContactRecord(dbId: 2, stableId: 'b', displayName: 'B', emails: ['X@Y.Z']),
    ];
    const handles = [HandleRecord(dbId: 3, address: 'x@y.z', contactDbId: 9)];

    final result = reconcileContacts(
      storedContacts: contacts,
      fetchedContacts: contacts,
      handles: handles,
    );

    expect(result.ambiguousHandleDbIds, {3});
    expect(result.handles.single.contactDbId, 9);
  });

  test('rejects duplicate fetched IDs', () {
    const duplicates = [
      ContactRecord(stableId: 'same', displayName: 'A'),
      ContactRecord(stableId: 'same', displayName: 'B'),
    ];
    expect(
      () => reconcileContacts(
        storedContacts: const [],
        fetchedContacts: duplicates,
        handles: const [],
      ),
      throwsStateError,
    );
  });
}

