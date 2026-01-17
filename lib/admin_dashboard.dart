import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("DhwaniSetu Admin Panel")),
      body: Row(
        children: [
          // Sidebar
          NavigationRail(
            selectedIndex: 0,
            destinations: [
              NavigationRailDestination(icon: Icon(Icons.dashboard), label: Text("Home")),
              NavigationRailDestination(icon: Icon(Icons.people), label: Text("Users")),
            ], 
            onDestinationSelected: (val) {},
          ),
          
          // Main Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Recent Transactions", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  Divider(),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      // Listen to transactions in real-time
                      stream: FirebaseFirestore.instance.collection('transactions').orderBy('timestamp', descending: true).snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) return Text("Error: ${snapshot.error}");
                        if (!snapshot.hasData) return LinearProgressIndicator();
                        
                        return DataTable(
                          columns: [
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