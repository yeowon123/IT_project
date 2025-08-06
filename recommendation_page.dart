// recommendation_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class RecommendationPage extends StatefulWidget {
  const RecommendationPage({super.key});

  @override
  State<RecommendationPage> createState() => _RecommendationPageState();
}

class _RecommendationPageState extends State<RecommendationPage> {
  List<QueryDocumentSnapshot> clothes = [];
  int page = 0;
  static const int itemsPerPage = 8;

  String category = '';
  String season = '';
  String situation = '';
  String style = '';

  bool isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, String?>;
    category = args['category'] ?? '';
    season = args['season'] ?? '';
    situation = args['situation'] ?? '';
    style = args['style'] ?? '';
    fetchClothes();
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
        final responseData = jsonDecode(response.body);
        final List<String> recommendedNames = List<String>.from(
          responseData['recommendations'],
        );
        debugPrint("추천 옷 이름: $recommendedNames");
        return recommendedNames;
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
    });

    try {
      List<String> recommendedNames = await fetchRecommendedItemNames();

      if (recommendedNames.isEmpty) {
        setState(() {
          clothes = [];
          isLoading = false;
        });
        return;
      }

      final query = FirebaseFirestore.instance
          .collection('clothes')
          .where('name', whereIn: recommendedNames);

      final snapshot = await query.get();

      setState(() {
        clothes = snapshot.docs;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('데이터 로딩 오류: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('데이터 로딩 실패')));
      setState(() {
        isLoading = false;
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
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
          centerTitle: true,
          title: Image.asset('assets/logo_4.png', height: 40),
        ),
        body: Container(
          color: Colors.white,
          child: SafeArea(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : clothes.isEmpty
                ? const Center(child: Text('추천할 의류가 없습니다.'))
                : Column(
                    children: [
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
                            final item =
                                currentItems[index].data()
                                    as Map<String, dynamic>;
                            final imageUrl = item['imageUrl'] ?? '';
                            final name = item['name'] ?? '옷 이름';
                            final link = item['link'] ?? '';

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
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(10),
                                    ),
                                    child: Image.network(
                                      imageUrl,
                                      height: 120,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.image, size: 100),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        GestureDetector(
                                          onTap: () => _launchURL(link),
                                          child: const Text(
                                            '링크',
                                            style: TextStyle(
                                              color: Colors.blue,
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
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
