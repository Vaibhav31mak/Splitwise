import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_friend_page.dart';
import 'friends_page.dart';
import 'bill_split_screen.dart';
import 'bill_requests_page.dart';
import 'split_requested_page.dart';
class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<DocumentSnapshot> _friendRequests = [];

  @override
  void initState() {
    super.initState();
    _fetchFriendRequests();
  }

  Future<void> _fetchFriendRequests() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('friend_requests')
          .where('to', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'pending')
          .get();
      setState(() {
        _friendRequests = snapshot.docs;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Home Page'),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => BillSplitScreen()),
                );
              },
              child: Text('Split Expense'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SplitRequestsPage()),
                );
              },
              child: Text('View Split Requests'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SplitRequestedPage()),
                );
              },
              child: Text('View Splits Requested'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AddFriendPage()),
                );
              },
              child: Text('Add Friend'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => FriendRequestsPage(friendRequests: _friendRequests, onAccept: _fetchFriendRequests)),
                );
              },
              child: Text('Friend Requests'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => FriendsPage()),
                );
              },
              child: Text('Friends'),
            ),
          ],
        ),
      ),
    );
  }
}
class FriendRequestsPage extends StatelessWidget {
  final List<DocumentSnapshot> friendRequests;
  final Function onAccept;

  FriendRequestsPage({required this.friendRequests, required this.onAccept});

  Future<void> _acceptFriendRequest(BuildContext context, String requestId, String fromId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        // Add the friend to both users' friends lists
        await FirebaseFirestore.instance.collection('friends').doc(currentUser.uid).set({
          'friends': FieldValue.arrayUnion([fromId]),
        }, SetOptions(merge: true));

        await FirebaseFirestore.instance.collection('friends').doc(fromId).set({
          'friends': FieldValue.arrayUnion([currentUser.uid]),
        }, SetOptions(merge: true));

        // Update the friend request status
        await FirebaseFirestore.instance.collection('friend_requests').doc(requestId).update({
          'status': 'accepted',
        });

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Friend request accepted')));
        onAccept(); // Refresh friend requests after accepting
      } catch (e) {
        print('Failed to accept friend request: $e');
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to accept request')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Friend Requests'),
      ),
      body: ListView.builder(
        itemCount: friendRequests.length,
        itemBuilder: (context, index) {
          final request = friendRequests[index];
          return ListTile(
            title: Text('${request['fromName']} sent you a friend request'),
            trailing: ElevatedButton(
              onPressed: () {
                _acceptFriendRequest(context, request.id, request['from']);
              },
              child: Text('Accept'),
            ),
          );
        },
      ),
    );
  }
}

