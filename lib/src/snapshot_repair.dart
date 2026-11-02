import 'dart:io';

import 'database_inspector.dart';
import 'dry_run_planner.dart';
import 'openbubbles_objectbox.g.dart';
import 'openbubbles_objectbox_models.dart';
import 'stable_id.dart';
import 'vcard_parser.dart';

Future<Map<String, Object?>> repairInspectionSnapshot(
  Directory snapshotRoot,
  CardDavSourceSummary source,
) async {
  final fetchedById = _uniqueFetchedContacts(source.contacts);
  final verified = await verifyInspectionSnapshot(snapshotRoot);
  final databasePath = verified.database.path;

  late Map<Type, int> entityCountsBefore;
  late Set<int> sharedContactIdsBefore;
  late Set<int> removedContactIds;
  var inserted = 0;
  var updated = 0;
  var unchanged = 0;
  var uniqueHandleMatches = 0;
  var ambiguousHandleMatches = 0;
  var unmatchedHandles = 0;
  var handlesRelinked = 0;
  var removedHandleLinksCleared = 0;

  var store = Store(getObjectBoxModel(), directory: databasePath);
  try {
    entityCountsBefore = _entityCounts(store);
    final contactsBefore = store.box<Contact>().getAll();
    sharedContactIdsBefore = contactsBefore
        .where((contact) => contact.isShared)
        .map((contact) => contact.dbId!)
        .toSet();

    store.runInTransaction(TxMode.write, () {
      final contactBox = store.box<Contact>();
      final handleBox = store.box<Handle>();
      final contacts = contactBox.getAll();
      final handles = handleBox.getAll();
      removedContactIds = contacts
          .where((contact) => !contact.isShared && contact.id.isEmpty)
          .map((contact) => contact.dbId!)
          .toSet();

      final storedByStableId = <String, Contact>{};
      for (final contact in contacts) {
        if (contact.isShared || contact.id.isEmpty) continue;
        if (storedByStableId.containsKey(contact.id)) {
          throw StateError(
              'The snapshot contains duplicate stable contact IDs. No repair was committed.');
        }
        storedByStableId[contact.id] = contact;
      }

      for (final entry in fetchedById.entries) {
        final fetched = entry.value;
        final existing = storedByStableId[entry.key];
        if (existing == null) {
          final insertedContact = Contact(
            id: entry.key,
            displayName: fetched.displayName,
            phones: List<String>.from(fetched.phones),
            emails: List<String>.from(fetched.emails),
          );
          contactBox.put(insertedContact);
          storedByStableId[entry.key] = insertedContact;
          inserted++;
        } else if (_sameContact(existing, fetched)) {
          unchanged++;
        } else {
          existing
            ..displayName = fetched.displayName
            ..phones = List<String>.from(fetched.phones)
            ..emails = List<String>.from(fetched.emails);
          contactBox.put(existing);
          updated++;
        }
      }

      final addressOwners = <String, Set<int>>{};
      for (final contact in contactBox.getAll()) {
        if (!contact.isShared && contact.id.isEmpty) continue;
        final contactId = contact.dbId!;
        for (final address in <String>[...contact.phones, ...contact.emails]) {
          final normalized = normalizeAddress(address);
          if (normalized.isNotEmpty) {
            addressOwners.putIfAbsent(normalized, () => <int>{}).add(contactId);
          }
        }
      }

      for (final handle in handles) {
        final address = handle.address is String ? handle.address as String : '';
        final matches =
            addressOwners[normalizeAddress(address)] ?? const <int>{};
        final oldTarget = handle.contactRelation.targetId;
        if (matches.length == 1) {
          uniqueHandleMatches++;
          final newTarget = matches.single;
          if (oldTarget != newTarget) {
            handle.contactRelation.targetId = newTarget;
            handleBox.put(handle);
            handlesRelinked++;
          }
        } else if (matches.length > 1) {
          ambiguousHandleMatches++;
        } else {
          unmatchedHandles++;
          if (removedContactIds.contains(oldTarget)) {
            handle.contactRelation.targetId = 0;
            handleBox.put(handle);
            removedHandleLinksCleared++;
          }
        }
      }
      if (removedContactIds.isNotEmpty) {
        contactBox.removeMany(removedContactIds.toList(growable: false));
      }
    });
  } finally {
    store.close();
  }

  store = Store(getObjectBoxModel(), directory: databasePath);
  try {
    final contacts = store.box<Contact>().getAll();
    final handles = store.box<Handle>().getAll();
    final entityCountsAfter = _entityCounts(store);
    final sharedContactIdsAfter = contacts
        .where((contact) => contact.isShared)
        .map((contact) => contact.dbId!)
        .toSet();
    if (!_sameSet(sharedContactIdsBefore, sharedContactIdsAfter)) {
      throw StateError('Snapshot verification failed: shared contacts changed.');
    }
    if (contacts.any((contact) => !contact.isShared && contact.id.isEmpty)) {
      throw StateError(
          'Snapshot verification failed: empty non-shared contacts remain.');
    }
    for (final entry in fetchedById.entries) {
      final matches = contacts.where((contact) => contact.id == entry.key).toList();
      if (matches.length != 1 || !_sameContact(matches.single, entry.value)) {
        throw StateError(
            'Snapshot verification failed: a fetched contact was not stored exactly once.');
      }
    }
    final contactIds = contacts.map((contact) => contact.dbId!).toSet();
    if (handles.any((handle) =>
        handle.contactRelation.targetId != 0 &&
        !contactIds.contains(handle.contactRelation.targetId))) {
      throw StateError('Snapshot verification failed: an orphan handle link exists.');
    }
    for (final type in entityCountsBefore.keys) {
      if (type == Contact) continue;
      if (entityCountsBefore[type] != entityCountsAfter[type]) {
        throw StateError(
            'Snapshot verification failed: an unrelated entity count changed.');
      }
    }

    return <String, Object?>{
      'reportVersion': 1,
      'mode': 'snapshot-rehearsal',
      'writesPerformed': true,
      'verifiedSnapshotModified': true,
      'liveDatabaseOpened': false,
      'modelSourceVersion': objectBoxModelSourceVersion,
      'modelFingerprint': objectBoxModelFingerprint,
      'packageVersion': verified.packageVersion,
      'source': <String, int>{
        'addressBooks': source.addressBookCount,
        'vcards': source.vcardCount,
        'uniqueStableIds': fetchedById.length,
      },
      'result': <String, int>{
        'contacts': contacts.length,
        'handles': handles.length,
        'removedEmptyNonSharedContacts': removedContactIds.length,
        'insertedStableContacts': inserted,
        'updatedExistingStableContacts': updated,
        'unchangedStableContacts': unchanged,
        'preservedSharedContacts': sharedContactIdsAfter.length,
        'uniqueHandleMatches': uniqueHandleMatches,
        'ambiguousHandleMatches': ambiguousHandleMatches,
        'unmatchedHandles': unmatchedHandles,
        'handlesRelinked': handlesRelinked,
        'removedHandleLinksCleared': removedHandleLinksCleared,
      },
      'verification': <String, Object?>{
        'reopenedSuccessfully': true,
        'sharedContactsPreserved': true,
        'fetchedContactsStoredExactlyOnce': true,
        'noEmptyNonSharedContacts': true,
        'noOrphanHandleLinks': true,
        'unrelatedEntityCountsPreserved': true,
      },
      'privacy': <String, Object?>{
        'containsContactValues': false,
        'containsVCardValues': false,
        'containsOAuthCredentials': false,
      },
    };
  } finally {
    store.close();
  }
}

Map<String, FetchedContact> _uniqueFetchedContacts(
    Iterable<FetchedContact> contacts) {
  final result = <String, FetchedContact>{};
  for (final contact in contacts) {
    if (result.containsKey(contact.stableId)) {
      throw StateError(
          'Google CardDAV returned duplicate stable contact IDs. No repair was attempted.');
    }
    result[contact.stableId] = contact;
  }
  return result;
}

Map<Type, int> _entityCounts(Store store) => <Type, int>{
      Attachment: store.box<Attachment>().count(),
      Chat: store.box<Chat>().count(),
      FCMData: store.box<FCMData>().count(),
      Handle: store.box<Handle>().count(),
      ThemeEntry: store.box<ThemeEntry>().count(),
      Message: store.box<Message>().count(),
      ThemeObject: store.box<ThemeObject>().count(),
      ThemeStruct: store.box<ThemeStruct>().count(),
      Contact: store.box<Contact>().count(),
    };

bool _sameContact(Contact stored, FetchedContact fetched) =>
    stored.displayName == fetched.displayName &&
    _sameNormalized(stored.phones, fetched.phones) &&
    _sameNormalized(stored.emails, fetched.emails);

bool _sameNormalized(Iterable<String> left, Iterable<String> right) {
  final a = left.map(normalizeAddress).where((value) => value.isNotEmpty).toSet();
  final b = right.map(normalizeAddress).where((value) => value.isNotEmpty).toSet();
  return _sameSet(a, b);
}

bool _sameSet<T>(Set<T> left, Set<T> right) =>
    left.length == right.length && left.containsAll(right);
