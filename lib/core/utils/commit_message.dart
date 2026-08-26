String automaticCommitMessage(
  String action, {
  String? project,
  String? version,
}) {
  final now = DateTime.now();
  String two(int value) => value.toString().padLeft(2, '0');
  final date = '${two(now.day)}/${two(now.month)}/${now.year}';
  final time = '${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
  final parts = <String>[action.trim()];
  if (project?.trim().isNotEmpty == true) {
    final projectText = project!.trim();
    final versionText = version?.trim();
    parts.add(
      versionText?.isNotEmpty == true ? '$projectText v$versionText' : projectText,
    );
  } else if (version?.trim().isNotEmpty == true) {
    parts.add('v${version!.trim()}');
  }
  parts.add('GitHub Manager');
  parts.add('$date $time');
  return parts.join(' • ');
}
