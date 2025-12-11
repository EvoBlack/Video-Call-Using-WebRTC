class Meeting {
  final String meetingId;
  final String hostId;
  final String hostName;
  final DateTime createdAt;
  final MeetingStatus status;
  final List<String> participantIds;

  Meeting({
    required this.meetingId,
    required this.hostId,
    required this.hostName,
    required this.createdAt,
    required this.status,
    this.participantIds = const [],
  });

  factory Meeting.fromMap(Map<String, dynamic> map, String id) {
    return Meeting(
      meetingId: id,
      hostId: map['hostId'] ?? '',
      hostName: map['hostName'] ?? '',
      createdAt: DateTime.parse(map['createdAt']),
      status: _parseStatus(map['status']),
      participantIds: List<String>.from(map['participantIds'] ?? []),
    );
  }

  static MeetingStatus _parseStatus(dynamic status) {
    if (status == null) return MeetingStatus.waiting;
    final statusStr = status.toString().toLowerCase();
    switch (statusStr) {
      case 'waiting':
        return MeetingStatus.waiting;
      case 'active':
        return MeetingStatus.active;
      case 'ended':
        return MeetingStatus.ended;
      default:
        return MeetingStatus.waiting;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'hostId': hostId,
      'hostName': hostName,
      'createdAt': createdAt.toIso8601String(),
      'status': status.name,
      'participantIds': participantIds,
    };
  }

  String get meetingLink => 'healthcare-meet://join/$meetingId';
}

enum MeetingStatus {
  waiting,
  active,
  ended,
}
