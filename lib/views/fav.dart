import 'package:bookii/views/reader_view.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/book_model.dart';



class Fav extends StatefulWidget {
  const Fav({super.key});

  @override
  State<Fav> createState() => _FavState();
}

class _FavState extends State<Fav> {
  @override
  Widget build(BuildContext context) {
    final favBox = Hive.box('favorites');

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        title: const Text(
          'المحفوظات',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ValueListenableBuilder(
        valueListenable: favBox.listenable(),
        builder: (context, Box box, _) {
          if (box.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.bookmark_border, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'لم تقم بحفظ أي كتب بعد 📚',
                    style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          }

          final keys = box.keys.toList();

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: keys.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final bookData = box.get(keys[index]);

              BookModel book;
              if (bookData is Map) {
                book = BookModel.fromJson(Map<String, dynamic>.from(bookData));
              } else {
                return const SizedBox.shrink();
              }

              // تصميم كارت شيك وحديث ومتناسق مع التطبيق
              return InkWell(
                onTap: () {
                  // الانتقال لصفحة تفاصيل الكتاب عند الضغط عليه
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ReaderView(book: book),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // صورة الغلاف مع حواف دائرية
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: book.coverUrl != null && book.coverUrl!.isNotEmpty
                            ? Image.network(
                          book.coverUrl!,
                          width: 60,
                          height: 85,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                           Container(
                            width: 60,
                            height: 85,
                            color: Colors.grey,
                            child: Icon(Icons.book, color: Colors.white),
                          ),
                        )
                            : Container(
                          width: 60,
                          height: 85,
                          color: const Color(0xFF6C63FF).withOpacity(0.1),
                          child: const Icon(Icons.book, color: Color(0xFF6C63FF)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // تفاصيل الكتاب (العنوان والمؤلف)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              book.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              book.authors.join(', '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // زر الحذف من المفضلة
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () {
                          box.delete(keys[index]);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}