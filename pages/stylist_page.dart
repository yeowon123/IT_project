import 'package:flutter/material.dart';

class StylistPage extends StatefulWidget {
  const StylistPage({Key? key}) : super(key: key);

  @override
  State<StylistPage> createState() => _StylistPageState();
}

class _StylistPageState extends State<StylistPage> {
  final List<Map<String, dynamic>> tops = List.generate(
    8,
    (i) => {
      "title": "상의 ${i + 1}",
      "image": "https://via.placeholder.com/100x100?text=Top${i + 1}",
      "link": "https://example.com/top${i + 1}",
    },
  );

  final List<Map<String, dynamic>> bottoms = List.generate(
    8,
    (i) => {
      "title": "하의 ${i + 1}",
      "image": "https://via.placeholder.com/100x100?text=Bottom${i + 1}",
      "link": "https://example.com/bottom${i + 1}",
    },
  );

  Map<String, dynamic>? selectedTop;
  Map<String, dynamic>? selectedBottom;

  void resetSelection() {
    setState(() {
      selectedTop = null;
      selectedBottom = null;
    });
  }

  Widget section(
    String title,
    List<Map<String, dynamic>> items,
    String category,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 10, top: 9),
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, idx) {
                final item = items[idx];
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
                    width: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.grey[300]!,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child:
                                item["image"] != null &&
                                    item["image"]!.isNotEmpty
                                ? Image.network(
                                    item["image"]!,
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(
                                              Icons.broken_image,
                                              size: 40,
                                              color: Colors.grey,
                                            ),
                                  )
                                : const Icon(
                                    Icons.image,
                                    size: 40,
                                    color: Colors.grey,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          item["title"]!,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        Text(
                          item["link"]!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
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
            Image.network(selectedBottom!["image"], width: 150, height: 150),
          if (selectedTop != null)
            Image.network(selectedTop!["image"], width: 150, height: 150),
          if (selectedTop == null && selectedBottom == null)
            const Text('상의와 하의를 선택해 주세요', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('즐겨찾기', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0.8,
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const SizedBox(height: 16),
          section('상의', tops, '상의'),
          section('하의', bottoms, '하의'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '코디 미리보기',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
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
    );
  }
}
