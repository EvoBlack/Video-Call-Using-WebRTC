import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/user_model.dart';
import '../models/call_model.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  // Generate random meeting ID (like Zoom: 123-456-789)
  String generateMeetingId() {
    final random = Random();
    final part1 = random.nextInt(900) + 100; // 100-999
    final part2 = random.nextInt(900) + 100;
    final part3 = random.nextInt(900) + 100;
    return '$part1-$part2-$part3';
  }

  // Meeting Management
  Future<Meeting> createMeeting(String hostName) async {
    final meetingId = generateMeetingId();
    final hostId = DateTime.now().millisecondsSinceEpoch.toString();
    
    final meeting = Meeting(
      meetingId: meetingId,
      hostId: hostId,
      hostName: hostName,
      createdAt: DateTime.now(),
      status: MeetingStatus.waiting,
      participantIds: [hostId],
    );

    await _firestore.collection('meetings').doc(meetingId).set(meeting.toMap());
    
    // Add host as participant
    await addParticipant(meetingId, hostId, hostName, true);
    
    return meeting;
  }

  Future<Meeting?> getMeeting(String meetingId) async {
    try {
      print('Fetching meeting from Firestore: $meetingId');
      final doc = await _firestore.collection('meetings').doc(meetingId).get();
      print('Document exists: ${doc.exists}');
      
      if (doc.exists && doc.data() != null) {
        print('Meeting data: ${doc.data()}');
        return Meeting.fromMap(doc.data()!, doc.id);
      }
      print('Meeting not found or has no data');
      return null;
    } catch (e, stackTrace) {
      print('Error fetching meeting: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> updateMeetingStatus(String meetingId, MeetingStatus status) async {
    await _firestore.collection('meetings').doc(meetingId).update({
      'status': status.name,
    });
  }

  Future<void> endMeeting(String meetingId) async {
    await updateMeetingStatus(meetingId, MeetingStatus.ended);
    await clearSignaling(meetingId);
  }

  // Participant Management
  Future<void> addParticipant(String meetingId, String participantId, String name, bool isHost) async {
    final participant = Participant(
      id: participantId,
      name: name,
      isHost: isHost,
      joinedAt: DateTime.now(),
    );

    await _firestore
        .collection('meetings')
        .doc(meetingId)
        .collection('participants')
        .doc(participantId)
        .set(participant.toMap());

    // Update participant list in meeting
    await _firestore.collection('meetings').doc(meetingId).update({
      'participantIds': FieldValue.arrayUnion([participantId]),
    });
  }

  Future<void> removeParticipant(String meetingId, String participantId) async {
    await _firestore
        .collection('meetings')
        .doc(meetingId)
        .collection('participants')
        .doc(participantId)
        .delete();

    await _firestore.collection('meetings').doc(meetingId).update({
      'participantIds': FieldValue.arrayRemove([participantId]),
    });
  }

  Stream<List<Participant>> getParticipants(String meetingId) {
    return _firestore
        .collection('meetings')
        .doc(meetingId)
        .collection('participants')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Participant.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Signaling (WebRTC)
  DatabaseReference getSignalingRef(String meetingId, String participantId) {
    return _database.ref('signaling/$meetingId/$participantId');
  }

  Future<void> sendSignal(String meetingId, String toParticipantId, String type, Map<String, dynamic> data) async {
    await _database.ref('signaling/$meetingId/$toParticipantId/$type').push().set(data);
  }

  Stream<DatabaseEvent> listenToSignals(String meetingId, String participantId, String type) {
    return _database.ref('signaling/$meetingId/$participantId/$type').onChildAdded;
  }

  Stream<DatabaseEvent> listenToAllSignals(String meetingId, String type) {
    return _database.ref('signaling/$meetingId').onChildAdded;
  }
  
  Stream<List<Participant>> watchParticipants(String meetingId) {
    return _firestore
        .collection('meetings')
        .doc(meetingId)
        .collection('participants')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Participant.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> clearSignaling(String meetingId) async {
    await _database.ref('signaling/$meetingId').remove();
  }
}
