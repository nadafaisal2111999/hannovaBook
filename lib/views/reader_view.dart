import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/book_model.dart';

// كلاس الفصل مع دعم الترجمة
class ReaderChapter {
  final String title;
  final String content;
  String? translatedContent;

  ReaderChapter({
    required this.title,
    required this.content,
    this.translatedContent,
  });
}

class ReaderView extends StatefulWidget {
  final BookModel book;

  const ReaderView({
    super.key,
    required this.book,
  });

  @override
  State<ReaderView> createState() => _ReaderViewState();
}

class _ReaderViewState extends State<ReaderView>
    with SingleTickerProviderStateMixin {
  final Dio _dio = Dio();
  final ScrollController _scrollController = ScrollController();

  String? _bookContent;
  String? _errorMessage;

  bool _isLoading = true;
  bool _isDarkMode = false;

  // متغيرات الترجمة
  bool _isTranslating = false;
  bool _showArabicTranslation = false;

  // بوكس Hive الخاص بحفظ العلامات المرجعية
  late Box _bookmarksBox;
  bool _isHiveInitialized = false;

  int? _bookmarkedChapter;
  double? _bookmarkedScrollOffset;
  String? _bookmarkedText; // النص المحفوظ بدقة
  int? _bookmarkedParagraphIndex; // مؤشر البراجراف المحفوظ لمنع التكرار

  // النص الحالي المظلل بواسطة المستخدم للقراءة أو الحفظ
  String? _currentSelectedText;
  int? _currentSelectedParagraphIndex; // مؤشر البراجراف الحالي المظلل

  double _fontSize = 18;
  double _lineHeight = 1.8;

  int _currentChapter = 0;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  List<ReaderChapter> _chapters = [];

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _scrollController.addListener(_updateProgress);

    // تهيئة Hive واسترجاع العلامة المحفوظة لهذا الكتاب
    _initHiveAndLoadBookmark();
  }

  Future<void> _initHiveAndLoadBookmark() async {
    try {
      _bookmarksBox = await Hive.openBox('book_bookmarks');

      String bookKey = 'book_${widget.book.id ?? widget.book.title}';

      final savedData = _bookmarksBox.get(bookKey);
      if (savedData != null) {
        _bookmarkedChapter = savedData['chapter'];
        _bookmarkedScrollOffset = savedData['offset'];
        _bookmarkedText = savedData['text'];
        _bookmarkedParagraphIndex = savedData['paragraphIndex'];
      }

      setState(() {
        _isHiveInitialized = true;
      });
    } catch (e) {
      setState(() {
        _isHiveInitialized = true;
      });
    }

    _fetchBookText();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateProgress);
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchBookText() async {
    try {
      final String? textUrl =
          widget.book.formats['text/plain'] ??
              widget.book.formats['text/plain; charset=utf-8'] ??
              widget.book.formats['text/plain; charset=us-ascii'];

      if (textUrl == null) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'عذراً، النص غير متوفر بصيغة نصية لهذا الكتاب.';
          _isLoading = false;
        });
        return;
      }

      final response = await _dio.get(
        textUrl,
        options: Options(responseType: ResponseType.plain),
      );

      if (response.statusCode == 200) {
        final String content = _cleanBookText(response.data.toString());
        final chapters = _splitIntoChapters(content);

        if (!mounted) return;

        setState(() {
          _bookContent = content;
          _chapters = chapters;
          _isLoading = false;
        });

        _animationController.forward();
      } else {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'فشل في تحميل محتوى الكتاب (رمز الخطأ: ${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'حدث خطأ أثناء تحميل الكتاب.\nالتفاصيل: $e';
        _isLoading = false;
      });
    }
  }

  String _cleanBookText(String text) {
    String cleaned = text;
    cleaned = cleaned.replaceAll('\r\n', '\n');
    cleaned = cleaned.replaceAll('\r', '\n');
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    cleaned = cleaned.replaceAll(RegExp(r'[ \t]+'), ' ');
    return cleaned.trim();
  }

  List<ReaderChapter> _splitIntoChapters(String text) {
    final RegExp chapterRegex = RegExp(
      r'^(chapter|CHAPTER)\s+([0-9ivxlcdmIVXLCDM]+)',
      caseSensitive: false,
      multiLine: true,
    );

    final matches = chapterRegex.allMatches(text);

    if (matches.isEmpty) {
      return [
        ReaderChapter(title: 'الكتاب كامل', content: text),
      ];
    }

    final List<ReaderChapter> chapters = [];
    final String firstContent = text.substring(0, matches.first.start).trim();
    if (firstContent.isNotEmpty) {
      chapters.add(ReaderChapter(title: 'المقدمة', content: firstContent));
    }

    for (int i = 0; i < matches.length; i++) {
      final match = matches.elementAt(i);
      final int start = match.end;
      final int end = i + 1 < matches.length
          ? matches.elementAt(i + 1).start
          : text.length;

      final String content = text.substring(start, end).trim();

      chapters.add(
        ReaderChapter(
          title: 'الفصل ${i + 1}',
          content: content,
        ),
      );
    }

    return chapters;
  }

  double get _readingProgress {
    if (!_scrollController.hasClients ||
        !_scrollController.position.hasContentDimensions) {
      return 0;
    }
    final double maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return 0;
    return (_scrollController.offset / maxScroll).clamp(0.0, 1.0);
  }

  void _updateProgress() {
    if (mounted) setState(() {});
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  void _nextChapter() {
    if (_currentChapter >= _chapters.length - 1) return;
    setState(() {
      _currentChapter++;
      _showArabicTranslation = false;
      _currentSelectedText = null;
      _currentSelectedParagraphIndex = null;
    });
    _scrollToTop();
  }

  void _previousChapter() {
    if (_currentChapter <= 0) return;
    setState(() {
      _currentChapter--;
      _showArabicTranslation = false;
      _currentSelectedText = null;
      _currentSelectedParagraphIndex = null;
    });
    _scrollToTop();
  }

  void _selectChapter(int index) {
    Navigator.pop(context);
    setState(() {
      _currentChapter = index;
      _showArabicTranslation = false;
      _currentSelectedText = null;
      _currentSelectedParagraphIndex = null;
    });
    _scrollToTop();
  }

  // حفظ النص المختار مع رقم البراجراف بدقة تامة في Hive
  Future<void> _saveCurrentBookmark() async {
    String bookKey = 'book_${widget.book.id ?? widget.book.title}';

    setState(() {
      String? textToSave = _currentSelectedText ?? _bookmarkedText;
      int? paragraphIdxToSave = _currentSelectedParagraphIndex ?? _bookmarkedParagraphIndex;

      _bookmarkedChapter = _currentChapter;
      _bookmarkedScrollOffset = _scrollController.offset;
      _bookmarkedText = textToSave;
      _bookmarkedParagraphIndex = paragraphIdxToSave;

      if (_isHiveInitialized) {
        _bookmarksBox.put(bookKey, {
          'chapter': _bookmarkedChapter,
          'offset': _bookmarkedScrollOffset,
          'text': _bookmarkedText,
          'paragraphIndex': _bookmarkedParagraphIndex,
        });
      }

      String msg = textToSave != null && textToSave.isNotEmpty
          ? 'تم تظليل وحفظ النص في مكانه الصحيح بدقة 📌'
          : 'تم حفظ علامة الفصل بنجاح 📌';

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    });
  }

  // العودة للمكان أو النص المحفوظ بدقة
  void _goToBookmark() async {
    if (_bookmarkedChapter == null) return;

    final targetChapter = _bookmarkedChapter!;
    final targetOffset = _bookmarkedScrollOffset ?? 0.0;

    setState(() {
      _currentChapter = targetChapter;
      _showArabicTranslation = false;
    });

    for (int i = 0; i < 5; i++) {
      await Future.delayed(Duration(milliseconds: 100 * (i + 1)));

      if (_scrollController.hasClients) {
        final maxExtent = _scrollController.position.maxScrollExtent;
        if (maxExtent > 0) {
          _scrollController.jumpTo(math.min(targetOffset, maxExtent));
          break;
        }
      }
    }
  }

  Future<void> _translateCurrentChapter() async {
    if (_showArabicTranslation) {
      setState(() {
        _showArabicTranslation = false;
      });
      return;
    }

    if (_chapters[_currentChapter].translatedContent != null) {
      setState(() {
        _showArabicTranslation = true;
      });
      return;
    }

    setState(() {
      _isTranslating = true;
    });

    try {
      final originalText = _chapters[_currentChapter].content;
      final response = await _dio.get(
        'https://api.mymemory.translated.net/get',
        queryParameters: {
          'q': originalText.length > 500 ? originalText.substring(0, 500) : originalText,
          'langpair': 'en|ar',
        },
      );

      if (response.statusCode == 200) {
        String translated = response.data['responseData']['translatedText'] ?? 'عذراً، تعذر ترجمة هذا النص.';

        setState(() {
          _chapters[_currentChapter].translatedContent =
          "--- (ترجمة الفصل) ---\n\n$translated\n\n[ملاحظة: الترجمة تتم آلياً]";
          _showArabicTranslation = true;
          _isTranslating = false;
        });
      } else {
        throw Exception();
      }
    } catch (e) {
      setState(() {
        _isTranslating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ أثناء الاتصال بخدمة الترجمة')),
      );
    }
  }

  void _showChapters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _buildChaptersSheet(),
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _buildSettingsSheet(),
    );
  }

  Color get _backgroundColor => _isDarkMode ? const Color(0xFF101114) : const Color(0xFFF7F3EA);
  Color get _surfaceColor => _isDarkMode ? const Color(0xFF191B20) : Colors.white;
  Color get _textColor => _isDarkMode ? const Color(0xFFE7E7EA) : const Color(0xFF292929);
  Color get _secondaryTextColor => _isDarkMode ? const Color(0xFF9EA3AE) : const Color(0xFF777777);

  @override
  Widget build(BuildContext context) {
    bool hasBookmark = _bookmarkedChapter != null;

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            if (!_isLoading && _errorMessage == null) _buildProgressBar(),
            Expanded(child: _buildBody()),
            if (!_isLoading && _errorMessage == null) _buildBottomControls(),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_currentSelectedText != null && _currentSelectedText!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FloatingActionButton.extended(
                onPressed: _saveCurrentBookmark,
                icon: const Icon(Icons.bookmark_add_rounded),
                label: const Text('تظليل وحفظ النص 📌'),
                backgroundColor: Colors.green,
              ),
            ),
          if (hasBookmark && (_currentSelectedText == null || _currentSelectedText!.isEmpty))
            FloatingActionButton.extended(
              onPressed: _goToBookmark,
              icon: const Icon(Icons.push_pin_rounded),
              label: Text(_bookmarkedText != null && _bookmarkedText!.isNotEmpty
                  ? 'الذهاب للنص المظلل 📍'
                  : 'الذهاب للعلامة'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          SizedBox(height: 40)
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 3,
      width: double.infinity,
      child: LinearProgressIndicator(
        value: _readingProgress,
        backgroundColor: _isDarkMode ? Colors.white10 : Colors.black12,
        valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return _buildLoading();
    if (_errorMessage != null) return _buildError();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildChapterHeader()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 60),
            sliver: SliverToBoxAdapter(child: _buildBookContent()),
          ),
          SliverToBoxAdapter(child: _buildChapterNavigation()),
          const SliverToBoxAdapter(child: SizedBox(height: 50)),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(.1),
              shape: BoxShape.circle,
            ),
            child: const Center(child: CircularProgressIndicator(strokeWidth: 3)),
          ),
          const SizedBox(height: 24),
          Text('جاري تجهيز الكتاب...', style: TextStyle(color: _textColor, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('لحظات ونبدأ القراءة 📖', style: TextStyle(color: _secondaryTextColor, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(color: Colors.red.withOpacity(.08), shape: BoxShape.circle),
              child: const Icon(Icons.menu_book_rounded, size: 42, color: Colors.redAccent),
            ),
            const SizedBox(height: 24),
            Text('مش قادرين نفتح الكتاب', style: TextStyle(color: _textColor, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: _secondaryTextColor, height: 1.6)),
            const SizedBox(height: 25),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _fetchBookText();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('حاول مرة أخرى'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    bool isCurrentBookmarked = _bookmarkedChapter == _currentChapter;

    return Container(
      color: _surfaceColor,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          _readerIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('NOW READING', style: TextStyle(color: _secondaryTextColor, fontSize: 9, letterSpacing: 1.4, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(widget.book.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _textColor, fontSize: 14, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _readerIconButton(
            icon: _isTranslating ? Icons.hourglass_top : (_showArabicTranslation ? Icons.translate : Icons.g_translate),
            color: _showArabicTranslation ? Theme.of(context).colorScheme.primary : null,
            onTap: _isTranslating ? () {} : _translateCurrentChapter,
          ),
          const SizedBox(width: 8),
          _readerIconButton(
            icon: isCurrentBookmarked ? Icons.push_pin_rounded : Icons.push_pin_outlined,
            color: isCurrentBookmarked ? Colors.amber[700] : null,
            onTap: _saveCurrentBookmark,
          ),
        ],
      ),
    );
  }

  Widget _readerIconButton({required IconData icon, required VoidCallback onTap, Color? color}) {
    return Material(
      color: _backgroundColor,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: color ?? _textColor, size: 20),
        ),
      ),
    );
  }

  Widget _buildChapterHeader() {
    final chapter = _chapters.isNotEmpty
        ? _chapters[_currentChapter]
        : ReaderChapter(title: 'الكتاب كامل', content: _bookContent ?? '');

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 25, 24, 25),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              '${_currentChapter + 1} / ${math.max(_chapters.length, 1)}',
              style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            chapter.title,
            textAlign: TextAlign.center,
            style: TextStyle(color: _textColor, fontSize: 27, height: 1.25, fontWeight: FontWeight.w900, letterSpacing: -.4),
          ),
          if (_showArabicTranslation) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: const Text('مترجم إلى العربية', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
          const SizedBox(height: 10),
          Container(width: 45, height: 4, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(10))),
        ],
      ),
    );
  }

  // محتوى الكتاب مع مطابقة رقم البراجراف حصرياً لمنع تكرار التظليل في براجرافات أخرى
  Widget _buildBookContent() {
    if (_chapters.isEmpty) return const SizedBox();

    final chapter = _chapters[_currentChapter];
    final content = (_showArabicTranslation && chapter.translatedContent != null)
        ? chapter.translatedContent!
        : chapter.content;

    final paragraphs = content.split(RegExp(r'\n\s*\n')).where((p) => p.trim().isNotEmpty).toList();

    final bool isThisChapterBookmarked = _bookmarkedChapter == _currentChapter;
    final String? savedText = (isThisChapterBookmarked && _bookmarkedText != null && _bookmarkedText!.isNotEmpty)
        ? _bookmarkedText
        : null;
    final int? savedParagraphIdx = isThisChapterBookmarked ? _bookmarkedParagraphIndex : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < paragraphs.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              // الشرط الحاسم: التظليل يتم فقط إذا كان رقم البراجراف الحالي مطابقاً تماماً لرقم البراجراف المحفوظ
              child: (savedText != null && savedParagraphIdx == i && paragraphs[i].contains(savedText))
                  ? _buildHighlightedParagraph(paragraphs[i], savedText)
                  : SelectableText(
                paragraphs[i].trim(),
                textAlign: TextAlign.justify,
                textDirection: _showArabicTranslation ? TextDirection.rtl : TextDirection.ltr,
                style: TextStyle(
                  color: _textColor,
                  fontSize: _fontSize,
                  height: _lineHeight,
                  letterSpacing: .15,
                  fontWeight: FontWeight.w400,
                ),
                onSelectionChanged: (selection, cause) {
                  if (!selection.isCollapsed) {
                    final fullText = paragraphs[i].trim();
                    final start = selection.start.clamp(0, fullText.length);
                    final end = selection.end.clamp(0, fullText.length);
                    if (start < end) {
                      final selectedText = fullText.substring(start, end);
                      if (selectedText.isNotEmpty) {
                        setState(() {
                          _currentSelectedText = selectedText;
                          _currentSelectedParagraphIndex = i; // حفظ مؤشر البراجراف الحالي
                        });
                      }
                    }
                  } else {
                    if (_currentSelectedText != null) {
                      setState(() {
                        _currentSelectedText = null;
                        _currentSelectedParagraphIndex = null;
                      });
                    }
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  // دالة تظليل دقيقة للبراجراف المستهدف فقط
  Widget _buildHighlightedParagraph(String paragraph, String savedText) {
    final int index = paragraph.indexOf(savedText);
    if (index == -1) {
      return SelectableText(
        paragraph.trim(),
        style: TextStyle(color: _textColor, fontSize: _fontSize, height: _lineHeight),
      );
    }

    final String before = paragraph.substring(0, index);
    final String target = savedText;
    final String after = paragraph.substring(index + savedText.length);

    return SelectableText.rich(
      TextSpan(
        style: TextStyle(
          color: _textColor,
          fontSize: _fontSize,
          height: _lineHeight,
          fontWeight: FontWeight.w400,
        ),
        children: [
          TextSpan(text: before),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _isDarkMode ? Colors.amber.withOpacity(0.3) : Colors.amber.shade200,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.amber.shade700, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('📌 ', style: TextStyle(fontSize: 12)),
                  Text(
                    target,
                    style: TextStyle(
                      color: _isDarkMode ? Colors.white : Colors.black87,
                      fontSize: _fontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          TextSpan(text: after),
        ],
      ),
      textAlign: TextAlign.justify,
      textDirection: _showArabicTranslation ? TextDirection.rtl : TextDirection.ltr,
    );
  }

  Widget _buildChapterNavigation() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: _chapterButton(
              icon: Icons.arrow_back_ios_new_rounded,
              label: 'السابق',
              enabled: _currentChapter > 0,
              onTap: _previousChapter,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _chapterButton(
              icon: Icons.arrow_forward_ios_rounded,
              label: 'التالي',
              enabled: _currentChapter < _chapters.length - 1,
              onTap: _nextChapter,
              reverse: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chapterButton({
    required IconData icon,
    required String label,
    required bool enabled,
    required VoidCallback onTap,
    bool reverse = false,
  }) {
    final primary = Theme.of(context).colorScheme.primary;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1 : .35,
      child: Material(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!reverse) ...[Icon(icon, size: 16, color: primary), const SizedBox(width: 8)],
                Text(label, style: TextStyle(color: _textColor, fontWeight: FontWeight.w800)),
                if (reverse) ...[const SizedBox(width: 8), Icon(icon, size: 16, color: primary)],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceColor,
        boxShadow: [
          BoxShadow(blurRadius: 20, offset: const Offset(0, -5), color: Colors.black.withOpacity(.08)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Row(
        children: [
          _bottomAction(icon: Icons.list_rounded, label: 'الفصول', onTap: _showChapters),
          _bottomAction(icon: Icons.text_fields_rounded, label: 'النص', onTap: _showSettings),
          _bottomAction(
            icon: _isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            label: _isDarkMode ? 'فاتح' : 'داكن',
            onTap: () => setState(() => _isDarkMode = !_isDarkMode),
          ),
        ],
      ),
    );
  }

  Widget _bottomAction({required IconData icon, required String label, required VoidCallback onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 21, color: _textColor),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: _secondaryTextColor, fontSize: 10, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChaptersSheet() {
    return Container(
      height: MediaQuery.of(context).size.height * .75,
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 45, height: 5, decoration: BoxDecoration(color: _secondaryTextColor.withOpacity(.3), borderRadius: BorderRadius.circular(20))),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              children: [
                Icon(Icons.menu_book_rounded, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Text('فصول الكتاب', style: TextStyle(color: _textColor, fontSize: 21, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          const SizedBox(height: 15),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 5, 16, 25),
              physics: const BouncingScrollPhysics(),
              itemCount: _chapters.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final isSelected = index == _currentChapter;
                return Material(
                  color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(17),
                  child: InkWell(
                    onTap: () => _selectChapter(index),
                    borderRadius: BorderRadius.circular(17),
                    child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isSelected ? Theme.of(context).colorScheme.primary : _backgroundColor,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(color: isSelected ? Colors.white : _secondaryTextColor, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              _chapters[index].title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: _textColor, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600),
                            ),
                          ),
                          if (isSelected) Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary),
                        ],
                      ),
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

  Widget _buildSettingsSheet() {
    return StatefulBuilder(
      builder: (context, setSheetState) {
        return Container(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 30),
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 45, height: 5, decoration: BoxDecoration(color: _secondaryTextColor.withOpacity(.3), borderRadius: BorderRadius.circular(20))),
              const SizedBox(height: 22),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('إعدادات القراءة', style: TextStyle(color: _textColor, fontSize: 21, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Icon(Icons.format_size_rounded, color: _secondaryTextColor),
                  const SizedBox(width: 12),
                  Text('حجم الخط', style: TextStyle(color: _textColor, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text('${_fontSize.toInt()}', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w900)),
                ],
              ),
              Slider(
                value: _fontSize,
                min: 14,
                max: 30,
                divisions: 8,
                onChanged: (value) {
                  setState(() => _fontSize = value);
                  setSheetState(() {});
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.format_line_spacing_rounded, color: _secondaryTextColor),
                  const SizedBox(width: 12),
                  Text('تباعد السطور', style: TextStyle(color: _textColor, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text(_lineHeight.toStringAsFixed(1), style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w900)),
                ],
              ),
              Slider(
                value: _lineHeight,
                min: 1.4,
                max: 2.4,
                divisions: 10,
                onChanged: (value) {
                  setState(() => _lineHeight = value);
                  setSheetState(() {});
                },
              ),
            ],
          ),
        );
      },
    );
  }
}