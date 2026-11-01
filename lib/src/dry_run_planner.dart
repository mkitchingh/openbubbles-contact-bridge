import 'dart:io';

import 'database_inspector.dart';
import 'openbubbles_objectbox.g.dart';
import 'openbubbles_objectbox_models.dart';
import 'stable_id.dart';
import 'vcard_parser.dart';

class CardDavSourceSummary {
  const CardDavSourceSummary({
    required this.addressBookCount,
    required this.vcardCount,
    required this.contacts,
  });

  final int addressBookCount;
  final int vcardCount;
  final List<FetchedContact> contacts;
}

Future<Map<String, Object?>> planDryRun(
  Directory snapshotRoot,
  CardDavSourceSummary source,
) async {
  final duplicates = <String>{};
  final fetchedById = <String, FetchedContact>{};
  for (final contact in source.contacts) {
    if (fetchedById.containsKey(contact.stableId)) {
      duplicates.add(contact.stableId);
    } else {
      fetchedById[contact.stableId] = contact;
    }
  }
  if (duplicates.isNotEmpty) {
    throw StateError(
        'Google CardDAV returned duplicate stable contact IDs. No plan was created.');
  }
  final verified = await verifyInspectionSnapshot(snapshotRoot);

  final store = Store(getObjectBoxModel(), directory: verified.database.path);
  try {
    final stored = store.box<Contact>().getAll();
    final handles = store.box<Handle>().getAll();
    final storedByStableId = <String, Contact>{};
    var emptyNonShared = 0;
    var shared = 0;
    for (final contact in stored) {
      if (contact.isShared) {
        shared++;
      } else if (contact.id.isEmpty) {
        emptyNonShared++;
      } else {
        storedByStableId[contact.id] = contact;
      }
    }

    var inserts = 0;
    var updates = 0;
    var unchanged = 0;
    for (final entry in fetchedById.entries) {
      final existing = storedByStableId[entry.key];
      if (existing == null) {
        inserts++;
      } else if (_sameContact(existing, entry.value)) {
        unchanged++;
      } else {
        updates++;
      }
    }

    final addressOwners = <String, Set<String>>{};
    for (final entry in fetchedById.entries) {
      for (final address in <String>[...entry.value.phones, ...entry.value.emails]) {
        final normalized = normalizeAddress(address);
        if (normalized.isNotEmpty) {
          addressOwners
              .putIfAbsent(normalized, () => <String>{})
              .add('carddav:${entry.key}');
        }
      }
    }
    for (final contact in stored.where((value) => value.isShared)) {
      for (final address in <String>[...contact.phones, ...contact.emails]) {
        final normalized = normalizeAddress(address);
        if (normalized.isNotEmpty) {
          addressOwners
              .putIfAbsent(normalized, () => <String>{})
              .add('shared:${contact.dbId}');
        }
      }
    }

    var uniqueHandleMatches = 0;
    var ambiguousHandleMatches = 0;
    var unmatchedHandles = 0;
    for (final handle in handles) {
      final address = handle.address is String ? handle.address as String : '';
      final owners = addressOwners[normalizeAddress(address)] ??
          const <String>{};
      if (owners.length == 1) {
        uniqueHandleMatches++;
      } else if (owners.length > 1) {
        ambiguousHandleMatches++;
      } else {
        unmatchedHandles++;
      }
    }

    return <String, Object?>{
      'reportVersion': 1,
      'mode': 'dry-run',
      'writesPerformed': false,
      'modelSourceVersion': objectBoxModelSourceVersion,
      'modelFingerprint': objectBoxModelFingerprint,
      'packageVersion': verified.packageVersion,
      'databaseBytes': verified.databaseBytes,
      'source': <String, int>{
        'addressBooks': source.addressBookCount,
        'vcards': source.vcardCount,
        'uniqueStableIds': fetchedById.length,
        'uidStableIds':
            fetchedById.values.where((contact) => contact.usedUid).length,
        'hrefFallbackStableIds':
            fetchedById.values.where((contact) => !contact.usedUid).length,
      },
      'database': <String, int>{
        'contacts': stored.length,
        'emptyNonSharedContacts': emptyNonShared,
        'sharedContacts': shared,
        'handles': handles.length,
      },
      'plan': <String, int>{
        'removeEmptyNonSharedContacts': emptyNonShared,
        'insertStableContacts': inserts,
        'updateExistingStableContacts': updates,
        'unchangedStableContacts': unchanged,
        'preserveSharedContacts': shared,
        'uniqueHandleMatches': uniqueHandleMatches,
        'ambiguousHandleMatches': ambiguousHandleMatches,
        'unmatchedHandles': unmatchedHandles,
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

bool _sameContact(Contact stored, FetchedContact fetched) =>
    stored.displayName == fetched.displayName &&
    _sameNormalized(stored.phones, fetched.phones) &&
    _sameNormalized(stored.emails, fetched.emails);

bool _sameNormalized(Iterable<String> left, Iterable<String> right) {
  final a = left.map(normalizeAddress).where((value) => value.isNotEmpty).toSet();
  final b = right.map(normalizeAddress).where((value) => value.isNotEmpty).toSet();
  return a.length == b.length && a.containsAll(b);
}
