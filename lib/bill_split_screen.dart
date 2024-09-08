import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BillSplitScreen extends StatefulWidget {
  @override
  _BillSplitScreenState createState() => _BillSplitScreenState();
}

class _BillSplitScreenState extends State<BillSplitScreen> {
  List<String> _friends = []; // List to hold friend names
  List<String> _selectedFriends = []; // List of selected friends for splitting
  Map<String, TextEditingController> _amountControllers = {}; // Map to hold TextEditingControllers for amounts
  double _totalBill = 0.0;
  Map<String, double> _balances = {};

  @override
  void initState() {
    super.initState();
    _fetchFriends();
  }

  Future<void> _fetchFriends() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != null) {
      try {
        // Fetch the user's friend list
        final DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
            .collection('friends')
            .doc(currentUserId)
            .get();

        final List<String> friendIds = List<String>.from((userSnapshot.data() as Map<String, dynamic>)['friends'] ?? []);

        final List<String> friendNames = [];

        // Fetch friend details
        for (final friendId in friendIds) {
          final friendDoc = await FirebaseFirestore.instance.collection('users').doc(friendId).get();
          friendNames.add(friendDoc.data()?['username'] ?? 'No Username');
        }

        setState(() {
          _friends = friendNames;
        });

      } catch (e) {
        print('Failed to fetch friends: $e');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching friends')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bill Splitter'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Input for Total Bill
              TextField(
                decoration: InputDecoration(labelText: 'Total Bill Amount'),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {
                    _totalBill = double.tryParse(value) ?? 0.0;
                  });
                },
              ),
              SizedBox(height: 20),
              Text('Select Friends to Split', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

              // Display a list of friends to select and input amount
              _friends.isNotEmpty
                  ? Column(
                      children: _friends.map((friend) {
                        bool isSelected = _selectedFriends.contains(friend);
                        return Column(
                          children: [
                            CheckboxListTile(
                              title: Text(friend),
                              value: isSelected,
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedFriends.add(friend);
                                    _amountControllers[friend] = TextEditingController();
                                  } else {
                                    _selectedFriends.remove(friend);
                                    _amountControllers.remove(friend)?.dispose();
                                  }
                                });
                              },
                            ),
                            if (isSelected)
                              TextField(
                                controller: _amountControllers[friend],
                                decoration: InputDecoration(
                                  labelText: 'Amount for $friend',
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            SizedBox(height: 10),
                          ],
                        );
                      }).toList(),
                    )
                  : Center(child: CircularProgressIndicator()),

              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _selectedFriends.isEmpty ? null : _splitBill,
                child: Text('Split Bill'),
              ),
              SizedBox(height: 20),
              _balances.isNotEmpty ? _buildBalancesView() : Container(),
            ],
          ),
        ),
      ),
    );
  }

  void _splitBill() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && _selectedFriends.isNotEmpty) {
      double totalOwed = 0.0;
      Map<String, double> amountsOwed = {};
      List<String> friendsWithoutAmount = [];
      double remainingAmount = _totalBill;

      // Calculate amounts for friends with specified amounts
      for (String friend in _selectedFriends) {
        String? amountText = _amountControllers[friend]?.text;
        double amountOwed = double.tryParse(amountText ?? '') ?? 0.0;

        if (amountText != null && amountText.isNotEmpty) {
          // Update total owed and reduce remaining amount
          amountsOwed[friend] = amountOwed;
          totalOwed += amountOwed;
          remainingAmount -= amountOwed;
        } else {
          // Collect friends without specified amount
          friendsWithoutAmount.add(friend);
        }
      }

      // Calculate split amount for friends without specified amounts
      if (friendsWithoutAmount.isNotEmpty) {
        double splitAmount = remainingAmount / friendsWithoutAmount.length;

        // Create split requests for friends with specified amounts
        for (String friend in amountsOwed.keys) {
          try {
            await FirebaseFirestore.instance.collection('split_requests').add({
              'from': currentUser.uid,
              'to': friend,
              'amount': amountsOwed[friend]!,
              'status': 'pending',
              'timestamp': FieldValue.serverTimestamp(),
              'description': 'Bill Split',
            });
          } catch (e) {
            print('Failed to send split request: $e');
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send split request')));
          }
        }

        // Create split requests for friends without specified amounts
        for (String friend in friendsWithoutAmount) {
          try {
            await FirebaseFirestore.instance.collection('split_requests').add({
              'from': currentUser.uid,
              'to': friend,
              'amount': splitAmount,
              'status': 'pending',
              'timestamp': FieldValue.serverTimestamp(),
              'description': 'Bill Split',
            });
          } catch (e) {
            print('Failed to send split request: $e');
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send split request')));
          }
        }
      }

      // Update balances
      Map<String, double> balances = {};
      for (String friend in _selectedFriends) {
        double amountOwed = amountsOwed[friend] ?? (remainingAmount / friendsWithoutAmount.length);
        balances[friend] = amountOwed;
      }

      setState(() {
        _balances = balances;
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Split requests sent')));
    }
  }

  // Build a widget to show balances
  Widget _buildBalancesView() {
    return Column(
      children: _balances.entries.map((entry) {
        String name = entry.key;
        double balance = entry.value;
        String balanceText = balance > 0
            ? '$name should receive \$${balance.abs().toStringAsFixed(2)}'
            : '$name owes \$${balance.abs().toStringAsFixed(2)}';

        return Text(balanceText, style: TextStyle(fontSize: 16));
      }).toList(),
    );
  }
}
