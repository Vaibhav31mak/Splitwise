import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SplitRequestedPage extends StatefulWidget {
  @override
  _SplitRequestedPageState createState() => _SplitRequestedPageState();
}

class _SplitRequestedPageState extends State<SplitRequestedPage> {
  List<DocumentSnapshot<Object?>> _sentRequests = [];

  @override
  void initState() {
    super.initState();
    _fetchSentRequests();
  }

  Future<void> _fetchSentRequests() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('split_requests')
            .where('from', isEqualTo: currentUser.uid)
            .get();

        setState(() {
          _sentRequests = snapshot.docs;
        });
      } catch (e) {
        print('Failed to fetch split requests: $e');
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error fetching split requests')));
      }
    }
  }

  Future<void> _cancelRequest(String requestId) async {
  try {
    // Delete the request from Firestore
    await FirebaseFirestore.instance.collection('split_requests').doc(requestId).delete();

    setState(() {
      // Remove the request from the list displayed in the UI
      _sentRequests.removeWhere((doc) => doc.id == requestId);
    });

    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Split request cancelled')));
  } catch (e) {
    print('Failed to cancel split request: $e');
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel request')));
  }
}


  Future<void> _denyRequest(String requestId) async {
    try {
      // Update the request status to 'pending'
      await FirebaseFirestore.instance.collection('split_requests').doc(requestId).update({
        'status': 'pending',
      });

      setState(() {
        // Update the request in the list to reflect the change
        final index = _sentRequests.indexWhere((doc) => doc.id == requestId);
        if (index != -1) {
          // Refresh the list by re-fetching the data
          _fetchSentRequests();
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Split request denied')));
    } catch (e) {
      print('Failed to deny split request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to deny request')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Split Requests'),
      ),
      body: ListView(
        children: _sentRequests.map((request) {
          final data = request.data() as Map<String, dynamic>?;

          return ListTile(
            title: Text('To: ${data?['to'] ?? 'Unknown'}'),
            subtitle: Text('Amount: \$${data?['amount'] ?? 0}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (data?['status'] == 'approved')
                  ElevatedButton(
                    onPressed: () => _denyRequest(request.id),
                    child: Text('Deny'),
                  ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _cancelRequest(request.id),
                  child: Text('Cancel'),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
