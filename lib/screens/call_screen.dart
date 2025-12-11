import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../models/call_model.dart';
import '../models/user_model.dart';
import '../services/webrtc_service.dart';
import '../services/socket_signaling_service.dart';
import '../services/firebase_service.dart';

class CallScreen extends StatefulWidget {
  final Meeting meeting;
  final String participantId;
  final String participantName;
  final bool isHost;

  const CallScreen({
    Key? key,
    required this.meeting,
    required this.participantId,
    required this.participantName,
    required this.isHost,
  }) : super(key: key);

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final WebRTCService _webrtcService = WebRTCService();
  final SocketSignalingService _socketService = SocketSignalingService();
  final FirebaseService _firebaseService = FirebaseService();

  bool _isAudioOn = true;
  bool _isVideoOn = true;
  bool _isConnecting = true;
  Timer? _callTimer;
  int _callDuration = 0;

  @override
  void initState() {
    super.initState();
    _initializeCall();
  }

  Future<void> _initializeCall() async {
    await _webrtcService.initialize();
    await _webrtcService.startLocalStream();
    await _firebaseService.updateMeetingStatus(widget.meeting.meetingId, MeetingStatus.active);
    
    // Connect to Socket.IO server
    await _socketService.connect();
    
    // Wait for connection
    await Future.delayed(Duration(milliseconds: 500));
    
    // Join the meeting room
    _socketService.joinMeeting(
      meetingId: widget.meeting.meetingId,
      participantId: widget.participantId,
      participantName: widget.participantName,
      isHost: widget.isHost,
    );
    
    await _setupWebRTC();
    _startCallTimer();
  }

  String? _connectedParticipantId;

  Future<void> _setupWebRTC() async {
    // Set up Socket.IO event listeners
    _socketService.onParticipantJoined = (data) async {
      final participantId = data['participantId'];
      final participantName = data['participantName'];
      final isHost = data['isHost'] ?? false;
      
      print('✅ Participant joined: $participantName ($participantId)');
      
      // If I'm the host and a joiner joined, send them an offer
      if (widget.isHost && !isHost && _connectedParticipantId == null) {
        _connectedParticipantId = participantId;
        await _sendOfferToParticipant(participantId);
      }
    };

    _socketService.onExistingParticipants = (participants) async {
      print('📋 Existing participants: ${participants.length}');
      
      // If I'm a joiner and there's a host, wait for their offer
      if (!widget.isHost && participants.isNotEmpty) {
        for (var p in participants) {
          if (p['isHost'] == true) {
            _connectedParticipantId = p['participantId'];
            print('🎯 Found host: ${p['participantName']}');
            break;
          }
        }
      }
    };

    _socketService.onOffer = (data) async {
      print('📨 Received offer from ${data['fromParticipantName']}');
      final offer = data['offer'];
      _connectedParticipantId = data['fromParticipantId'];
      
      await _webrtcService.setRemoteDescription(offer);
      
      // Set up ICE candidate callback
      _webrtcService.setOnIceCandidate((candidate) {
        _socketService.sendIceCandidate(
          meetingId: widget.meeting.meetingId,
          toParticipantId: _connectedParticipantId!,
          candidate: candidate,
        );
      });
      
      final answer = await _webrtcService.createAnswer(widget.meeting.meetingId);
      _socketService.sendAnswer(
        meetingId: widget.meeting.meetingId,
        toParticipantId: _connectedParticipantId!,
        answer: answer,
      );
      
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    };

    _socketService.onAnswer = (data) async {
      print('✅ Received answer from ${data['fromParticipantId']}');
      final answer = data['answer'];
      
      await _webrtcService.setRemoteDescription(answer);
      
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    };

    _socketService.onIceCandidate = (data) async {
      print('🧊 Received ICE candidate from ${data['fromParticipantId']}');
      final candidate = data['candidate'];
      await _webrtcService.addIceCandidate(candidate);
    };

    _socketService.onParticipantLeft = (data) {
      print('👋 Participant left: ${data['participantName']}');
      if (mounted) {
        setState(() => _isConnecting = true);
      }
    };
  }

  Future<void> _sendOfferToParticipant(String participantId) async {
    print('📤 Sending offer to participant: $participantId');
    
    // Set up ICE candidate callback
    _webrtcService.setOnIceCandidate((candidate) {
      _socketService.sendIceCandidate(
        meetingId: widget.meeting.meetingId,
        toParticipantId: participantId,
        candidate: candidate,
      );
    });
    
    final offer = await _webrtcService.createOffer(widget.meeting.meetingId);
    _socketService.sendOffer(
      meetingId: widget.meeting.meetingId,
      toParticipantId: participantId,
      offer: offer,
    );
  }

  void _startCallTimer() {
    _callTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() => _callDuration++);
    });
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  void _toggleAudio() {
    _webrtcService.toggleAudio();
    setState(() => _isAudioOn = !_isAudioOn);
  }

  void _toggleVideo() {
    _webrtcService.toggleVideo();
    setState(() => _isVideoOn = !_isVideoOn);
  }

  void _switchCamera() {
    _webrtcService.switchCamera();
  }

  Future<void> _endCall() async {
    _callTimer?.cancel();
    
    // Leave Socket.IO room
    _socketService.leaveMeeting(
      meetingId: widget.meeting.meetingId,
      participantId: widget.participantId,
    );
    
    if (widget.isHost) {
      await _firebaseService.endMeeting(widget.meeting.meetingId);
    } else {
      await _firebaseService.removeParticipant(
        widget.meeting.meetingId,
        widget.participantId,
      );
    }
    
    await _webrtcService.dispose();
    
    if (mounted) {
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Remote video (full screen)
          RTCVideoView(
            _webrtcService.remoteRenderer,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          ),

          // Local video (small preview)
          Positioned(
            top: 50,
            right: 20,
            child: Container(
              width: 120,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: RTCVideoView(
                  _webrtcService.localRenderer,
                  mirror: true,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
            ),
          ),

          // Top info bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
              child: Column(
                children: [
                  Text(
                    widget.meeting.meetingId,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _isConnecting ? 'Connecting...' : _formatDuration(_callDuration),
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 4),
                  StreamBuilder<List<Participant>>(
                    stream: _firebaseService.getParticipants(widget.meeting.meetingId),
                    builder: (context, snapshot) {
                      final count = snapshot.data?.length ?? 1;
                      return Text(
                        '$count participant${count > 1 ? 's' : ''}',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 14,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 40),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildControlButton(
                    icon: _isAudioOn ? Icons.mic : Icons.mic_off,
                    onPressed: _toggleAudio,
                    backgroundColor: _isAudioOn ? Colors.white24 : Colors.red,
                  ),
                  _buildControlButton(
                    icon: _isVideoOn ? Icons.videocam : Icons.videocam_off,
                    onPressed: _toggleVideo,
                    backgroundColor: _isVideoOn ? Colors.white24 : Colors.red,
                  ),
                  _buildControlButton(
                    icon: Icons.cameraswitch,
                    onPressed: _switchCamera,
                    backgroundColor: Colors.white24,
                  ),
                  _buildControlButton(
                    icon: Icons.call_end,
                    onPressed: _endCall,
                    backgroundColor: Colors.red,
                    size: 64,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color backgroundColor,
    double size = 56,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        iconSize: size * 0.5,
        onPressed: onPressed,
      ),
    );
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _webrtcService.dispose();
    super.dispose();
  }
}
