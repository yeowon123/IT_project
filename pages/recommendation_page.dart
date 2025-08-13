import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/user_handle.dart';

class RecommendationPage extends StatefulWidget {
  const RecommendationPage({super.key});

  @override
  State<RecommendationPage> createState() => _RecommendationPageState();
}

class _RecommendationPageState extends State<RecommendationPage> {
  // ====== 에뮬레이터 개발용: 스마트스토어면 바로 msearch로 열기 ======
  static const bool kAltForSmartstoreInEmulator = true;

  // ====== API 설정 ======
  static const String _apiKey = "twenty-clothes-api-key";
  static const Duration apiTimeout = Duration(seconds: 60);
  static const Duration pingTimeout = Duration(seconds: 20);

  late final String _apiUrl = "${_apiBase()}/recommend";

  String _apiBase() {
    const fromDefine = String.fromEnvironment('API_BASE');
    if (fromDefine.isNotEmpty) return fromDefine;

    if (kIsWeb) return "http://localhost:8000";
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return "http://10.0.2.2:8000";
      case TargetPlatform.iOS:
        return "http://127.0.0.1:8000";
      default:
        return "http://localhost:8000";
    }
  }

  /// Firestore 문서 또는 서버에서 온 Map을 함께 담기 위해 dynamic 사용
  List<dynamic> clothes = [];
  int page = 0;
  static const int itemsPerPage = 8;
  bool isLoading = true;
  bool loadFailed = false;
  bool _initialized = false;

  String category = ''; // 한글 표기: 상의/하의/원피스
  String season = '';
  String situation = '';
  String style = '';

  // ★ 추가: API/Firestore용 코드 분리(호환형)
  String categoryApiCode = ''; // tops | bottoms | setup (혹은 서버 요구값)
  String categoryFsSub = ''; // tops | bottoms | setup

  Set<String> favoriteIds = {};

  // 디버그 로그
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

      // ★ 라우트 인자에 새 키가 오면 사용, 없으면 한글 category로부터 유도
      categoryApiCode = (args['categoryApi'] ?? '').trim();
      categoryFsSub = (args['categoryFs'] ?? '').trim();
      if (categoryApiCode.isEmpty) {
        categoryApiCode = _toApiCategory(category);
      }
      if (categoryFsSub.isEmpty) {
        categoryFsSub = _subCollectionOf(category);
      }

      _addLog("[CFG] style=$style, category(kr)=$category");
      _addLog("[CFG] derived → api=$categoryApiCode, fs=$categoryFsSub");

      fetchClothes();
      _initialized = true;
    }
  }

  // ===== 한국어 → 서버 enum(영어) 변환 =====
  String _toApiStyle(String s) {
    final base = s.split('/').first.trim();
    const map = {
      '캐주얼': 'casual',
      '댄디': 'dandy',
      '러블리': 'lovely',
      '스포티': 'sporty',
      '스트릿': 'street',
      '빈티지': 'vintage',
    };
    return map[base] != null ? map[base]! : base.toLowerCase();
  }

  String _toApiCategory(String s) {
    const map = {
      '상의': 'tops',
      '하의': 'bottoms',
      '세트업': 'setup',
      '세트': 'setup',
      '원피스': 'setup', // 서버가 setup만 받는다고 해서 매핑
    };
    return map[s] ?? 'tops';
  }

  String _toApiSeason(String s) {
    const map = {'봄': 'spring', '여름': 'summer', '가을': 'fall', '겨울': 'winter'};
    return map[s] ?? s.toLowerCase();
  }

  String _toApiSituation(String s) {
    const map = {
      '개총': 'orientation',
      '오티': 'orientation',
      'OT': 'orientation',
      '오리엔테이션': 'orientation',
      '엠티': 'retreat',
      'MT': 'retreat',
      '면접': 'interview',
      '일상': 'daily',
      '등교': 'daily',
      '데이트': 'date',
    };
    return map[s] ?? s.toLowerCase();
  }

  // ===== API 결과 파싱 (문자열 배열/객체 배열 모두 지원) =====
  Future<Map<String, dynamic>> _fetchFromApi() async {
    final url = Uri.parse(_apiUrl);
    final email = FirebaseAuth.instance.currentUser?.email ?? "guest@local";

    final apiStyle = _toApiStyle(style);
    final apiCategory = categoryApiCode; // ★ 고정 사용
    final apiSeason = _toApiSeason(season);
    final apiSituation = _toApiSituation(situation);

    final body = {
      "email": email,
      "user_id": "user123",
      "user_input": {
        "style": apiStyle,
        "category": apiCategory,
        "season": apiSeason,
        "situation": apiSituation,
      },
      "favorites": [],
    };

    try {
      _addLog("[CFG] API_BASE = ${_apiBase()}");
      _addLog(
        "[API] 요청 → $_apiUrl style=$apiStyle, category=$apiCategory, season=$apiSeason, situation=$apiSituation",
      );

      final t0 = DateTime.now();
      final res = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json', 'x-api-key': _apiKey},
            body: jsonEncode(body),
          )
          .timeout(apiTimeout);
      final ms = DateTime.now().difference(t0).inMilliseconds;
      _addLog("[API] 응답 status=${res.statusCode}, ${ms}ms");

      if (res.statusCode != 200 || res.body.isEmpty) {
        _addLog("[API] 실패 status=${res.statusCode} body=${res.body}");
        return {"names": <String>[], "items": <Map<String, dynamic>>[]};
      }

      final decoded = jsonDecode(res.body);
      final payload = (decoded is Map && decoded.containsKey("recommendations"))
          ? decoded["recommendations"]
          : decoded;

      if (payload is List && payload.isNotEmpty) {
        if (payload.first is String) {
          final names = List<String>.from(payload);
          _addLog("[API] 문자열 추천 ${names.length}개");
          return {"names": names, "items": <Map<String, dynamic>>[]};
        }
        if (payload.first is Map) {
          final items = payload
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
              .cast<Map<String, dynamic>>();
          for (final m in items) {
            m["title"] = (m["title"] ?? m["name"] ?? "").toString();
            m["image"] = (m["image"] ?? "").toString();
            m["link"] = (m["link"] ?? "").toString();
          }
          _addLog("[API] 객체 추천 ${items.length}개");
          return {"names": <String>[], "items": items};
        }
      }

      _addLog("[API] 추천 0개 또는 알 수 없는 스키마");
      return {"names": <String>[], "items": <Map<String, dynamic>>[]};
    } catch (e) {
      _addLog("[API] 예외: $e");
      return {"names": <String>[], "items": <Map<String, dynamic>>[]};
    }
  }

  // ===== Firestore 서브컬렉션명 =====
  String _subCollectionOf(String category) {
    switch (category) {
      case '상의':
        return 'tops';
      case '하의':
        return 'bottoms';
      case '세트업':
      case '세트':
        return 'setup';
      case '원피스':
        return 'setup'; // ★ FIX: onepiece → setup (DB와 일치)
      default:
        return '';
    }
  }

  // ===== Firestore 조회 (name/title whereIn, 10개 청크) =====
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _queryByNamesBoth(
    String subCollection,
    List<String> names,
  ) async {
    const chunkSize = 10;
    final acc = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

    for (var i = 0; i < names.length; i += chunkSize) {
      final chunk = names.sublist(
        i,
        (i + chunkSize) > names.length ? names.length : (i + chunkSize),
      );

      final snap1 = await FirebaseFirestore.instance
          .collectionGroup(subCollection)
          .where('name', whereIn: chunk)
          .get();

      final snap2 = await FirebaseFirestore.instance
          .collectionGroup(subCollection)
          .where('title', whereIn: chunk)
          .get();

      acc.addAll(snap1.docs);
      acc.addAll(snap2.docs);
    }

    final seen = <String>{};
    final deduped = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final d in acc) {
      final path = d.reference.path;
      if (seen.add(path)) deduped.add(d);
    }
    _addLog("[FS] '$subCollection' 조회 결과(중복 제거 후): ${deduped.length}건");
    return deduped;
  }

  // ===== Firestore Fallback =====
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _fallbackFromFS(
    String subCollection, {
    int limit = 12,
  }) async {
    final snap = await FirebaseFirestore.instance
        .collectionGroup(subCollection)
        .limit(limit)
        .get();
    _addLog("[FS/Fallback] '$subCollection'에서 대체 ${snap.docs.length}건 로드");
    return snap.docs;
  }

  // ===== 메인 로더 =====
  Future<void> fetchClothes() async {
    setState(() {
      isLoading = true;
      loadFailed = false;
      page = 0;
      _log.clear();
    });

    try {
      final api = await _fetchFromApi();
      final sub = categoryFsSub; // ★ FIX: 유도/전달된 FS 서브컬렉션 사용
      _addLog("[FS] 카테고리='$category' → sub='$sub'");

      // 1) 서버가 객체 배열을 주면 그대로 표시
      final serverItems = (api["items"] is List)
          ? List<Map<String, dynamic>>.from(api["items"])
          : <Map<String, dynamic>>[];
      if (serverItems.isNotEmpty) {
        if (!mounted) return;
        for (var i = 0; i < serverItems.length; i++) {
          serverItems[i]["_id"] = serverItems[i]["id"]?.toString() ?? "api-$i";
        }
        setState(() {
          clothes = serverItems;
          isLoading = false;
          loadFailed = false;
        });
        return;
      }

      // 2) 문자열 이름 배열이면 파베 매칭
      final names = (api["names"] is List)
          ? List<String>.from(api["names"])
          : <String>[];
      if (names.isNotEmpty && sub.isNotEmpty) {
        final docs = await _queryByNamesBoth(sub, names);

        String norm(String s) => s.trim().toLowerCase();
        final order = <String, int>{};
        for (int i = 0; i < names.length; i++) {
          order[norm(names[i])] = i;
        }
        docs.sort((a, b) {
          final am = a.data();
          final bm = b.data();
          final an = norm(((am['name'] ?? am['title'] ?? '')).toString());
          final bn = norm(((bm['name'] ?? bm['title'] ?? '')).toString());
          final ai = order[an] ?? 999999;
          final bi = order[bn] ?? 999999;
          return ai.compareTo(bi);
        });

        if (!mounted) return;
        if (docs.isNotEmpty) {
          setState(() {
            clothes = docs;
            isLoading = false;
            loadFailed = false;
          });
          return;
        } else {
          _addLog("[UI] 파베 매칭 0건 → Fallback 시도");
        }
      } else {
        _addLog("[UI] 서버 추천이 비었거나 sub 비어 있음 → Fallback 시도");
      }

      // 3) Fallback
      if (sub.isNotEmpty) {
        final fallbacks = await _fallbackFromFS(sub);
        if (!mounted) return;
        setState(() {
          clothes = fallbacks;
          isLoading = false;
          loadFailed = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          clothes = [];
          isLoading = false;
          loadFailed = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      _addLog("[FS] 예외: $e");
      setState(() {
        isLoading = false;
        loadFailed = true;
      });
    }
  }

  // ===== URL 열기 보조 =====
  String _normalizeUrl(String url) {
    var s = url.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '').trim();
    if (s.isEmpty) return s;

    if (s.startsWith('//')) s = 'https:$s';
    if (!s.startsWith('http://') && !s.startsWith('https://')) s = 'https://$s';

    Uri uri;
    try {
      uri = Uri.parse(s);
    } catch (_) {
      return s;
    }

    if (uri.host.contains('shopping.naver.com')) {
      final door = uri.queryParameters['url'] ?? uri.queryParameters['u'];
      if (door != null && door.isNotEmpty) {
        try {
          return _normalizeUrl(Uri.decodeFull(door));
        } catch (_) {
          return door;
        }
      }
    }

    if (uri.scheme == 'http') {
      uri = uri.replace(scheme: 'https');
    }

    if (uri.host.endsWith('smartstore.naver.com')) {
      final m = RegExp(r'/products/(\d+)').firstMatch(uri.path);
      String? pid = m?.group(1);

      if (pid == null) {
        for (final key in ['productNo', 'itemId', 'pdpNo', 'prdNo']) {
          final v = uri.queryParameters[key];
          if (v != null && RegExp(r'^\d+$').hasMatch(v)) {
            pid = v;
            break;
          }
        }
      }

      if (pid != null && pid.isNotEmpty) {
        return 'https://m.smartstore.naver.com/products/$pid';
      }

      return Uri(
        scheme: 'https',
        host: 'm.smartstore.naver.com',
        path: uri.path,
      ).toString();
    }

    final cleaned = uri.replace(queryParameters: {});
    final out = cleaned.toString();
    return out.endsWith('?') ? out.substring(0, out.length - 1) : out;
  }

  bool _isSmartstore(String u) =>
      Uri.tryParse(u)?.host.endsWith('smartstore.naver.com') ?? false;

  String? _extractSmartstorePid(String u) {
    final m1 = RegExp(r'/products/(\d+)').firstMatch(u);
    if (m1 != null) return m1.group(1);
    final m2 = RegExp(
      r'[?&](productNo|itemId|pdpNo|prdNo)=(\d+)',
    ).firstMatch(u);
    return m2?.group(2);
  }

  Future<bool> _blockedByNaver(Uri u) async {
    try {
      final r = await http.get(u).timeout(const Duration(seconds: 3));
      final t = r.body;
      return t.contains('접속이 일시적으로 제한') || t.contains('현재 서비스 접속이 불가합니다');
    } catch (_) {
      return false;
    }
  }

  Future<bool> _openExternal(Uri u) async {
    try {
      return await launchUrl(u, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  Future<void> _launchURL(String raw) async {
    debugPrint('RAW URL >>> $raw');
    final normalized = _normalizeUrl(raw);
    debugPrint('NORMALIZED >>> $normalized');

    if (normalized.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('링크가 없어요.')));
      return;
    }

    final uri = Uri.tryParse(normalized);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('잘못된 링크 형식이에요.')));
      return;
    }

    if (_isSmartstore(normalized)) {
      final pid = _extractSmartstorePid(normalized);
      if (pid != null) {
        if (kAltForSmartstoreInEmulator) {
          final alt = Uri.parse(
            'https://msearch.shopping.naver.com/product/$pid',
          );
          if (await _openExternal(alt)) return;
        }
        if (await _blockedByNaver(uri)) {
          final alt = Uri.parse(
            'https://msearch.shopping.naver.com/product/$pid',
          );
          if (await _openExternal(alt)) return;
        }
      }
    }

    final ok = await _openExternal(uri);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('링크를 열 수 없습니다. 다른 네트워크에서 다시 시도해 주세요.')),
      );
    }
  }

  // 즐겨찾기 수집
  List<Map<String, dynamic>> _collectFavoriteItems() {
    final List<Map<String, dynamic>> result = [];
    for (int i = 0; i < clothes.length; i++) {
      final doc = clothes[i];

      String id = '';
      String title = '';
      String image = '';
      String link = '';

      if (doc is QueryDocumentSnapshot<Map<String, dynamic>>) {
        id = doc.id;
        final data = doc.data();
        title = ((data['title'] ?? data['name'] ?? '')).toString();
        image = ((data['image'] ?? '')).toString();
        link = ((data['link'] ?? '')).toString();
      } else if (doc is Map<String, dynamic>) {
        id = (doc["_id"] ?? doc["id"] ?? 'api-$i').toString();
        title = ((doc['title'] ?? doc['name'] ?? '')).toString();
        image = ((doc['image'] ?? '')).toString();
        link = ((doc['link'] ?? '')).toString();
      } else {
        continue;
      }

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('즐겨찾기 저장에 실패했어요.')));
    }
  }

  // API 핑(연결 확인)
  Future<void> _pingApi() async {
    final docsUrl = Uri.parse("${_apiBase()}/docs");
    final specUrl = Uri.parse("${_apiBase()}/openapi.json");

    Future<void> doPing(Uri url) async {
      final t0 = DateTime.now();
      final res = await http.get(url).timeout(pingTimeout);
      final ms = DateTime.now().difference(t0).inMilliseconds;
      _addLog("[PING] GET $url → status=${res.statusCode}, ${ms}ms");
    }

    try {
      await doPing(docsUrl);
    } catch (_) {
      try {
        await doPing(specUrl);
      } catch (e) {
        _addLog("[PING] error=$e");
      }
    }

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final maxToShow = (page + 1) * itemsPerPage;
    final visibleCount = maxToShow < clothes.length
        ? maxToShow
        : clothes.length;
    final hasMore = visibleCount < clothes.length;

    final pillStyle = OutlinedButton.styleFrom(
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

                          String imageUrl = '';
                          String title = '';
                          String link = '';
                          String id = '';

                          if (doc
                              is QueryDocumentSnapshot<Map<String, dynamic>>) {
                            final data = doc.data();
                            imageUrl = (data['image'] ?? '').toString();
                            title = (data['title'] ?? data['name'] ?? '옷 이름')
                                .toString();
                            link = (data['link'] ?? '').toString();
                            id = doc.id;
                          } else if (doc is Map<String, dynamic>) {
                            imageUrl = (doc['image'] ?? '').toString();
                            title = (doc['title'] ?? doc['name'] ?? '옷 이름')
                                .toString();
                            link = (doc['link'] ?? '').toString();
                            id = (doc['_id'] ?? doc['id'] ?? 'api-$index')
                                .toString();
                          }

                          // ====== 카드 UI ======
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                ),
                                child: Stack(
                                  children: [
                                    SizedBox(
                                      height: 120,
                                      width: double.infinity,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(
                                                Icons.image,
                                                size: 150,
                                              ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      right: 8,
                                      top: 8,
                                      child: Material(
                                        color: Colors.white.withOpacity(0.9),
                                        shape: const CircleBorder(),
                                        elevation: 2,
                                        child: InkWell(
                                          customBorder: const CircleBorder(),
                                          onTap: () {
                                            setState(() {
                                              if (favoriteIds.contains(id)) {
                                                favoriteIds.remove(id);
                                              } else {
                                                favoriteIds.add(id);
                                              }
                                            });
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.all(6),
                                            child: Icon(
                                              favoriteIds.contains(id)
                                                  ? Icons.star
                                                  : Icons.star_border,
                                              size: 18,
                                              color: const Color(0xFF63C6D1),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10.0,
                                ),
                                child: InkWell(
                                  onTap: () => _launchURL(link),
                                  child: Text(
                                    title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                      fontSize: 13,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                          // ====== UI 변경 끝 ======
                        },
                      ),
                    ),
                  ),
                  // 하단 버튼
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
