class LeaderboardRewardModel {
  final double? amount;
  final String status;
  final String? note;

  LeaderboardRewardModel({
    required this.amount,
    required this.status,
    this.note,
  });

  factory LeaderboardRewardModel.fromJson(Map<String, dynamic> json) {
    final raw = json['amount'];
    double? amount;
    if (raw is num) {
      amount = raw.toDouble();
    }
    return LeaderboardRewardModel(
      amount: amount,
      status: json['status']?.toString() ?? 'pending',
      note: json['note']?.toString(),
    );
  }
}

class LeaderboardEntryModel {
  final int rank;
  final String displayName;
  final double marks;
  final int? timeMicroseconds;
  final LeaderboardRewardModel reward;

  LeaderboardEntryModel({
    required this.rank,
    required this.displayName,
    required this.marks,
    required this.timeMicroseconds,
    required this.reward,
  });

  factory LeaderboardEntryModel.fromJson(Map<String, dynamic> json) {
    final timeRaw = json['time_microseconds'];
    int? timeUs;
    if (timeRaw is int) {
      timeUs = timeRaw;
    } else if (timeRaw is num) {
      timeUs = timeRaw.toInt();
    }
    return LeaderboardEntryModel(
      rank: (json['rank'] as num).toInt(),
      displayName: json['display_name']?.toString() ?? '',
      marks: (json['marks'] as num?)?.toDouble() ?? 0,
      timeMicroseconds: timeUs,
      reward: LeaderboardRewardModel.fromJson(
        Map<String, dynamic>.from(json['reward'] as Map? ?? {}),
      ),
    );
  }
}

class LeaderboardResponseModel {
  final String duelId;
  final int total;
  final int limit;
  final int offset;
  final List<LeaderboardEntryModel> entries;

  LeaderboardResponseModel({
    required this.duelId,
    required this.total,
    required this.limit,
    required this.offset,
    required this.entries,
  });

  factory LeaderboardResponseModel.fromJson(Map<String, dynamic> json) {
    final raw = json['entries'];
    final list = <LeaderboardEntryModel>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          list.add(LeaderboardEntryModel.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    return LeaderboardResponseModel(
      duelId: json['duel_id']?.toString() ?? '',
      total: (json['total'] as num?)?.toInt() ?? 0,
      limit: (json['limit'] as num?)?.toInt() ?? 0,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
      entries: list,
    );
  }
}

class MyRankResponseModel {
  final String duelId;
  final LeaderboardEntryModel entry;

  MyRankResponseModel({
    required this.duelId,
    required this.entry,
  });

  factory MyRankResponseModel.fromJson(Map<String, dynamic> json) {
    return MyRankResponseModel(
      duelId: json['duel_id']?.toString() ?? '',
      entry: LeaderboardEntryModel.fromJson(
        Map<String, dynamic>.from(json['entry'] as Map),
      ),
    );
  }
}
