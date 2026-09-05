import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/book_model.dart';

class BookCard extends StatelessWidget {
  final BookModel book;
  final VoidCallback? onTap;

  const BookCard({super.key, required this.book, this.onTap});

  @override
  Widget build(BuildContext context) {
    final favBox = Hive.box('favorites');

    return ValueListenableBuilder(
      valueListenable: favBox.listenable(),
      builder: (context, Box box, _) {
        bool isFav = box.containsKey(book.id);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            onTap: onTap,
            leading: book.coverUrl != null
                ? Image.network(book.coverUrl!, width: 50, fit: BoxFit.cover)
                : const Icon(Icons.book, size: 50),
            title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(book.authors.join(', '), maxLines: 1),
            trailing: IconButton(
              icon: Icon(
                isFav ? Icons.bookmark : Icons.bookmark_border,
                color: isFav ? Colors.deepPurple : null,
              ),
              onPressed: () {
                if (isFav) {
                  box.delete(book.id);
                } else {
                  box.put(book.id, {
                    'id': book.id,
                    'title': book.title,
                    'authors': book.authors,
                    'coverUrl': book.coverUrl,
                    'formats': book.formats,
                    'subjects': book.subjects,
                  });
                }
              },
            ),
          ),
        );
      },
    );
  }
}