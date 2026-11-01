import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:objectbox/objectbox.dart';

import 'openbubbles_objectbox.g.dart';
import 'openbubbles_objectbox_models.dart';

const objectBoxModelFingerprint =
    '62da57a39eea2ea78c221b32a504d63224aba4263f07335cbf6205facbd2352c';
const objectBoxModelSourceVersion = 'OpenBubbles 1.15.0';
const inspectionMarkerName = 'inspection-snapshot.json';

Future<Map<String, Object?>> inspectSnapshot(Directory snapshotRoot) async {
  final root = Directory(snapshotRoot.resolveSymbolicLinksSync());
  final markerFile = File('${root.path}${Platform.pathSeparator}$inspectionMarkerName');
  if (!markerFile.existsSync()) {
    throw StateError('Inspection marker is missing. Refusing to open this database.');
  }

  final decoded = jsonDecode(await markerFile.readAsString());
  if (decoded is! Map<String, dynamic> || decoded['markerVersion'] != 1) {
    throw StateError('Inspection marker is invalid or unsupported.');
  }
  final relative = decoded['databaseRelativeDirectory'];
  final expectedHash = decoded['dataSha256'];
  if (relative is! String || relative.isEmpty || expectedHash is! String) {
    throw StateError('Inspection marker is incomplete.');
  }
  if (relative.contains('..') || relative.contains(':') ||
      relative.startsWith('/') || relative.startsWith(r'\')) {
    throw StateError('Inspection database path is unsafe.');
  }

  final database = Directory('${root.path}${Platform.pathSeparator}$relative');
  if (!database.existsSync()) throw StateError('Snapshot database is missing.');
  final resolvedDatabase = database.resolveSymbolicLinksSync();
  final rootPrefix = '${root.path}${Platform.pathSeparator}'.toLowerCase();
  if (!resolvedDatabase.toLowerCase().startsWith(rootPrefix)) {
    throw StateError('Snapshot database resolves outside its snapshot directory.');
  }
  final dataFile = File('$resolvedDatabase${Platform.pathSeparator}data.mdb');
  if (!dataFile.existsSync()) throw StateError('Snapshot data.mdb is missing.');
  final actualHash = (await sha256.bind(dataFile.openRead()).first).toString();
  if (actualHash.toLowerCase() != expectedHash.toLowerCase()) {
    throw StateError('Snapshot hash verification failed.');
  }

  final store = Store(getObjectBoxModel(), directory: resolvedDatabase);
  try {
    final contactBox = store.box<Contact>();
    final handleBox = store.box<Handle>();
    final contacts = contactBox.getAll();
    final handles = handleBox.getAll();

    final stableIdCounts = <String, int>{};
    var emptyContactIds = 0;
    var sharedContacts = 0;
    var dismissedContacts = 0;
    for (final contact in contacts) {
      final id = (contact.id ?? '').toString();
      if (id.isEmpty) {
        emptyContactIds++;
      } else {
        stableIdCounts.update(id, (value) => value + 1, ifAbsent: () => 1);
      }
      if (contact.isShared == true) sharedContacts++;
      if (contact.isDismissed == true) dismissedContacts++;
    }

    var linkedHandles = 0;
    for (final handle in handles) {
      if (handle.contactRelation.targetId != 0) linkedHandles++;
    }

    return <String, Object?>{
      'reportVersion': 1,
      'modelSourceVersion': objectBoxModelSourceVersion,
      'modelFingerprint': objectBoxModelFingerprint,
      'packageVersion': decoded['packageVersion'],
      'databaseBytes': dataFile.lengthSync(),
      'entities': <String, int>{
        'attachments': store.box<Attachment>().count(),
        'chats': store.box<Chat>().count(),
        'fcmData': store.box<FCMData>().count(),
        'handles': handles.length,
        'themeEntries': store.box<ThemeEntry>().count(),
        'messages': store.box<Message>().count(),
        'themeObjects': store.box<ThemeObject>().count(),
        'themeStructs': store.box<ThemeStruct>().count(),
        'contacts': contacts.length,
      },
      'contacts': <String, int>{
        'emptyIds': emptyContactIds,
        'shared': sharedContacts,
        'dismissed': dismissedContacts,
        'uniqueNonEmptyIds': stableIdCounts.length,
        'duplicateNonEmptyIds':
            stableIdCounts.values.where((count) => count > 1).length,
      },
      'handles': <String, int>{
        'linked': linkedHandles,
        'unlinked': handles.length - linkedHandles,
      },
      'privacy': <String, Object?>{
        'containsContactValues': false,
        'containsMessageValues': false,
        'containsCredentials': false,
      },
    };
  } finally {
    store.close();
  }
}

