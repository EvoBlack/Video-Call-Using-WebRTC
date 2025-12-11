import 'dart:async';
import 'firebase_service.dart';

class SignalingService {
  final FirebaseService _firebaseService = FirebaseService();
  final Map<String, StreamSubscription> _subscriptions = {};

  Future<void> sendOffer(String meetingId, String toParticipantId, Map<String, dynamic> offer) async {
    await _firebaseService.sendSignal(meetingId, toParticipantId, 'offer', {
      'sdp': offer['sdp'],
      'type': offer['type'],
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> sendAnswer(String meetingId, String toParticipantId, Map<String, dynamic> answer) async {
    await _firebaseService.sendSignal(meetingId, toParticipantId, 'answer', {
      'sdp': answer['sdp'],
      'type': answer['type'],
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> sendIceCandidate(String meetingId, String toParticipantId, Map<String, dynamic> candidate) async {
    await _firebaseService.sendSignal(meetingId, toParticipantId, 'ice', {
      'candidate': candidate['candidate'],
      'sdpMid': candidate['sdpMid'],
      'sdpMLineIndex': candidate['sdpMLineIndex'],
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void listenForOffer(String meetingId, String myParticipantId, Function(Map<String, dynamic>) onOffer) {
    _subscriptions['offer'] = _firebaseService
        .listenToSignals(meetingId, myParticipantId, 'offer')
        .listen((event) {
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        print('Received offer: ${data['type']}');
        onOffer({
          'sdp': data['sdp'],
          'type': data['type'],
        });
      }
    });
  }

  void listenForAllIceCandidates(String meetingId, String excludeParticipantId, Function(Map<String, dynamic>) onCandidate) {
    // Listen for ICE candidates from all participants except self
    _subscriptions['all_ice'] = _firebaseService
        .listenToAllSignals(meetingId, 'ice')
        .listen((event) {
      if (event.snapshot.value != null) {
        final participantId = event.snapshot.key;
        if (participantId != excludeParticipantId) {
          final data = Map<String, dynamic>.from(event.snapshot.value as Map);
          onCandidate({
            'candidate': data['candidate'],
            'sdpMid': data['sdpMid'],
            'sdpMLineIndex': data['sdpMLineIndex'],
          });
        }
      }
    });
  }

  void listenForAnswer(String meetingId, String participantId, Function(Map<String, dynamic>) onAnswer) {
    _subscriptions['answer'] = _firebaseService
        .listenToSignals(meetingId, participantId, 'answer')
        .listen((event) {
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        onAnswer({
          'sdp': data['sdp'],
          'type': data['type'],
        });
      }
    });
  }

  void listenForIceCandidates(String meetingId, String participantId, Function(Map<String, dynamic>) onCandidate) {
    _subscriptions['ice'] = _firebaseService
        .listenToSignals(meetingId, participantId, 'ice')
        .listen((event) {
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        onCandidate({
          'candidate': data['candidate'],
          'sdpMid': data['sdpMid'],
          'sdpMLineIndex': data['sdpMLineIndex'],
        });
      }
    });
  }

  Future<void> cleanup(String meetingId) async {
    _subscriptions.forEach((key, subscription) {
      subscription.cancel();
    });
    _subscriptions.clear();
    await _firebaseService.clearSignaling(meetingId);
  }

  void dispose() {
    _subscriptions.forEach((key, subscription) {
      subscription.cancel();
    });
    _subscriptions.clear();
  }
}
