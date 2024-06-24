import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:sillaraiadmin/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Coins Admin',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Coins App Admin'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>>
      _fetchUsersWithLatestRequestTimestamp() async {
    QuerySnapshot userSnapshot = await _firestore.collection('users').get();

    List<Map<String, dynamic>> usersWithTimestamp = [];

    for (var user in userSnapshot.docs) {
      QuerySnapshot requestSnapshot = await user.reference
          .collection('requests')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      Timestamp? latestRequestTimestamp;
      if (requestSnapshot.docs.isNotEmpty) {
        latestRequestTimestamp = requestSnapshot.docs.first.get('timestamp');
      }

      usersWithTimestamp.add({
        'user': user,
        'latestRequestTimestamp': latestRequestTimestamp,
      });
    }

    // Sort users based on latestRequestTimestamp
    usersWithTimestamp.sort((a, b) {
      Timestamp? timestampA = a['latestRequestTimestamp'];
      Timestamp? timestampB = b['latestRequestTimestamp'];
      if (timestampA == null && timestampB == null) return 0;
      if (timestampA == null) return 1;
      if (timestampB == null) return -1;
      return timestampB.compareTo(timestampA);
    });

    return usersWithTimestamp;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchUsersWithLatestRequestTimestamp(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No users found'));
          }
          final users = snapshot.data!;
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index]['user'];
              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🙍 ' + (user['userName'] ?? 'No Name'),
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '📱 ' + (user['mobileNumber'] ?? 'No Mobile Number'),
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '🏠 ' + (user['address'] ?? 'No Address'),
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  trailing: Icon(Icons.visibility, color: Colors.teal),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserRequestsPage(
                          userId: user.id,
                          mobileNumber: user['mobileNumber'],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class UserRequestsPage extends StatefulWidget {
  final String userId;
  final String mobileNumber;

  const UserRequestsPage({
    Key? key,
    required this.userId,
    required this.mobileNumber,
  }) : super(key: key);

  @override
  _UserRequestsPageState createState() => _UserRequestsPageState();
}

class _UserRequestsPageState extends State<UserRequestsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;

  // Function to delete a request
  Future<void> deleteRequest(String requestId) async {
    try {
      await _firestore
          .collection('users')
          .doc(widget.userId)
          .collection('requests')
          .doc(requestId)
          .delete();

      // Show Snackbar after successful deletion
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: Duration(seconds: 2),
          content: Text('Request deleted successfully'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      print('Error deleting request: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    // Introduce delay to simulate loading
    Future.delayed(Duration(seconds: 1), () {
      setState(() {
        _isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Requests for ${widget.mobileNumber}'),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('users')
                  .doc(widget.userId)
                  .collection('requests')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('No requests found'));
                }
                final requests = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final request = requests[index];
                    final requestId = request.id;
                    final requestData = request.data() as Map<String, dynamic>;

                    // Convert timestamp to DateTime
                    Timestamp timestamp = requestData['timestamp'];
                    DateTime dateTime = timestamp.toDate();

                    // Format DateTime using intl package
                    String formattedDate =
                        DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);

                    String selectedStatus =
                        requestData['status'] ?? 'Pending'; // Default status

                    return Card(
                      margin: const EdgeInsets.all(8.0),
                      child: ListTile(
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Type: ${requestData['requestType']}'),
                            Text('Amount: ${requestData['amount']}'),
                            Text('Time: $formattedDate'),
                            Row(
                              children: [
                                Text('Status'),
                                SizedBox(width: 10),
                                Container(
                                  color: Colors.grey.shade200,
                                  child: DropdownButton<String>(
                                    value: selectedStatus,
                                    items: <String>[
                                      'Pending',
                                      'Paid',
                                      'Completed'
                                    ].map((String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      );
                                    }).toList(),
                                    onChanged: (String? newValue) {
                                      setState(() {
                                        selectedStatus = newValue!;
                                        // Update status in Firestore for the particular request
                                        request.reference
                                            .update({'status': selectedStatus});
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text('Delete Request'),
                                content: Text(
                                    'Are you sure you want to delete this request?'),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                    child: Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      // Call deleteRequest function to delete the request
                                      deleteRequest(requestId);
                                      Navigator.pop(context);
                                    },
                                    child: Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
