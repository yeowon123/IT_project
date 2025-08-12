// lib/utils/user_handle.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// 이메일 @ 앞부분을 정규화해 문서 ID로 사용
String toHandle(String email) {
  var local = email.split('@').first.toLowerCase().trim();
  return local.replaceAll(RegExp(r'[^a-z0-9._-]'), '_');
}

/// 현재 로그인 사용자의 users/{handle} 참조
Future<DocumentReference<Map<String, dynamic>>> userDocByHandle() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null || user.email == null) {
    throw Exception('로그인이 필요합니다.');
  }
  final handle = toHandle(user.email!);
  return FirebaseFirestore.instance.collection('users').doc(handle);
}

/// (규칙 강화 대비) handles/{handle} 선점
Future<void> ensureHandleClaimed() async {
  final user = FirebaseAuth.instance.currentUser!;
  final email = user.email!;
  final uid = user.uid;
  final handle = toHandle(email);

  final db = FirebaseFirestore.instance;
  await db.runTransaction((tx) async {
    final hRef = db.collection('handles').doc(handle);
    final snap = await tx.get(hRef);
    if (snap.exists) {
      if (snap.data()?['uid'] != uid) {
        throw Exception('이미 다른 계정이 사용하는 handle 입니다.');
      }
    } else {
      tx.set(hRef, {
        'uid': uid,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  });
}