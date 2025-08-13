import 'package:flutter/material.dart';

class MyPageDrawer extends StatelessWidget {
  final String email;
  final String season;
  final String situation;

  const MyPageDrawer({
    super.key,
    required this.email,
    required this.season,
    required this.situation,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.white),
            child: Text(
              '마이페이지',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),

          // 내 정보
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('내 정보'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(
                context,
                '/profile',
                arguments: {
                  'email': email,
                  'season': season,
                  'situation': situation,
                  'style': '', // ChoicePage 연동 시 선택된 스타일로 대체
                },
              );
            },
          ),

          // 즐겨찾기
          ListTile(
            leading: const Icon(Icons.star_border),
            title: const Text('즐겨찾기'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/favorite');
            },
          ),

          // 검색
          ListTile(
            leading: const Icon(Icons.search),
            title: const Text('검색'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(
                context,
                '/question',
                arguments: {
                  'email': email,
                  'season': season,
                  'situation': situation,
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
