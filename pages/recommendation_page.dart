import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/user_handle.dart' as uh; // ★ 변경: null-safe 컬렉션 가드를 위해 별칭 import

enum _PageMode { apiObjects, apiNamesFs, fsFallback }

class RecommendationPage extends StatefulWidget {
  const RecommendationPage({super.key});
  @override
  State<RecommendationPage> createState() => _RecommendationPageState();
}

class _RecommendationPageState extends State<RecommendationPage> {
  static const bool kAltForSmartstoreInEmulator = true;

  static const String _apiKey = "twenty-clothes-api-key";
  static const Duration apiTimeout = Duration(seconds: 60);
  static const Duration pingTimeout = Duration(seconds: 20);
  static const int _remotePageSize = 12;

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

  List<dynamic> clothes = [];
  bool isLoading = true;
  bool loadFailed = false;
  bool _initialized = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  String? _apiNextCursor;
  int _apiNextPage = 2;

  QueryDocumentSnapshot<Map<String, dynamic>>? _lastFsDoc;
  _PageMode? _mode;

  final Set<String> _seenApiIds = {};
  final Set<String> _seenFsPaths = {};

  String category = '';
  String season = '';
  String situation = '';
  String style = '';

  String categoryApiCode = '';
  String categoryFsSub = '';

  Set<String> favoriteIds = {};
  final StringBuffer _log = StringBuffer();
  void _addLog(String msg) {
    debugPrint(msg);
    _log.writeln(msg);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;

    final args = ModalRoute.of(context)!.settings.arguments as Map<String, String?>;
    category = args['categoryKr'] ?? args['category'] ?? '';
    season = args['season'] ?? '';
    situation = args['situation'] ?? '';
    style = args['style'] ?? '';

    categoryApiCode = (args['categoryApi'] ?? '').trim();
    categoryFsSub = (args['categoryFs'] ?? '').trim();
    if (categoryApiCode.isEmpty) categoryApiCode = _toApiCategory(category);
    if (categoryFsSub.isEmpty) categoryFsSub = _subCollectionOf(category);
    if (category.isEmpty && categoryFsSub.isNotEmpty) category = _krFromFsSub(categoryFsSub);

    fetchClothes();
    _initialized = true;
  }

  String _krFromFsSub(String s) {
    switch (s) {
      case 'tops':
        return '상의';
      case 'bottoms':
        return '하의';
      case 'setup':
        return '원피스';
      default:
        return '';
    }
  }

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
    return map[base] ?? base.toLowerCase();
  }

  String _toApiCategory(String s) {
    const map = {
      '상의': 'tops',
      '하의': 'bottoms',
      '세트업': 'setup',
      '세트': 'setup',
      '원피스': 'setup',
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

  Future<Map<String, dynamic>> _fetchFromApi({String? cursor, int? page, int? limit}) async {
    final url = Uri.parse(_apiUrl);
    final email = FirebaseAuth.instance.currentUser?.email ?? "guest@local";

    final body = {
      "email": email,
      "user_id": "user123",
      "user_input": {
        "style": _toApiStyle(style),
        "category": categoryApiCode,
        "season": _toApiSeason(season),
        "situation": _toApiSituation(situation),
      },
      "favorites": [],
      if (limit != null) "limit": limit,
      if (cursor != null) "cursor": cursor,
      if (page != null) "page": page,
    };

    try {
      final t0 = DateTime.now();
      final res = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json', 'x-api-key': _apiKey},
            body: jsonEncode(body),
          )
          .timeout(apiTimeout);
      final ms = DateTime.now().difference(t0).inMilliseconds;
      _addLog("[API] ${res.statusCode}, ${ms}ms");

      if (res.statusCode != 200 || res.body.isEmpty) {
        return {"names": <String>[], "items": <Map<String, dynamic>>[], "nextCursor": null};
      }

      final decoded = jsonDecode(res.body);
      String? nextCursor;
      if (decoded is Map) {
        nextCursor = (decoded["next_cursor"] ?? (decoded["meta"] is Map ? decoded["meta"]["next_cursor"] : null))?.toString();
      }
      final payload = (decoded is Map && decoded.containsKey("recommendations")) ? decoded["recommendations"] : decoded;

      if (payload is List && payload.isNotEmpty) {
        if (payload.first is String) {
          final names = List<String>.from(payload);
          return {"names": names, "items": <Map<String, dynamic>>[], "nextCursor": nextCursor};
        }
        if (payload.first is Map) {
          final items = payload.map((e) => Map<String, dynamic>.from(e as Map)).toList().cast<Map<String, dynamic>>();
          for (final m in items) {
            m["title"] = (m["title"] ?? m["name"] ?? "").toString();
            m["image"] = (m["image"] ?? "").toString();
            m["link"] = (m["link"] ?? "").toString();
          }
          return {"names": <String>[], "items": items, "nextCursor": nextCursor};
        }
      }
      return {"names": <String>[], "items": <Map<String, dynamic>>[], "nextCursor": null};
    } catch (_) {
      return {"names": <String>[], "items": <Map<String, dynamic>>[], "nextCursor": null};
    }
  }

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
        return 'setup';
      default:
        return '';
    }
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _queryByNamesBoth(
    String subCollection,
    List<String> names,
  ) async {
    const chunkSize = 10;
    final acc = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

    for (var i = 0; i < names.length; i += chunkSize) {
      final chunk = names.sublist(i, (i + chunkSize) > names.length ? names.length : (i + chunkSize));
      final snap1 = await FirebaseFirestore.instance.collectionGroup(subCollection).where('name', whereIn: chunk).get();
      final snap2 = await FirebaseFirestore.instance.collectionGroup(subCollection).where('title', whereIn: chunk).get();
      acc.addAll(snap1.docs);
      acc.addAll(snap2.docs);
    }

    final seen = <String>{};
    final deduped = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final d in acc) {
      final path = d.reference.path;
      if (seen.add(path)) deduped.add(d);
    }
    return deduped;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _fetchFsPage(
    String subCollection, {
    int limit = _remotePageSize,
    bool next = false,
  }) async {
    if (subCollection.isEmpty) return [];
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collectionGroup(subCollection).orderBy(FieldPath.documentId).limit(limit);
    if (next && _lastFsDoc != null) q = q.startAfterDocument(_lastFsDoc!);
    final snap = await q.get();
    if (snap.docs.isNotEmpty) _lastFsDoc = snap.docs.last;
    return snap.docs;
  }

  Future<void> fetchClothes() async {
    setState(() {
      isLoading = true;
      loadFailed = false;
      _isLoadingMore = false;
      _hasMore = true;
      _apiNextCursor = null;
      _apiNextPage = 2;
      _lastFsDoc = null;
      _mode = null;
      clothes = [];
      _seenApiIds.clear();
      _seenFsPaths.clear();
      _log.clear();
    });

    try {
      final api = await _fetchFromApi(limit: _remotePageSize);
      final sub = categoryFsSub;

      final serverItems = (api["items"] is List) ? List<Map<String, dynamic>>.from(api["items"]) : <Map<String, dynamic>>[];
      if (serverItems.isNotEmpty) {
        _appendApiItems(serverItems);
        _apiNextCursor = (api["nextCursor"] as String?);
        _mode = _PageMode.apiObjects;
        _hasMore = _apiNextCursor != null || serverItems.length >= _remotePageSize;
        if (mounted) setState(() => isLoading = false);
        return;
      }

      final names = (api["names"] is List) ? List<String>.from(api["names"]) : <String>[];
      if (names.isNotEmpty && sub.isNotEmpty) {
        final docs = await _queryByNamesBoth(sub, names);
        _appendFsDocs(docs);
        _mode = _PageMode.apiNamesFs;
        _hasMore = true;
        if (mounted) setState(() => isLoading = false);
        return;
      }

      if (sub.isNotEmpty) {
        final first = await _fetchFsPage(sub, limit: _remotePageSize, next: false);
        _appendFsDocs(first);
        _mode = _PageMode.fsFallback;
        _hasMore = first.length >= _remotePageSize;
      } else {
        _mode = _PageMode.fsFallback;
        _hasMore = false;
      }
      if (mounted) setState(() => isLoading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        loadFailed = true;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    try {
      if (_mode == _PageMode.apiObjects) {
        final api = await _fetchFromApi(limit: _remotePageSize, cursor: _apiNextCursor, page: _apiNextCursor == null ? _apiNextPage : null);
        final items = (api["items"] is List) ? List<Map<String, dynamic>>.from(api["items"]) : <Map<String, dynamic>>[];
        _appendApiItems(items);
        final nextCur = (api["nextCursor"] as String?);
        if (nextCur != null && nextCur.isNotEmpty) {
          _apiNextCursor = nextCur;
        } else {
          _apiNextCursor = null;
          _apiNextPage += 1;
        }
        _hasMore = (nextCur != null && nextCur.isNotEmpty) || items.length >= _remotePageSize;
      } else {
        final sub = categoryFsSub;
        final docs = await _fetchFsPage(sub, limit: _remotePageSize, next: true);
        _appendFsDocs(docs);
        _mode ??= _PageMode.fsFallback;
        _hasMore = docs.length >= _remotePageSize;
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _appendApiItems(List<Map<String, dynamic>> items) {
    for (var i = 0; i < items.length; i++) {
      final m = items[i];
      final id = (m["_id"] ?? m["id"] ?? m["link"] ?? "api-$i").toString();
      if (_seenApiIds.add(id)) {
        m["_id"] = id;
        clothes.add(m);
      }
    }
  }

  void _appendFsDocs(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    for (final d in docs) {
      final path = d.reference.path;
      if (_seenFsPaths.add(path)) clothes.add(d);
    }
  }

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

    if (uri.scheme == 'http') uri = uri.replace(scheme: 'https');

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
      return Uri(scheme: 'https', host: 'm.smartstore.naver.com', path: uri.path).toString();
    }

    final cleaned = uri.replace(queryParameters: {});
    final out = cleaned.toString();
    return out.endsWith('?') ? out.substring(0, out.length - 1) : out;
  }

  bool _isSmartstore(String u) => Uri.tryParse(u)?.host.endsWith('smartstore.naver.com') ?? false;

  String? _extractSmartstorePid(String u) {
    final m1 = RegExp(r'/products/(\d+)').firstMatch(u);
    if (m1 != null) return m1.group(1);
    final m2 = RegExp(r'[?&](productNo|itemId|pdpNo|prdNo)=(\d+)').firstMatch(u);
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
    final normalized = _normalizeUrl(raw);
    if (normalized.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('링크가 없어요.')));
      return;
    }
    final uri = Uri.tryParse(normalized);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('잘못된 링크 형식이에요.')));
      return;
    }
    if (_isSmartstore(normalized)) {
      final pid = _extractSmartstorePid(normalized);
      if (pid != null) {
        if (kAltForSmartstoreInEmulator) {
          final alt = Uri.parse('https://msearch.shopping.naver.com/product/$pid');
          if (await _openExternal(alt)) return;
        }
        if (await _blockedByNaver(uri)) {
          final alt = Uri.parse('https://msearch.shopping.naver.com/product/$pid');
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

  String _favDocId(String id) => (categoryFsSub.isNotEmpty ? '${categoryFsSub}_$id' : id);

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
          'id': id,
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
    const snackBg = Color(0xFFB3B3B3);

    final items = _collectFavoriteItems();
    if (items.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: snackBg, content: Text('선택된 즐겨찾기가 없어요.', style: TextStyle(color: Colors.black))),
      );
      return;
    }

    final col = uh.favoritesColOrNull(); // ★ 변경: 초기화 레이스 대비 null-safe 참조
    if (col == null) { // ★ 변경
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: snackBg, content: Text('사용자 정보를 준비 중이에요. 잠시 후 다시 시도해 주세요.', style: TextStyle(color: Colors.black))),
      );
      return;
    }

    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final item in items) {
        final rawId = (item['id'] as String?) ?? '';
        final docId = _favDocId(rawId);
        batch.set(col.doc(docId), item, SetOptions(merge: true));
      }
      await batch.commit();

      if (!mounted) return;

      final btnStyle = OutlinedButton.styleFrom(
        shape: const StadiumBorder(),
        side: const BorderSide(color: snackBg),
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: snackBg, // ★ 변경: 요청 색상
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8), // ★ 변경: 텍스트를 아래로 내리기 위한 여백
              const Text('즐겨찾기를 저장했어요', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              OutlinedButton(
                style: btnStyle,
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  Navigator.pushNamed(context, '/stylist');
                },
                child: const Text('즐겨찾기 보기'),
              ),
            ],
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: snackBg, content: Text('즐겨찾기 저장에 실패했어요.', style: TextStyle(color: Colors.black))),
      );
    }
  }

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
    final pillStyle = OutlinedButton.styleFrom(
      shape: const StadiumBorder(),
      side: const BorderSide(color: Color(0xFFB3B3B3)),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      foregroundColor: Colors.black,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(statusBarColor: Colors.white, statusBarIconBrightness: Brightness.dark),
      child: Scaffold(
        backgroundColor: Colors.white,
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(color: Colors.black),
                child: Text('메뉴', style: TextStyle(color: Colors.white, fontSize: 24)),
              ),
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('내 정보'),
                onTap: () => Navigator.pushNamed(context, '/profile'),
              ),
              ListTile(
                leading: const Icon(Icons.star),
                title: const Text('즐겨찾기'),
                onTap: () => Navigator.pushNamed(context, '/stylist'),
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
                ? Center(child: OutlinedButton(onPressed: fetchClothes, style: pillStyle, child: const Text('다시 시도')))
                : clothes.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('추천 결과가 없어요.'),
                            const SizedBox(height: 12),
                            OutlinedButton(onPressed: fetchClothes, style: pillStyle, child: const Text('다시 시도')),
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
                                  children: [OutlinedButton(onPressed: _pingApi, style: pillStyle, child: const Text('API 핑'))],
                                ),
                                const SizedBox(height: 12),
                              ],
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          const Divider(color: Color(0xFF63C6D1), thickness: 1, indent: 24, endIndent: 24),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(32, 12, 12, 12),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(category, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          Expanded(
                            child: ScrollConfiguration(
                              behavior: const _NoGlowScrollBehavior(),
                              child: GridView.builder(
                                physics: const ClampingScrollPhysics(),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 0.75,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                                itemCount: clothes.length,
                                itemBuilder: (context, index) {
                                  final doc = clothes[index];
                                  String imageUrl = '';
                                  String title = '';
                                  String link = '';
                                  String id = '';

                                  if (doc is QueryDocumentSnapshot<Map<String, dynamic>>) {
                                    final data = doc.data();
                                    imageUrl = (data['image'] ?? '').toString();
                                    title = (data['title'] ?? data['name'] ?? '옷 이름').toString();
                                    link = (data['link'] ?? '').toString();
                                    id = doc.id;
                                  } else if (doc is Map<String, dynamic>) {
                                    imageUrl = (doc['image'] ?? '').toString();
                                    title = (doc['title'] ?? doc['name'] ?? '옷 이름').toString();
                                    link = (doc['link'] ?? '').toString();
                                    id = (doc['_id'] ?? doc['id'] ?? 'api-$index').toString();
                                  }

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
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
                                                  errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 150),
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              right: 8,
                                              top: 8,
                                              child: Material(
                                                color: Colors.white.withValues(alpha: 0.9),
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
                                                  child: const Padding(
                                                    padding: EdgeInsets.all(6),
                                                    child: Icon(Icons.star_border, size: 18, color: Color(0xFF63C6D1)),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10.0),
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
                                },
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20, top: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                OutlinedButton(
                                  onPressed: favoriteIds.isNotEmpty ? _saveFavorites : null,
                                  style: pillStyle,
                                  child: const Text('즐겨찾기 저장'),
                                ),
                                const SizedBox(width: 12),
                                if (_hasMore)
                                  OutlinedButton(
                                    onPressed: _isLoadingMore ? null : _loadMore,
                                    style: pillStyle,
                                    child: _isLoadingMore
                                        ? const SizedBox(
                                            height: 18,
                                            width: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Text('추천 더보기'),
                                  ),
                              ],
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
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}
