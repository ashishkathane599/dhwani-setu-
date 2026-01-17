import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TransactionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. Find a user by Name (Simplification for Voice Command)
  Future<DocumentSnapshot?> findUserByName(String name) async {
    final querySnapshot = await _db
        .collection('users')
        .where('name', isEqualTo: name)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) return null;
    return querySnapshot.docs.first;
  }

  // 2. ATOMIC TRANSFER Logic
  Future<String> executeTransfer({required String receiverUid, required double amount}) async {
    final senderUid = _auth.currentUser!.uid;
    final senderRef = _db.collection('users').doc(senderUid);
    final receiverRef = _db.collection('users').doc(receiverUid);
    final txnRef = _db.collection('transactions').doc();

    try {
      await _db.runTransaction((transaction) async {
        final senderSnapshot = await transaction.get(senderRef);
        final receiverSnapshot = await transaction.get(receiverRef);

        if (!senderSnapshot.exists) throw Exception("Sender account not found");
        if (!receiverSnapshot.exists) throw Exception("Receiver account not found");

        final senderBalance = senderSnapshot.data()?['balance'] ?? 0;
        
        // Check Sufficiency
        if (senderBalance < amount) {
          throw Exception("Insufficient Funds");
        }

        // DEDUCT from Sender
        transaction.update(senderRef, {'balance': senderBalance - amount});

        // ADD to Receiver
        final receiverBalance = receiverSnapshot.data()?['balance'] ?? 0;
        transaction.update(receiverRef, {'balance': receiverBalance + amount});

        // LOG Transaction
        transaction.set(txnRef, {
          'from_uid': senderUid,
          'to_uid': receiverUid,
          'amount': amount,
          'type': 'transfer',
          'status': 'success',
          'timestamp': FieldValue.serverTimestamp(),
        });
      });

      return "Success";
    } catch (e) {
      return "Failed: ${e.toString()}";
    }
  }
}