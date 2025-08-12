import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'pages/style_page.dart';
import 'pages/choice_page.dart';
import 'pages/question_page.dart';
import 'pages/recommendation_page.dart';
import 'pages/stylist_page.dart';
import 'pages/login_page.dart'; //  Firebase 로그인 페이지 import

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fashion Recommender',
      debugShowCheckedModeBanner: false,

      // ✅ 전체 스크롤 글로우/바운스 제거 (iOS bounce, Android glow)
      builder: (context, child) {
        return ScrollConfiguration(
          behavior: const _NoGlowScrollBehavior(),
          child: child!,
        );
      },

      // ✅ AppBar가 스크롤 시 연보라색으로 변하는 M3 틴트/오버레이 제거
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.teal,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white, // 항상 흰색
          foregroundColor: Colors.black,
          elevation: 0,
          scrolledUnderElevation: 0, // 스크롤 아래로 내용이 지나가도 음영/오버레이 없음
          surfaceTintColor: Colors.transparent, // M3 표면 틴트 제거
        ),
      ),

      initialRoute: '/',
      routes: {
        '/': (context) => const LoginPage(), //  로그인 페이지 연결
        '/question': (context) => const QuestionPage(),
        '/choice': (context) => const ChoicePage(),
        '/recommendation': (context) => const RecommendationPage(),
        // 🔧 여기만 수정: 기본 생성자 사용
        '/style': (context) => const StylePage(),
        '/stylist': (context) => const StylistPage(),
      },
    );
  }
}

//  스크롤 글로우/스트레치 제거용 (프로젝트 공용으로 써도 됨)
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