import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import '../models/recommendation_response.dart';
import '../utils/user_handle.dart'; // 추가

class RecommendationPage extends StatefulWidget {
  const RecommendationPage({super.key});

  @override
  State<RecommendationPage> createState() => _RecommendationPageState();
}

class _RecommendationPageState extends State<RecommendationPage> {
  // ====== API 설정 ======
  static const String _apiKey = "twenty-clothes-api-key";
  late final String _apiUrl = "${_apiBase()}/recommend";

  String _apiBase() {
    // flutter run --dart-define=API_BASE=http://172.30.1.71:8000 로 오버라이드 가능
    const fromDefine = String.fromEnvironment('API_BASE');
    if (fromDefine.isNotEmpty) return fromDefine;

    if (kIsWeb) return "http://localhost:8000";
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return "http://10.0.2.2:8000"; // Android 에뮬레이터에서 호스트 접근
      case TargetPlatform.iOS:
        return "http://127.0.0.1:8000"; // iOS 시뮬레이터에서 호스트 접근
      default:
        return "http://localhost:8000";
    }
  }

  // Firestore 문서만 담도록 타입 명확화
  List<QueryDocumentSnapshot<Map<String, dynamic>>> clothes = [];
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

  // 디버그 로그(빈 결과 시 화면에서 확인)
  final StringBuffer _log = StringBuffer();
  void _addLog(String msg) {
    debugPrint(msg);
    _log.writeln(msg);
  }

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
    final url = Uri.parse(_apiUrl);

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
      _addLog("[API] 요청 → $_apiUrl body=$body");
      final t0 = DateTime.now();
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json', 'x-api-key': _apiKey},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
      final ms = DateTime.now().difference(t0).inMilliseconds;
      _addLog("[API] 응답 status=${response.statusCode}, ${ms}ms");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final dto = RecommendationResponse.fromJson(decoded);
        _addLog(
          "[API] 추천 개수=${dto.recommendations.length}, 상위10=${dto.recommendations.take(10).toList()}",
        );
        return dto.recommendations;
      } else {
        _addLog("[API] 실패 status=${response.statusCode} body=${response.body}");
        return [];
      }
    } catch (e) {
      _addLog("[API] 예외: $e");
      return [];
    }
  }

  // 카테고리 → 서브컬렉션명 매핑
  String _subCollectionOf(String category) {
    switch (category) {
      case '상의':
        return 'tops';
      case '하의':
        return 'bottoms';
      // 필요 시 확장:
      // case '아우터': return 'outers';
      // case '원피스': return 'onepiece';
      default:
        return '';
    }
  }

  // whereIn 10개 제한을 고려해 청크 분할, name/title 양쪽 조회 후 dedupe
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _queryByNamesBoth(
    String subCollection,
    List<String> names,
  ) async {
    const int chunkSize = 10;
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> acc = [];

    for (int i = 0; i < names.length; i += chunkSize) {
      final chunk = names.sublist(
        i,
        (i + chunkSize) > names.length ? names.length : (i + chunkSize),
      );

      // name in (...)
      final snap1 = await FirebaseFirestore.instance
          .collectionGroup(subCollection)
          .where('name', whereIn: chunk)
          .get();

      // title in (...)
      final snap2 = await FirebaseFirestore.instance
          .collectionGroup(subCollection)
          .where('title', whereIn: chunk)
          .get();

      acc.addAll(snap1.docs);
      acc.addAll(snap2.docs);
    }

    // 중복 제거 (문서 경로 기준)
    final seen = <String>{};
    final deduped = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final d in acc) {
      final path = d.reference.path;
      if (seen.add(path)) deduped.add(d);
    }
    _addLog("[FS] '${subCollection}' 조회 결과(중복 제거 후): ${deduped.length}건");
    return deduped;
  }

  void fetchClothes() async {
    setState(() {
      isLoading = true;
      loadFailed = false;
      page = 0;
      _log.clear();
    });

    try {
      final recommendedNames = await fetchRecommendedItemNames();

      final subCollection = _subCollectionOf(category);
      _addLog("[FS] 카테고리='$category' → sub='$subCollection'");

      if (recommendedNames.isEmpty || subCollection.isEmpty) {
        _addLog("[FS] 추천이 비었거나 subCollection이 비어 있음 → 표시할 아이템 없음");
        if (!mounted) return;
        setState(() {
          clothes = [];
          isLoading = false;
          loadFailed = false; // 결과 없음 상태
        });
        return;
      }

      final docs = await _queryByNamesBoth(subCollection, recommendedNames);
      if (!mounted) return;

      // 추천 이름 순서대로 정렬
      String norm(String s) => s.trim().toLowerCase();
      final order = <String, int>{};
      for (int i = 0; i < recommendedNames.length; i++) {
        order[norm(recommendedNames[i])] = i;
      }

      docs.sort((a, b) {
        final am = a.data();
        final bm = b.data();
        final an = norm((am['name'] ?? am['title'] ?? '') as String? ?? '');
        final bn = norm((bm['name'] ?? bm['title'] ?? '') as String? ?? '');
        final ai = order[an] ?? 999999;
        final bi = order[bn] ?? 999999;
        return ai.compareTo(bi);
      });

      setState(() {
        clothes = docs;
        isLoading = false;
        loadFailed = false;
      });

      if (docs.isEmpty) {
        _addLog("[FS] 0건 → 필드명 불일치/값 오탈자/규칙/문서 미존재 가능성");
      }
    } catch (e) {
      if (!mounted) return;
      _addLog("[FS] 예외: $e");
      setState(() {
        isLoading = false;
        loadFailed = true; // 네트워크/쿼리 실패
      });
    }
  }

  Future<void> _launchURL(String url) async {
    if (url.isEmpty) return;
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
    for (final doc in clothes) {
      final data = doc.data();
      final id = doc.id;
      final title = (data['title'] ?? data['name'] ?? '') as String? ?? '';
      final image = (data['image'] ?? '') as String? ?? '';
      final link = (data['link'] ?? '') as String? ?? '';
      if (favoriteIds.contains(id)) {
        result.add({
          'title': title,
          'image': image,
          'link': link,
          'category': category,
          'savedAt': FieldValue.serverTimestamp(),
        });
      }
    }
    return result;
  }

  // 즐겨찾기 저장: users/{handle}/favorites/{autoId}
  Future<void> _saveFavorites() async {
    final items = _collectFavoriteItems();
    if (items.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('선택된 즐겨찾기가 없어요.')));
      return;
    }

    try {
      final userDoc = await userDocByHandle();
      final favoritesCol = userDoc.collection('favorites');

      final batch = FirebaseFirestore.instance.batch();
      for (final item in items) {
        final ref = favoritesCol.doc(); // 자동 ID → 누적 저장
        batch.set(ref, item);
      }
      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('즐겨찾기를 저장했어요 (${items.length}개 추가)')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('즐겨찾기 저장에 실패했어요.')));
    }
  }

  // API 네트워크 간단 점검
  Future<void> _pingApi() async {
    try {
      final res = await http
          .post(
            Uri.parse(_apiUrl),
            headers: {'Content-Type': 'application/json', 'x-api-key': _apiKey},
            body: jsonEncode({
              "user_id": "ping",
              "user_input": {
                "style": "",
                "category": "",
                "season": "",
                "situation": "",
              },
              "favorites": [],
            }),
          )
          .timeout(const Duration(seconds: 5));
      _addLog("[PING] status=${res.statusCode}");
      setState(() {});
    } catch (e) {
      _addLog("[PING] error=$e");
      setState(() {});
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
            : clothes.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('추천 결과가 없어요.'),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: fetchClothes,
                      style: pillStyle,
                      child: const Text('다시 시도'),
                    ),
                    const SizedBox(height: 24),
                    ExpansionTile(
                      title: const Text('진단 정보 보기'),
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          color: const Color(0xFFF7F7F7),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SelectableText(_log.toString()),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton(
                              onPressed: _pingApi,
                              style: pillStyle,
                              child: const Text('API 핑'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ],
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
                      behavior: const _NoGlowScrollBehavior(),
                      child: GridView.builder(
                        physics: const ClampingScrollPhysics(),
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
                          final data = doc.data();

                          final String imageUrl =
                              (data['image'] ?? '') as String? ?? '';
                          final String title =
                              (data['title'] ?? data['name'] ?? '옷 이름')
                                  as String;
                          final String link =
                              (data['link'] ?? '') as String? ?? '';
                          final String id = doc.id;

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
                                    left: -15, // 필요시 오른쪽으로 변경 가능
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

                  // 하단 버튼 영역
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

// 오버스크롤 글로우/스트레치 제거용
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
