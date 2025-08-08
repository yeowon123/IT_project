import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/recommendation_response.dart';

class RecommendationPage extends StatefulWidget {
  const RecommendationPage({super.key});

  @override
  State<RecommendationPage> createState() => _RecommendationPageState();
}

class _RecommendationPageState extends State<RecommendationPage> {
  List<QueryDocumentSnapshot> clothes = [];
  int page = 0;
  static const int itemsPerPage = 8;
  bool isLoading = true;
  bool loadFailed = false;
  bool _initialized = false;

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
        debugPrint("추천 옷 이름: ${dto.recommendations}");
        return dto.recommendations;
      } else {
        debugPrint("API 오류: ${response.statusCode} - ${response.body}");
        return [];
      }
    } catch (e) {
      debugPrint("요청 실패: $e");
      return [];
    }
  }

  void fetchClothes() async {
    setState(() {
      isLoading = true;
      loadFailed = false;
    });

    try {
      final recommendedNames = await fetchRecommendedItemNames();

      if (recommendedNames.isEmpty) {
        setState(() {
          clothes = [];
          isLoading = false;
        });
        return;
      }

      final subCollection = category == '상의'
          ? 'tops'
          : category == '하의'
          ? 'bottoms'
          : '';

      if (subCollection.isEmpty) {
        setState(() {
          clothes = [];
          isLoading = false;
        });
        return;
      }

      final querySnapshot = await FirebaseFirestore.instance
          .collectionGroup(subCollection)
          .where('name', whereIn: recommendedNames)
          .get();

      setState(() {
        clothes = querySnapshot.docs;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('데이터 로딩 오류: $e');
      if (!mounted) return;
      setState(() {
        isLoading = false;
        loadFailed = true;
      });
    }
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

  @override
  Widget build(BuildContext context) {
    final currentItems = clothes
        .skip(page * itemsPerPage)
        .take(itemsPerPage)
        .toList();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
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
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/profile');
                },
              ),
              ListTile(
                leading: const Icon(Icons.star),
                title: const Text('즐겨찾기'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/favorites');
                },
              ),
              ListTile(
                leading: const Icon(Icons.search),
                title: const Text('검색'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/search');
                },
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
        body: Container(
          color: Colors.white,
          child: SafeArea(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : loadFailed
                ? Center(
                    child: ElevatedButton(
                      onPressed: fetchClothes,
                      child: const Text("다시 시도"),
                    ),
                  )
                : Column(
                    children: [
                      const Divider(color: Colors.grey, thickness: 1),
                      Padding(
                        padding: const EdgeInsets.all(12.0),
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
                        child: GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.75,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                          itemCount: currentItems.length,
                          itemBuilder: (context, index) {
                            final doc = currentItems[index];
                            final item = doc.data() as Map<String, dynamic>;
                            final imageUrl = item['image'] ?? '';
                            final title = item['title'] ?? '옷 이름';
                            final link = item['link'] ?? '';
                            final id = doc.id;

                            return Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF2F2F2),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(25),
                                    blurRadius: 4,
                                    offset: const Offset(2, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(10),
                                            ),
                                        child: Image.network(
                                          imageUrl,
                                          height: 120,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(
                                                Icons.image,
                                                size: 100,
                                              ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: IconButton(
                                          icon: Icon(
                                            favoriteIds.contains(id)
                                                ? Icons.star
                                                : Icons.star_border,
                                            color: Colors.blue,
                                          ),
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
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () => _launchURL(link),
                                          child: const Text(
                                            '링크',
                                            style: TextStyle(
                                              color: Colors.black,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      if ((page + 1) * itemsPerPage < clothes.length)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                page++;
                              });
                            },
                            child: const Text("Next"),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
