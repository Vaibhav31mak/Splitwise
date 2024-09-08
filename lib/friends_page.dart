// lib/friends_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendsPage extends StatefulWidget {
  @override
  _FriendsPageState createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  List<DocumentSnapshot<Map<String, dynamic>>> _friends = [];

  @override
  void initState() {
    super.initState();
    _fetchFriends();
  }

  Future<void> _fetchFriends() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != null) {
      try {
        // Fetch the user's friends list document
        final DocumentSnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore.instance
            .collection('friends')
            .doc(currentUserId)
            .get();

        final List<String> friendIds = List.from(snapshot.data()?['friends'] ?? []);
        
        // Fetch friend details
        final List<DocumentSnapshot<Map<String, dynamic>>> friendDocs = [];
        for (final friendId in friendIds) {
          final DocumentSnapshot<Map<String, dynamic>> friendDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(friendId)
              .get();
          friendDocs.add(friendDoc);
        }

        setState(() {
          _friends = friendDocs;
        });

      } catch (e) {
        print('Failed to fetch friends: $e');
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error fetching friends')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Friends'),
      ),
      body: ListView.builder(
        itemCount: _friends.length,
        itemBuilder: (context, index) {
          final friend = _friends[index].data();
          return ListTile(
            title: Text(friend?['username'] ?? 'No Username'),
            subtitle: Text(friend?['email'] ?? 'No Email'),
          );
        },
      ),
    );
  }
}
