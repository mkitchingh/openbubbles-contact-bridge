import 'models.dart';
import 'stable_id.dart';

ReconciliationResult reconcileContacts({
  required List<ContactRecord> storedContacts,
  required List<ContactRecord> fetchedContacts,
  required List<HandleRecord> handles,
}) {
  final removed = <int>{};
  final inserted = <String>{};
  final updated = <String>{};

  final fetchedById = <String, ContactRecord>{};
  for (final contact in fetchedContacts) {
    if (contact.stableId.isEmpty) {
      throw ArgumentError('Fetched contacts must have a stable ID.');
    }
    if (fetchedById.containsKey(contact.stableId)) {
      throw StateError('Duplicate fetched contact ID: ${contact.stableId}');
    }
    fetchedById[contact.stableId] = contact;
  }

  final storedById = <String, ContactRecord>{};
  final preservedShared = <ContactRecord>[];
  for (final contact in storedContacts) {
    if (contact.isShared) {
      preservedShared.add(contact);
    } else if (contact.stableId.isEmpty) {
      if (contact.dbId != null) removed.add(contact.dbId!);
    } else {
      storedById[contact.stableId] = contact;
    }
  }

  final reconciled = <ContactRecord>[...preservedShared];
  for (final entry in fetchedById.entries) {
    final old = storedById[entry.key];
    final fresh = entry.value;
    if (old == null) {
      reconciled.add(fresh);
      inserted.add(entry.key);
    } else {
      reconciled.add(fresh.copyWith(dbId: old.dbId));
      if (!_sameContact(old, fresh)) updated.add(entry.key);
    }
  }

  // Contacts no longer returned by CardDAV are not deleted in this first
  // implementation. Destructive pruning needs provider ownership metadata.
  for (final old in storedById.values) {
    if (!fetchedById.containsKey(old.stableId)) reconciled.add(old);
  }

  final candidates = <String, Set<int>>{};
  for (final contact in reconciled) {
    final id = contact.dbId;
    if (id == null) continue; // Assigned by the adapter before relation writes.
    for (final address in [...contact.phones, ...contact.emails]) {
      final normalized = normalizeAddress(address);
      if (normalized.isEmpty) continue;
      candidates.putIfAbsent(normalized, () => <int>{}).add(id);
    }
  }

  final ambiguous = <int>{};
  final linkedHandles = <HandleRecord>[];
  for (final handle in handles) {
    final matches = candidates[normalizeAddress(handle.address)] ?? const <int>{};
    if (matches.length == 1) {
      linkedHandles.add(handle.linkTo(matches.single));
    } else if (matches.length > 1) {
      ambiguous.add(handle.dbId);
      linkedHandles.add(handle);
    } else if (removed.contains(handle.contactDbId)) {
      linkedHandles.add(handle.linkTo(null));
    } else {
      linkedHandles.add(handle);
    }
  }

  return ReconciliationResult(
    contacts: reconciled,
    handles: linkedHandles,
    removedContactDbIds: removed,
    insertedStableIds: inserted,
    updatedStableIds: updated,
    ambiguousHandleDbIds: ambiguous,
  );
}

bool _sameContact(ContactRecord a, ContactRecord b) =>
    a.displayName == b.displayName &&
    _sameSet(a.phones.map(normalizeAddress), b.phones.map(normalizeAddress)) &&
    _sameSet(a.emails.map(normalizeAddress), b.emails.map(normalizeAddress));

bool _sameSet(Iterable<String> a, Iterable<String> b) {
  final left = a.toSet();
  final right = b.toSet();
  return left.length == right.length && left.containsAll(right);
}

