class Participant {
  final String id;
  final String name;
  final bool isHost;
  final DateTime joinedAt;

  Participant({
    required this.id,
    required this.name,
    required this.isHost,
    required this.joinedAt,
  });

  factory Participant.fromMap(Map<String, dynamic> map, String id) {
    return Participant(
      id: id,
      name: map['name'] ?? '',
      isHost: map['isHost'] ?? false,
      joinedAt: DateTime.parse(map['joinedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'isHost': isHost,
      'joinedAt': joinedAt.toIso8601String(),
    };
  }
}
