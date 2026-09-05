import 'package:dio/dio.dart';
import '../models/book_model.dart';

class BookService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://gutendex.com',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Accept': 'application/json',
      },
    ),
  );

  Future<List<BookModel>> fetchBooks() async {
    try {
      final response = await _dio.get(
        '/books/',
        queryParameters: {
          'page': 1,
          'sort': 'popular',
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Server error: ${response.statusCode}',
        );
      }

      final data = response.data;

      if (data is! Map) {
        throw Exception('Invalid API response');
      }

      final results = data['results'];

      if (results is! List) {
        throw Exception('Books list not found');
      }

      final List<BookModel> books = [];

      for (final item in results) {
        if (item is Map) {
          try {
            final book = BookModel.fromJson(
              Map<String, dynamic>.from(item),
            );

            if (book.id != 0) {
              books.add(book);
            }
          } catch (e) {
            print('Book parsing error: $e');
          }
        }
      }

      print('Books loaded: ${books.length}');

      return books;
    } on DioException catch (e) {
      print('Dio Error: ${e.message}');

      throw Exception(
        e.message ?? 'حدث خطأ أثناء الاتصال بالخادم',
      );
    } catch (e) {
      print('General Error: $e');

      throw Exception(
        e.toString(),
      );
    }
  }
}