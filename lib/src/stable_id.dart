String stableContactId(String vCard, Uri href) {
  final unfolded = vCard.replaceAll(RegExp(r'\r?\n[ \t]'), '');
  final match = RegExp(
    r'^UID(?:;[^:\r\n]*)?:(.+)$',
    multiLine: true,
    caseSensitive: false,
  ).firstMatch(unfolded);
  final uid = match?.group(1)?.trim();
  if (uid != null && uid.isNotEmpty) return 'carddav-uid:$uid';
  return 'carddav-href:$href';
}

String normalizeAddress(String address) {
  final value = address.trim();
  if (value.contains('@')) return value.toLowerCase();
  final hasPlus = value.startsWith('+');
  final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
  return '${hasPlus ? '+' : ''}$digits';
}

