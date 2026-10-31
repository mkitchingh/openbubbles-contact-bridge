class ContactRecord {
  const ContactRecord({
    required this.stableId,
    required this.displayName,
    this.dbId,
    this.phones = const [],
    this.emails = const [],
    this.isShared = false,
  });

  final int? dbId;
  final String stableId;
  final String displayName;
  final List<String> phones;
  final List<String> emails;
  final bool isShared;

  ContactRecord copyWith({
    int? dbId,
    String? stableId,
    String? displayName,
    List<String>? phones,
    List<String>? emails,
    bool? isShared,
  }) =>
      ContactRecord(
        dbId: dbId ?? this.dbId,
        stableId: stableId ?? this.stableId,
        displayName: displayName ?? this.displayName,
        phones: phones ?? this.phones,
        emails: emails ?? this.emails,
        isShared: isShared ?? this.isShared,
      );
}

class HandleRecord {
  const HandleRecord({
    required this.dbId,
    required this.address,
    this.contactDbId,
  });

  final int dbId;
  final String address;
  final int? contactDbId;

  HandleRecord linkTo(int? id) =>
      HandleRecord(dbId: dbId, address: address, contactDbId: id);
}

class ReconciliationResult {
  const ReconciliationResult({
    required this.contacts,
    required this.handles,
    required this.removedContactDbIds,
    required this.insertedStableIds,
    required this.updatedStableIds,
    required this.ambiguousHandleDbIds,
  });

  final List<ContactRecord> contacts;
  final List<HandleRecord> handles;
  final Set<int> removedContactDbIds;
  final Set<String> insertedStableIds;
  final Set<String> updatedStableIds;
  final Set<int> ambiguousHandleDbIds;
}

