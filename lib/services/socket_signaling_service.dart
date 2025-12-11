import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/app_config.dart';

class SocketSignalingService {
  static final SocketSignalingService _instance = SocketSignalingService._internal();
  factory SocketSignalingService() => _instance;
  SocketSignalingService._internal();

  IO.Socket? _socket;
  bool _isConnected = false;

  // Server URL is now managed in lib/config/app_config.dart
  // This allows easy switching between development and production
  String get serverUrl => AppConfig.serverUrl;

  // Callbacks
  Function(Map<String, dynamic>)? onOffer;
  Function(Map<String, dynamic>)? onAnswer;
  Function(Map<String, dynamic>)? onIceCandidate;
  Function(Map<String, dynamic>)? onParticipantJoined;
  Function(Map<String, dynamic>)? onParticipantLeft;
  Function(List<dynamic>)? onExistingParticipants;

  Future<void> connect() async {
    if (_isConnected) return;

    print('🌐 Environment: ${AppConfig.environment}');
    print('🔗 Connecting to signaling server: $serverUrl');

    _socket = IO.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    _socket!.connect();

    _socket!.onConnect((_) {
      print('Connected to signaling server');
      _isConnected = true;
    });

    _socket!.onDisconnect((_) {
      print('Disconnected from signaling server');
      _isConnected = false;
    });

    _socket!.onConnectError((error) {
      print('Connection error: $error');
    });

    _socket!.onError((error) {
      print('Socket error: $error');
    });

    // Listen for WebRTC signaling events
    _socket!.on('offer', (data) {
      print('Received offer from ${data['fromParticipantName']}');
      if (onOffer != null) {
        onOffer!(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('answer', (data) {
      print('Received answer from ${data['fromParticipantId']}');
      if (onAnswer != null) {
        onAnswer!(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('ice-candidate', (data) {
      print('Received ICE candidate from ${data['fromParticipantId']}');
      if (onIceCandidate != null) {
        onIceCandidate!(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('participant-joined', (data) {
      print('Participant joined: ${data['participantName']}');
      if (onParticipantJoined != null) {
        onParticipantJoined!(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('participant-left', (data) {
      print('Participant left: ${data['participantName']}');
      if (onParticipantLeft != null) {
        onParticipantLeft!(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('existing-participants', (data) {
      print('Existing participants: ${data.length}');
      if (onExistingParticipants != null) {
        onExistingParticipants!(data);
      }
    });
  }

  void joinMeeting({
    required String meetingId,
    required String participantId,
    required String participantName,
    required bool isHost,
  }) {
    if (!_isConnected) {
      print('Not connected to server, cannot join meeting');
      return;
    }

    print('Joining meeting: $meetingId as $participantName');
    _socket!.emit('join-meeting', {
      'meetingId': meetingId,
      'participantId': participantId,
      'participantName': participantName,
      'isHost': isHost,
    });
  }

  void sendOffer({
    required String meetingId,
    required String toParticipantId,
    required Map<String, dynamic> offer,
  }) {
    print('Sending offer to $toParticipantId');
    _socket!.emit('offer', {
      'meetingId': meetingId,
      'toParticipantId': toParticipantId,
      'offer': offer,
    });
  }

  void sendAnswer({
    required String meetingId,
    required String toParticipantId,
    required Map<String, dynamic> answer,
  }) {
    print('Sending answer to $toParticipantId');
    _socket!.emit('answer', {
      'meetingId': meetingId,
      'toParticipantId': toParticipantId,
      'answer': answer,
    });
  }

  void sendIceCandidate({
    required String meetingId,
    required String toParticipantId,
    required Map<String, dynamic> candidate,
  }) {
    _socket!.emit('ice-candidate', {
      'meetingId': meetingId,
      'toParticipantId': toParticipantId,
      'candidate': candidate,
    });
  }

  void leaveMeeting({
    required String meetingId,
    required String participantId,
  }) {
    print('Leaving meeting: $meetingId');
    _socket!.emit('leave-meeting', {
      'meetingId': meetingId,
      'participantId': participantId,
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _isConnected = false;
  }

  bool get isConnected => _isConnected;
}
