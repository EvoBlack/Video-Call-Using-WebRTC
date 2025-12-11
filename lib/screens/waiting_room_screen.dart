import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/call_model.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';
import 'call_screen.dart';

class WaitingRoomScreen extends StatefulWidget {
  final Meeting meeting;
  final String participantName;
  final String participantId;
  final bool isHost;

  const WaitingRoomScreen({
    Key? key,
    required this.meeting,
    required this.participantName,
    required this.participantId,
    required this.isHost,
  }) : super(key: key);

  @override
  State<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends State<WaitingRoomScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    if (!widget.isHost) {
      _joinMeeting();
    }
  }

  Future<void> _joinMeeting() async {
    await _firebaseService.addParticipant(
      widget.meeting.meetingId,
      widget.participantId,
      widget.participantName,
      false,
    );
  }

  void _copyMeetingId() {
    Clipboard.setData(ClipboardData(text: widget.meeting.meetingId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Meeting ID copied to clipboard')),
    );
  }

  void _copyMeetingLink() {
    Clipboard.setData(ClipboardData(text: widget.meeting.meetingLink));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Meeting link copied to clipboard')),
    );
  }

  void _startMeeting() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => CallScreen(
          meeting: widget.meeting,
          participantId: widget.participantId,
          participantName: widget.participantName,
          isHost: widget.isHost,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Waiting Room'),
        actions: [
          if (widget.isHost)
            IconButton(
              icon: Icon(Icons.close),
              onPressed: () async {
                await _firebaseService.endMeeting(widget.meeting.meetingId);
                Navigator.pop(context);
              },
            ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.video_call,
                      size: 64,
                      color: Colors.blue,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Meeting ID',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      widget.meeting.meetingId,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _copyMeetingId,
                          icon: Icon(Icons.copy),
                          label: Text('Copy ID'),
                        ),
                        SizedBox(width: 16),
                        OutlinedButton.icon(
                          onPressed: _copyMeetingLink,
                          icon: Icon(Icons.link),
                          label: Text('Copy Link'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Participants',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<Participant>>(
                stream: _firebaseService.getParticipants(widget.meeting.meetingId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Text('No participants yet'),
                    );
                  }

                  final participants = snapshot.data!;

                  return ListView.builder(
                    itemCount: participants.length,
                    itemBuilder: (context, index) {
                      final participant = participants[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              participant.name[0].toUpperCase(),
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(participant.name),
                          subtitle: Text(
                            participant.isHost ? 'Host' : 'Participant',
                          ),
                          trailing: participant.isHost
                              ? Icon(Icons.star, color: Colors.amber)
                              : null,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _startMeeting,
              icon: Icon(Icons.videocam),
              label: Text(
                widget.isHost ? 'Start Meeting' : 'Join Meeting',
                style: TextStyle(fontSize: 18),
              ),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (!widget.isHost) {
      _firebaseService.removeParticipant(
        widget.meeting.meetingId,
        widget.participantId,
      );
    }
    super.dispose();
  }
}
