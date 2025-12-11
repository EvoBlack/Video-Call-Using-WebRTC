import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/call_model.dart';
import 'waiting_room_screen.dart';

class JoinMeetingScreen extends StatefulWidget {
  final String participantName;

  const JoinMeetingScreen({
    Key? key,
    required this.participantName,
  }) : super(key: key);

  @override
  State<JoinMeetingScreen> createState() => _JoinMeetingScreenState();
}

class _JoinMeetingScreenState extends State<JoinMeetingScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _meetingIdController = TextEditingController();
  bool _isJoining = false;

  Future<void> _joinMeeting() async {
    final meetingId = _meetingIdController.text.trim();
    
    if (meetingId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter meeting ID')),
      );
      return;
    }

    setState(() => _isJoining = true);

    try {
      print('Attempting to join meeting: $meetingId');
      final meeting = await _firebaseService.getMeeting(meetingId);

      if (meeting == null) {
        print('Meeting not found in database: $meetingId');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Meeting not found. Please check the ID.')),
          );
        }
        setState(() => _isJoining = false);
        return;
      }

      print('Meeting found: ${meeting.meetingId}, Status: ${meeting.status}');

      if (meeting.status == MeetingStatus.ended) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('This meeting has ended')),
          );
        }
        setState(() => _isJoining = false);
        return;
      }

      final participantId = DateTime.now().millisecondsSinceEpoch.toString();
      print('Joining as participant: $participantId');

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => WaitingRoomScreen(
              meeting: meeting,
              participantName: widget.participantName,
              participantId: participantId,
              isHost: false,
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('Error joining meeting: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join meeting: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Join Meeting'),
      ),
      body: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.meeting_room,
              size: 80,
              color: Colors.blue,
            ),
            SizedBox(height: 32),
            Text(
              'Enter Meeting ID',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Joining as: ${widget.participantName}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 48),
            TextField(
              controller: _meetingIdController,
              decoration: InputDecoration(
                labelText: 'Meeting ID',
                hintText: '123-456-789',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(Icons.tag),
              ),
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isJoining ? null : _joinMeeting,
              child: _isJoining
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Join Meeting',
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
    _meetingIdController.dispose();
    super.dispose();
  }
}
