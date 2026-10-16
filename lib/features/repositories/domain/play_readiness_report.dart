enum PlayCheckState { verified, attention, unknown }

class PlayCheck {
  const PlayCheck({
    required this.title,
    required this.detail,
    required this.state,
    this.evidence,
  });

  final String title;
  final String detail;
  final PlayCheckState state;
  final String? evidence;
}

class PlayReadinessReport {
  const PlayReadinessReport({
    required this.branch,
    required this.androidProject,
    required this.completeTree,
    required this.automatic,
    required this.manual,
    this.note,
  });

  final String branch;
  final bool androidProject;
  final bool completeTree;
  final List<PlayCheck> automatic;
  final List<PlayCheck> manual;
  final String? note;

  int get verified => automatic.where((c) => c.state == PlayCheckState.verified).length;
  int get attention => automatic.where((c) => c.state == PlayCheckState.attention).length;
  int get unknown => automatic.where((c) => c.state == PlayCheckState.unknown).length;
}
