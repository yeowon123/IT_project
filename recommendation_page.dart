import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/recommendation_response.dart';

class RecommendationPage extends StatefulWidget {
  const RecommendationPage({super.key});

  @override
  State<RecommendationPage> createState() => _RecommendationPageState();
}

class _RecommendationPageState extends State<RecommendationPage> {
  List<dynamic> clothes = [];
  int page = 0;
  static const int itemsPerPage = 8;
  bool isLoading = true;
  bool loadFailed = false;
  bool _initialized = false;
  bool isMock = false;

  String category = '';
  String season = '';
  String situation = '';
  String style = '';

  Set<String> favoriteIds = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args =
          ModalRoute.of(context)!.settings.arguments as Map<String, String?>;
      category = args['category'] ?? '';
      season = args['season'] ?? '';
      situation = args['situation'] ?? '';
      style = args['style'] ?? '';
      fetchClothes();
      _initialized = true;
    }
  }

  Future<List<String>> fetchRecommendedItemNames() async {
    const String apiKey = "twenty-clothes-api-key";
    final url = Uri.parse("http://172.30.1.71:8000/recommend");

    final Map<String, dynamic> body = {
      "user_id": "user123",
      "user_input": {
        "style": style,
        "category": category,
        "season": season,
        "situation": situation,
      },
      "favorites": [],
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'x-api-key': apiKey},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final dto = RecommendationResponse.fromJson(decoded);
        return dto.recommendations;
      } else {
        return [];
      }
    } catch (_) {
      return [];
    }
  }

  void fetchClothes() async {
    setState(() {
      isLoading = true;
      loadFailed = false;
      isMock = false;
      page = 0; 
    });

    try {
      final recommendedNames = await fetchRecommendedItemNames();
      final subCollection = category == '상의'
          ? 'tops'
          : category == '하의'
          ? 'bottoms'
          : '';

      if (recommendedNames.isEmpty || subCollection.isEmpty) {
        showMockItems();
        return;
      }

      final querySnapshot = await FirebaseFirestore.instance
          .collectionGroup(subCollection)
          .where('name', whereIn: recommendedNames)
          .get();

      if (querySnapshot.docs.isEmpty) {
        showMockItems();
        return;
      }

      setState(() {
        clothes = querySnapshot.docs;
        isMock = false;
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        loadFailed = true;
      });
    }
  }

  
  void showMockItems() {
    final mockItems = List.generate(12, (i) {
      return {
        'title': '예시 옷 ${i + 1}',
        'image': 'https://via.placeholder.com/100x100?text=Mock+${i + 1}',
        'link': 'https://example.com/mock${i + 1}',
      };
    });

    setState(() {
      clothes = mockItems;
      isMock = true;
      isLoading = false;
      page = 0;
    });
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('링크를 열 수 없습니다.')));
    }
  }

  // 즐겨찾기 수집
  List<Map<String, dynamic>> _collectFavoriteItems() {
    final List<Map<String, dynamic>> result = [];
    for (int i = 0; i < clothes.length; i++) {
      final doc = clothes[i];
      String id;
      String title = '';
      String image = '';
      String link = '';

      if (doc is QueryDocumentSnapshot) {
        id = doc.id;
        final data = doc.data() as Map<String, dynamic>;
        title = data['title'] ?? '';
        image = data['image'] ?? '';
        link = data['link'] ?? '';
      } else if (doc is Map<String, dynamic>) {
        id = 'mock-$i';
        title = doc['title'] ?? '';
        image = doc['image'] ?? '';
        link = doc['link'] ?? '';
      } else {
        continue;
      }

      if (favoriteIds.contains(id)) {
        result.add({
          'title': title,
          'image': image,
          'link': link,
          'savedAt': FieldValue.serverTimestamp(),
        });
      }
    }
    return result;
  }

  // 즐겨찾기 저장: 로그인 보장 → uid 사용, 기존 데이터 보존(append)
  Future<void> _saveFavorites() async {
    final user = FirebaseAuth.instance.currentUser!; 
    final favoritesCol = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favorites');

    final items = _collectFavoriteItems();
    if (items.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('선택된 즐겨찾기가 없어요. ⭐를 눌러 선택해 주세요.')),
      );
      return;
    }

    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final item in items) {
        final ref = favoritesCol.doc(); 
        batch.set(ref, item);
      }
      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('즐겨찾기를 저장했어요 (${items.length}개 추가)')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('즐겨찾기 저장에 실패했어요. 잠시 후 다시 시도해 주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final int maxToShow = (page + 1) * itemsPerPage;
    final int visibleCount = maxToShow < clothes.length
        ? maxToShow
        : clothes.length;
    final bool hasMore = visibleCount < clothes.length;

   
    final ButtonStyle pillStyle = OutlinedButton.styleFrom(
      shape: const StadiumBorder(),
      side: const BorderSide(color: Color(0xFFB3B3B3)),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      foregroundColor: Colors.black,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(color: Colors.black),
                child: Text(
                  '메뉴',
                  style: TextStyle(color: Colors.white, fontSize: 24),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('내 정보'),
                onTap: () => Navigator.pushNamed(context, '/profile'),
              ),
              ListTile(
                leading: const Icon(Icons.star),
                title: const Text('즐겨찾기'),
                onTap: () => Navigator.pushNamed(context, '/favorites'),
              ),
              ListTile(
                leading: const Icon(Icons.search),
                title: const Text('검색'),
                onTap: () => Navigator.pushNamed(context, '/search'),
              ),
            ],
          ),
        ),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
          centerTitle: true,
          title: Image.asset('assets/logo_4.png', height: 50),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : loadFailed
            ? Center(
                child: OutlinedButton(
                  onPressed: fetchClothes,
                  style: pillStyle,
                  child: const Text('다시 시도'),
                ),
              )
            : Column(
                children: [
                  const Divider(
                    color: Color(0xFF63C6D1),
                    thickness: 1,
                    indent: 24,
                    endIndent: 24,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 12, 12, 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        category,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ScrollConfiguration(
                      behavior: const _NoGlowScrollBehavior(), // 글로우 제거
                      child: GridView.builder(
                        physics:
                            const ClampingScrollPhysics(), // overscroll bounce 방지
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.75,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                       
                        itemCount: visibleCount,
                        itemBuilder: (context, index) {
                          final doc = clothes[index];

                          String imageUrl = '';
                          String title = '';
                          String link = '';
                          String id = '';

                          if (doc is QueryDocumentSnapshot) {
                            final item = doc.data() as Map<String, dynamic>;
                            imageUrl = item['image'] ?? '';
                            title = item['title'] ?? '옷 이름';
                            link = item['link'] ?? '';
                            id = doc.id;
                          } else if (doc is Map<String, dynamic>) {
                            imageUrl = doc['image'] ?? '';
                            title = doc['title'] ?? '옷 이름';
                            link = doc['link'] ?? '';
                            id = 'mock-$index';
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 이미지 + 별
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.network(
                                        imageUrl,
                                        height: 120,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.image, size: 150),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 0,
                                    left: -15,
                                    child: IconButton(
                                      icon: Icon(
                                        favoriteIds.contains(id)
                                            ? Icons.star
                                            : Icons.star_border,
                                        color: const Color(0xFF63C6D1),
                                        size: 26,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        setState(() {
                                          if (favoriteIds.contains(id)) {
                                            favoriteIds.remove(id);
                                          } else {
                                            favoriteIds.add(id);
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // 상품명 (클릭 시 링크)
                              Padding(
                                padding: const EdgeInsets.only(left: 28.0),
                                child: InkWell(
                                  onTap: () => _launchURL(link),
                                  child: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),

                  // 하단 버튼 영역 (hasMore 사용)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: 20,
                      top: 8,
                    ),
                    child: hasMore
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              OutlinedButton(
                                onPressed: favoriteIds.isNotEmpty
                                    ? _saveFavorites
                                    : null,
                                style: pillStyle,
                                child: const Text('즐겨찾기 저장'),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton(
                                onPressed: () => setState(() => page++),
                                style: pillStyle,
                                child: const Text('추천 더보기'),
                              ),
                            ],
                          )
                        : Center(
                            child: OutlinedButton(
                              onPressed: favoriteIds.isNotEmpty
                                  ? _saveFavorites
                                  : null,
                              style: pillStyle,
                              child: const Text('즐겨찾기 저장'),
                            ),
                          ),
                  ),
                ],
              ),
      ),
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
