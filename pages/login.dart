// lib/pages/login.dart (또는 login_page.dart)
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/user_handle.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  /// 인증 성공 후 공통 처리: handles 선점 + users/{handle} 업서트 + (신규시 createdAt) + healthcheck
  Future<void> _postAuthSetup({required bool isNew}) async {
    await ensureHandleClaimed(); // 🔒 handles/{handle} 선점
    await upsertUserRootDoc(); // ✅ users/{handle} upsert (uid, email, handle, lastLoginAt)
    if (isNew) {
      // 신규일 경우 createdAt만 추가 기록
      await userDocRef().set({
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> _signUpAndSave() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('모든 항목을 입력해주세요')));
      return;
    }

    // 1) 신규 회원가입 시도
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (cred.user != null) {
        await _postAuthSetup(isNew: true);
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/question');
        return;
      }
    } on FirebaseAuthException catch (e) {
      // 기존 계정이면 로그인으로 폴백
      if (e.code != 'email-already-in-use') {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('회원가입 실패: ${e.message}')));
        return;
      }
      // else: 아래에서 로그인 시도
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('오류: $e')));
      return;
    }

    // 2) 기존 계정 로그인
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (cred.user != null) {
        await _postAuthSetup(isNew: false);
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/question');
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('로그인 실패: ${e.message}')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('로그인 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 60),
              Image.asset('assets/logo.png', width: 200, height: 200),
              Container(
                margin: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFFD9D9D9),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Email',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF999999),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _buildInputDecoration('Enter your Email'),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Password',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF999999),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: _buildInputDecoration('Enter your Password'),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _signUpAndSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF63C6D1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Sign In',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFFD9D9D9)),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
