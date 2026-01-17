import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart'; 
import 'voice_processor.dart';
import 'transaction_service.dart';

// NOTE: We removed the import for 'admin_dashboard.dart' 
// because we added the class at the bottom of this file.

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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => VoiceProcessor()),
        Provider(create: (_) => TransactionService()),
      ],
      child: MaterialApp(
        title: 'DhwaniSetu',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: LayoutBuilder(builder: (context, constraints) {
          // If the screen is wide (like a PC browser), show Admin Dashboard
          if (constraints.maxWidth > 800) {
            return AdminDashboard(); 
          }
          // Otherwise (mobile/narrow window), show the Voice App
          return const AuthWrapper(); 
        }),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    _signInAnonymously();
  }

  void _signInAnonymously() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      await FirebaseAuth.instance.signInAnonymously();
      if (FirebaseAuth.instance.currentUser != null) {
        String uid = FirebaseAuth.instance.currentUser!.uid;
        FirebaseFirestore.instance.collection('users').doc(uid).set({
          'name': 'User $uid', 
          'balance': 5000, 
          'phone': '9999999999'
        }, SetOptions(merge: true));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
      lowerBound: 0.8,
      upperBound: 1.0,
    )..repeat(reverse: true);
    
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      Provider.of<VoiceProcessor>(context, listen: false)
          .speak("Namaste. Main DhwaniSetu hoon. Bataiye kya karna hai?");
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleVoiceCommand(BuildContext context) async {
    final voice = Provider.of<VoiceProcessor>(context, listen: false);
    final txnService = Provider.of<TransactionService>(context, listen: false);

    await voice.listen(onResult: (command) async {
      if (!mounted) return;
      command = command.toLowerCase();
      
      if (command.contains("balance") || command.contains("paise")) {
        String uid = FirebaseAuth.instance.currentUser!.uid;
        var doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        int balance = doc.data()?['balance'] ?? 0;
        
        voice.setStatus(VoiceStatus.success);
        voice.speak("Aapke account mein $balance rupaye hain.");
      }
      else if (command.contains("bhejo") || command.contains("transfer")) {
        double? amount = voice.extractAmount(command);
        String? name = voice.extractName(command);

        if (amount != null && name != null) {
          voice.speak("$name ko $amount rupaye bhejne hain. Haan ya Na?");
          
          var receiverDoc = await txnService.findUserByName(name);
          if (receiverDoc == null) {
            voice.setStatus(VoiceStatus.error);
            voice.speak("Maaf kijiye, $name nahi mila.");
            return;
          }

          String result = await txnService.executeTransfer(
            receiverUid: receiverDoc.id, 
            amount: amount
          );

          if (result == "Success") {
             voice.setStatus(VoiceStatus.success);
             voice.speak("Paise bhej diye gaye hain.");
          } else {
             voice.setStatus(VoiceStatus.error);
             voice.speak("Transaction fail ho gaya.");
          }
        } else {
           voice.setStatus(VoiceStatus.error);
           voice.speak("Kitne paise aur kisko bhejne hain, samajh nahi aaya.");
        }
      } else {
        voice.setStatus(VoiceStatus.error);
        voice.speak("Maaf kijiye, samajh nahi aaya.");
      }
    });
  }

  Color _getStatusColor(VoiceStatus status) {
    switch (status) {
      case VoiceStatus.listening: return Colors.blue;
      case VoiceStatus.success: return Colors.green;
      case VoiceStatus.error: return Colors.red;
      default: return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = Provider.of<VoiceProcessor>(context).status;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              Provider.of<VoiceProcessor>(context).lastWords,
              style: const TextStyle(color: Colors.white, fontSize: 24),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 50),
            ScaleTransition(
              scale: _controller,
              child: GestureDetector(
                onTap: () => _handleVoiceCommand(context),
                child: Container(
                  height: 200,
                  width: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getStatusColor(status),
                    boxShadow: [
                      BoxShadow(
                        color: _getStatusColor(status).withOpacity(0.6),
                        blurRadius: 30,
                        spreadRadius: 10,
                      )
                    ]
                  ),
                  child: const Icon(Icons.mic, size: 80, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              "Bolne ke liye dabayein",
              style: TextStyle(color: Colors.white70, fontSize: 18),
            )
          ],
        ),
      ),
    );
  }
}

// --- ADMIN DASHBOARD CLASS ADDED HERE TO FIX IMPORT ISSUES ---

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("DhwaniSetu Admin Panel")),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: 0,
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.dashboard), label: Text("Home")),
              NavigationRailDestination(icon: Icon(Icons.people), label: Text("Users")),
            ], 
            onDestinationSelected: (val) {},
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Recent Transactions", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const Divider(),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('transactions').orderBy('timestamp', descending: true).snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) return Text("Error: ${snapshot.error}");
                        if (!snapshot.hasData) return const LinearProgressIndicator();
                        
                        return DataTable(
                          columns: const [
                            DataColumn(label: Text("Txn ID")),
                            DataColumn(label: Text("Amount")),
                            DataColumn(label: Text("Status")),
                          ],
                          rows: snapshot.data!.docs.map((doc) {
                            var data = doc.data() as Map<String, dynamic>;
                            return DataRow(cells: [
                              DataCell(Text(doc.id.substring(0, 8))),
                              DataCell(Text("₹${data['amount']}")),
                              DataCell(Text(data['status'])),
                            ]);
                          }).toList(),
                        );
                      },
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}