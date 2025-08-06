import 'package:flutter/material.dart';

class StylistPage extends StatefulWidget {
  const StylistPage({super.key});

  @override
  State<StylistPage> createState() => _StylistPageState();
}

class _StylistPageState extends State<StylistPage> {
  final List<Map<String, dynamic>> tops = [
    {'id': 1, 'image': 'https://via.placeholder.com/100x100?text=Top1'},
    {'id': 2, 'image': 'https://via.placeholder.com/100x100?text=Top2'},
  ];

  final List<Map<String, dynamic>> bottoms = [
    {'id': 1, 'image': 'https://via.placeholder.com/100x100?text=Bottom1'},
    {'id': 2, 'image': 'https://via.placeholder.com/100x100?text=Bottom2'},
  ];

  final List<Map<String, dynamic>> dresses = [
    {'id': 1, 'image': 'https://via.placeholder.com/100x100?text=Dress1'},
    {'id': 2, 'image': 'https://via.placeholder.com/100x100?text=Dress2'},
  ];

  Map<String, dynamic>? selectedTop;
  Map<String, dynamic>? selectedBottom;

  void resetSelection() {
    setState(() {
      selectedTop = null;
      selectedBottom = null;
    });
  }

  bool favoriteClothesIsEmpty() {
    return tops.isEmpty && bottoms.isEmpty && dresses.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 1,
        backgroundColor: Colors.white,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        centerTitle: true,
        title: const Text(
          'T - T',
          style: TextStyle(
            color: Colors.blueAccent,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blueAccent),
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
              },
            ),
            ListTile(
              leading: const Icon(Icons.favorite),
              title: const Text('즐겨찾기'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('검색'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: favoriteClothesIsEmpty()
          ? _buildEmptyMessage()
          : _buildMainContent(),
    );
  }

  Widget _buildEmptyMessage() {
    return const Center(
      child: Text(
        '즐겨찾기한 의류가 없습니다.',
        style: TextStyle(color: Colors.grey, fontSize: 16),
      ),
    );
  }

  Widget _buildMainContent() {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '상의',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            _buildHorizontalList(tops, '상의'),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '하의',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            _buildHorizontalList(bottoms, '하의'),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '원피스',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            _buildHorizontalList(dresses, '원피스'),

            const SizedBox(height: 20),
            const Center(
              child: Text(
                '코디 미리보기',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            _buildPreviewBox(),

            const SizedBox(height: 20),
            Center(
              child: ElevatedButton.icon(
                onPressed: resetSelection,
                icon: const Icon(Icons.refresh, color: Colors.black),
                label: const Text('초기화', style: TextStyle(color: Colors.black)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Colors.black),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalList(
    List<Map<String, dynamic>> items,
    String category,
  ) {
    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final isSelected =
              (category == '상의' && selectedTop == item) ||
              (category == '하의' && selectedBottom == item);

          return GestureDetector(
            onTap: () {
              setState(() {
                if (category == '상의') {
                  selectedTop = item;
                } else if (category == '하의') {
                  selectedBottom = item;
                }
              });
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? Colors.blue : Colors.grey,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.network(item['image'], width: 100, height: 100),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPreviewBox() {
    return Container(
      width: double.infinity,
      height: 300,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (selectedBottom != null)
            Image.network(selectedBottom!['image'], width: 150, height: 150),
          if (selectedTop != null)
            Image.network(selectedTop!['image'], width: 150, height: 150),
          if (selectedTop == null && selectedBottom == null)
            const Text('상의와 하의를 선택해 주세요', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
