import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SplitRequestsPage extends StatefulWidget {
  @override
  _SplitRequestsPageState createState() => _SplitRequestsPageState();
}

class _SplitRequestsPageState extends State<SplitRequestsPage> {
  List<DocumentSnapshot> _receivedRequests = [];

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        final userSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        final currentUsername = userSnapshot.data()?['username'];

        // Fetch received requests (requests where the current user is the recipient)
        final receivedSnapshot = await FirebaseFirestore.instance
            .collection('split_requests')
            .where('to', isEqualTo: currentUsername)
            .get();


        setState(() {
          _receivedRequests = receivedSnapshot.docs;
        });
      } catch (e) {
        print('Failed to fetch split requests: $e');
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error fetching split requests')));
      }
    }
  }

  Future<String?> _getUserNameById(String userId) async {
    try {
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      return userSnapshot.data()?['username'];
    } catch (e) {
      print('Error fetching user name: $e');
      return null;
    }
  }

  Future<void> _approveRequest(String requestId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        await FirebaseFirestore.instance.collection('split_requests').doc(requestId).update({
          'status': 'approved',
        });
        setState(() {});

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Split request approved')));
      } catch (e) {
        print('Failed to approve split request: $e');
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to approve request')));
      }
    }
  }

  // Future<void> _askForApproval(String requestId) async {
  //   try {
  //     await FirebaseFirestore.instance.collection('split_requests').doc(requestId).update({
  //       'approvalRequested': true,
  //     });

  //     ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('Asked for approval')));
  //   } catch (e) {
  //     print('Failed to ask for approval: $e');
  //     ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('Failed to ask for approval')));
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Split Requests'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Received requests
            ListView(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              children: _receivedRequests.map((request) {
                return FutureBuilder<String?>(
                  future: _getUserNameById(request['from']),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return ListTile(
                        title: Text('Loading...'),
                      );
                    } else if (snapshot.hasError) {
                      return ListTile(
                        title: Text('Error loading sender'),
                      );
                    }

                    final senderName = snapshot.data ?? 'Unknown';
                    return ListTile(
  title: Text('From: $senderName'),
  subtitle: Text('Amount: \$${request['amount']}'),
  trailing: Builder(
    builder: (context) {
      if (request['status'] == 'pending') {
        return ElevatedButton(
          onPressed: () => _approveRequest(request.id),
          child: Text('Ask Approval'),
        );
      } else {
        return SizedBox.shrink(); // Return an empty widget if condition is not met
      }
    },
  ),
);

                  },
                );
              }).toList(),
            ),
            // Sent requests
            // ListView(
            //   shrinkWrap: true,
            //   physics: NeverScrollableScrollPhysics(),
            //   children: _sentRequests.map((request) {
            //     final data = request.data() as Map<String, dynamic>?;

            //     return FutureBuilder<String?>(
            //       future: _getUserNameById(request['to']),
            //       builder: (context, snapshot) {
            //         if (snapshot.connectionState == ConnectionState.waiting) {
            //           return ListTile(
            //             title: Text('Loading...'),
            //           );
            //         } else if (snapshot.hasError) {
            //           return ListTile(
            //             title: Text('Error loading recipient'),
            //           );
            //         }

            //         final recipientName = snapshot.data ?? 'Unknown';
            //         bool approvalRequested = data?['approvalRequested'] ?? false;

            //         return ListTile(
            //           title: Text('To: $recipientName'),
            //           subtitle: Text('Amount: \$${request['amount']}'),
            //           trailing: Column(
            //             crossAxisAlignment: CrossAxisAlignment.start,
            //             children: [
            //               Text('Status: ${request['status']}'),
            //               if (request['status'] == 'pending' && !approvalRequested)
            //                 ElevatedButton(
            //                   onPressed: () => _askForApproval(request.id),
            //                   child: Text('Ask for Approval'),
            //                 ),
            //               if (request['status'] == 'pending')
            //                 ElevatedButton(
            //                   onPressed: () => _cancelRequest(request.id),
            //                   child: Text('Cancel'),
            //                 ),
            //             ],
            //           ),
            //         );
            //       },
            //     );
            //   }).toList(),
            // ),
          ],
        ),
      ),
    );
  }
}
