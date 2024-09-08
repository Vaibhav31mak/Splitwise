import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddFriendPage extends StatefulWidget {
  @override
  _AddFriendPageState createState() => _AddFriendPageState();
}

class _AddFriendPageState extends State<AddFriendPage> {
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _users = [];
  List<DocumentSnapshot> _filteredUsers = [];
  final ValueNotifier<List<DocumentSnapshot>> _filteredUsersNotifier = ValueNotifier([]);

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('users').get();
      setState(() {
        _users = snapshot.docs;
        _filteredUsers = _users;
        _filteredUsersNotifier.value = _filteredUsers;
      });

      // Debugging: Print the fetched users to check the data
      print('Fetched users: $_users');
    } catch (e) {
      print('Failed to fetch users: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching users')));
    }
  }

  void _searchUser(String query) {
    final filteredUsers = query.isEmpty
        ? _users // Display all users if no search query
        : _users.where((user) {
            final username = user['username']?.toString().toLowerCase() ?? '';
            final searchLower = query.toLowerCase();
            return username.contains(searchLower);
          }).toList();

    setState(() {
      _filteredUsers = filteredUsers;
      _filteredUsersNotifier.value = _filteredUsers;
    });

    // Debugging: Print the filtered users to check the results
    print('Filtered users: $_filteredUsers');
  }

  void _sendFriendRequest(String userId, String username) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        // Send a friend request
        await FirebaseFirestore.instance.collection('friend_requests').add({
          'from': currentUser.uid,
          'to': userId,
          'fromName': currentUser.displayName ?? 'No Name',
          'status': 'pending',
          'timestamp': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Friend request sent')));
      } catch (e) {
        print('Failed to send friend request: $e');
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to send request')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Friend'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by username',
                border: OutlineInputBorder(),
              ),
              onChanged: _searchUser,
            ),
          ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: _filteredUsersNotifier,
              builder: (context, value, child) {
                return ListView.builder(
                  itemCount: value.length,
                  itemBuilder: (context, index) {
                    final user = value[index];
                    return ListTile(
                      title: Text(user['username'] ?? 'No Username'),
                      trailing: IconButton(
                        icon: Icon(Icons.person_add),
                        onPressed: () => _sendFriendRequest(user.id, user['username'] ?? 'No Username'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
