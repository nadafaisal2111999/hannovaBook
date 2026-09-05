class BookModel {
  final int id;
  final String title;
  final List<String> authors;
  final String? coverUrl;
  final Map<String, dynamic> formats;
  final List<String> subjects;

  BookModel({
    required this.id,
    required this.title,
    required this.authors,
    this.coverUrl,
    required this.formats,
    required this.subjects,
  });

  factory BookModel.fromJson(Map<String, dynamic> json) {
    final List<String> authors = [];

    final authorsData = json['authors'];

    if (authorsData is List) {
      for (final author in authorsData) {
        if (author is Map) {
          final name = author['name'];

          if (name != null && name.toString().trim().isNotEmpty) {
            authors.add(name.toString().trim());
          }
        }
      }
    }

    final Map<String, dynamic> formats = {};

    final formatsData = json['formats'];

    if (formatsData is Map) {
      formatsData.forEach((key, value) {
        formats[key.toString()] = value;
      });
    }

    final List<String> subjects = [];

    final subjectsData = json['subjects'];

    if (subjectsData is List) {
      for (final subject in subjectsData) {
        if (subject != null) {
          subjects.add(subject.toString());
        }
      }
    }

    String? coverUrl;

    final image = formats['image/jpeg'];

    if (image != null && image.toString().trim().isNotEmpty) {
      coverUrl = image.toString();
    }

    return BookModel(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      title: json['title']?.toString().trim().isNotEmpty == true
          ? json['title'].toString().trim()
          : 'بدون عنوان',
      authors: authors,
      coverUrl: coverUrl,
      formats: formats,
      subjects: subjects,
    );
  }
}