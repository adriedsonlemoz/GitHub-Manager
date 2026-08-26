String automaticCommitMessage(String action) {
  final now = DateTime.now();
  String two(int value) => value.toString().padLeft(2, '0');
  final date = '${two(now.day)}/${two(now.month)}/${now.year}';
  final time = '${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
  return '$action • GitHub Manager • $date $time';
}
