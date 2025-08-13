import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tt/user_handle.dart';
import 'firebase_options.dart';

// 페이지 import
import 'pages/style.dart';
import 'pages/choice.dart';
import 'pages/question.dart'; // QuestionPage 정의
import 'pages/recommendation.dart';
import 'pages/favorite.dart'; // StylistPage 정의
import 'pages/login.dart';
import 'pages/mypage.dart';
import 'pages/profile.dart';
import 'utils/user_handle.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 익명 로그인
  if (FirebaseAuth.instance.currentUser == null) {
    await FirebaseAuth.instance.signInAnonymously();
  }

  // 사용자 핸들 초기화
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

        // 질문 페이지 (arguments 방식)
        '/question': (context) => const QuestionPage(),

        '/choice': (context) => const ChoicePage(),
        '/recommendation': (context) => const RecommendationPage(),
        '/style': (context) => const StylePage(),

        // 마이페이지
        '/mypage': (context) => const MyPage(
          email: 'test@test.com',
          season: '여름',
          situation: '데이트',
        ),

        // 프로필 화면
        '/profile': (context) {
          final args =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          return ProfileScreen(
            email: args?['email'] ?? '',
            season: args?['season'] ?? '',
            situation: args?['situation'] ?? '',
            style: args?['style'] ?? '',
          );
        },

        // 즐겨찾기 & 스타일리스트 페이지
        '/favorite': (context) => const FavoritePage(),
        '/favorites': (context) => const FavoritePage(),
        '/stylist': (context) => const FavoritePage(),
      },
    );
  }
}
