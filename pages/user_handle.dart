import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ★ 변경: 이메일이 없을 때(uid 기반)도 안전하게 핸들 생성
String _resolveHandle(User u) {
  final em = u.email;
  if (em != null && em.isNotEmpty) {
    final local = em.split('@').first.toLowerCase().trim();
    return local.replaceAll(RegExp(r'[^a-z0-9._-]'), '_');
  }
  return 'uid_${u.uid}';
}

User _requireUser() {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw FirebaseAuthException(
      code: 'not-authenticated',
      message: '로그인이 필요합니다.',
    );
  }
  return user;
}

// ★ 변경: 이메일 의존 제거(익명 로그인에서도 동작)
String currentHandle() => _resolveHandle(_requireUser());

// users/{handle}
DocumentReference<Map<String, dynamic>> userDocRef() =>
    FirebaseFirestore.instance.collection('users').doc(currentHandle());

// handles/{handle}
DocumentReference<Map<String, dynamic>> handleDocRef() =>
    FirebaseFirestore.instance.collection('handles').doc(currentHandle());

// 하위 컬렉션
CollectionReference<Map<String, dynamic>> favoritesCol() =>
    userDocRef().collection('favorites');
CollectionReference<Map<String, dynamic>> resultsCol() =>
    userDocRef().collection('results');

// ★ 변경: 앱 부팅 시 호출 → 핸들 점유 + users 루트 업서트
Future<void> ensureUserHandle() async {
  final u = _requireUser();
  final db = FirebaseFirestore.instance;
  final handle = currentHandle();

  await db.runTransaction((tx) async {
    final hRef = db.collection('handles').doc(handle);
    final snap = await tx.get(hRef);
    if (snap.exists) {
      final owner = snap.data()?['uid'] as String?;
      if (owner != null && owner != u.uid) {
        throw StateError('이미 다른 계정이 사용하는 handle 입니다.');
      }
      tx.set(hRef, {
        'uid': u.uid,
        'email': u.email,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      tx.set(hRef, {
        'uid': u.uid,
        'email': u.email,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  });

  await userDocRef().set({
    'uid': u.uid,
    'email': u.email,
    'handle': handle,
    'lastLoginAt': FieldValue.serverTimestamp(),
    'createdAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}

// ★ 변경: null-safe 대체 참조(화면에서 안전 가드가 필요할 때 사용 가능)
CollectionReference<Map<String, dynamic>>? favoritesColOrNull() {
  final u = FirebaseAuth.instance.currentUser;
  if (u == null) return null;
  final handle = _resolveHandle(u);
  return FirebaseFirestore.instance
      .collection('users')
      .doc(handle)
      .collection('favorites');
}

// 유지: 로그인 직후 루트 업서트(외부에서 직접 쓸 수 있게 남김)
Future<void> upsertUserRootDoc() async {
  final u = _requireUser();
  await userDocRef().set({
    'uid': u.uid,
    'email': u.email,
    'handle': currentHandle(),
    'lastLoginAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}

// 유지: 핸들 점유(직접 호출이 필요할 때 사용)
Future<void> ensureHandleClaimed() async {
  final u = _requireUser();
  final db = FirebaseFirestore.instance;
  final handle = currentHandle();

  await db.runTransaction((tx) async {
    final hRef = db.collection('handles').doc(handle);
    final snap = await tx.get(hRef);
    if (snap.exists) {
      final owner = snap.data()?['uid'] as String?;
      if (owner != null && owner != u.uid) {
        throw StateError('이미 다른 계정이 사용하는 handle 입니다.');
      }
    }
    tx.set(hRef, {
      'uid': u.uid,
      'email': u.email,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  });
}

@deprecated
Future<DocumentReference<Map<String, dynamic>>> userDocByHandle() async {
  return userDocRef();
}
