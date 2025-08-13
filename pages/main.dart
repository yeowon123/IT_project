import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ★ 변경: 최소 로그인 보장을 위해 추가
import 'firebase_options.dart';
import 'pages/style_page.dart';
import 'pages/choice_page.dart';
import 'pages/question_page.dart';
import 'pages/recommendation_page.dart';
import 'pages/stylist_page.dart';
import 'pages/login_page.dart';
import 'utils/user_handle.dart'; // ★ 변경: ensureUserHandle 사용

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ★ 변경: 앱 시작 시 익명 로그인 보장(디바이스에서 로그인 전 진입 방지)
  if (FirebaseAuth.instance.currentUser == null) {
    await FirebaseAuth.instance.signInAnonymously();
  }

  // ★ 변경: 사용자 핸들/루트문서 준비(즐겨찾기 컬렉션 참조가 null 되는 문제 방지)
  await ensureUserHandle();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fashion Recommender',
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return ScrollConfiguration(
          behavior: const _NoGlowScrollBehavior(),
          child: child!,
        );
      },
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.teal,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginPage(),
        '/question': (context) => const QuestionPage(),
        '/choice': (context) => const ChoicePage(),
        '/recommendation': (context) => const RecommendationPage(),
        '/style': (context) => const StylePage(),
        '/stylist': (context) => const StylistPage(),
      },
    );
  }
}

class _NoGlowScrollBehavior extends ScrollBehavior {
  const _NoGlowScrollBehavior();
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
