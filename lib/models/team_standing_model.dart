class TeamStanding {
  final String teamId;
  final String teamName;
  final int wins;
  final int losses;
  final int ties;
  final int totalMatches;
  final double winRatio;

  TeamStanding({
    required this.teamId,
    required this.teamName,
    required this.wins,
    required this.losses,
    required this.ties,
    required this.totalMatches,
    required this.winRatio,
  });
}
