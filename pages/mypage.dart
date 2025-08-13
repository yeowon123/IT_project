import 'package:flutter/material.dart';
import 'mypage_drawer.dart';

class MyPage extends StatelessWidget {
  final String email;
  final String season;
  final String situation;

  const MyPage({
    super.key,
    required this.email,
    required this.season,
    required this.situation,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: MyPageDrawer(
        email: email,
        season: season,
        situation: situation,
      ),
      appBar: AppBar(
        title: const Text('마이페이지', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // arguments로 QuestionPage에 데이터 전달
              Navigator.pushNamed(
                context,
                '/question',
                arguments: {
                  'name': email,
                  'season': season,
                  'situation': situation,
                },
              );
            },
          ),
        ],
      ),
      body: const Center(
        child: Text(
          '마이페이지 메인 콘텐츠',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
