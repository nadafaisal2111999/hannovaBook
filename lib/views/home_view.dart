import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/book_model.dart';
import '../services/book_service.dart';
import 'UserProfileView.dart';
import 'reader_view.dart';
import 'fav.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late Future<List<BookModel>> _booksFuture;

  final TextEditingController _searchController =
  TextEditingController();

  String _searchQuery = '';
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();

    _booksFuture = BookService().fetchBooks();

    _searchController.addListener(() {
      if (!mounted) return;

      setState(() {
        _searchQuery =
            _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _booksFuture = BookService().fetchBooks();
    });

    await _booksFuture;
  }

  List<BookModel> _filterBooks(
      List<BookModel> books) {
    if (_searchQuery.isEmpty) {
      return books;
    }

    return books.where((book) {
      final title = book.title.toLowerCase();

      final authors = book.authors
          .join(' ')
          .toLowerCase();

      return title.contains(_searchQuery) ||
          authors.contains(_searchQuery);
    }).toList();
  }

  void _clearSearch() {
    _searchController.clear();

    FocusScope.of(context).unfocus();
  }

  void _openReader(BookModel book) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReaderView(book: book),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FC),

      body: SafeArea(
        child: FutureBuilder<List<BookModel>>(
          future: _booksFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return _buildLoading();
            }

            if (snapshot.hasError) {
              return _buildError();
            }

            final allBooks =
                snapshot.data ?? [];

            final books =
            _filterBooks(allBooks);

            return RefreshIndicator(
              color: const Color(0xFF6C63FF),
              onRefresh: _refresh,
              child: CustomScrollView(
                physics:
                const BouncingScrollPhysics(
                  parent:
                  AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildHeader(),
                  ),

                  SliverToBoxAdapter(
                    child: _buildSearch(),
                  ),

                  // =========================
                  // SEARCH EMPTY STATE
                  // =========================
                  if (_searchQuery.isNotEmpty &&
                      books.isEmpty)
                    SliverToBoxAdapter(
                      child: _buildSearchEmpty(),
                    ),

                  // =========================
                  // NORMAL HOME
                  // =========================
                  if (_searchQuery.isEmpty &&
                      books.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: _buildSectionTitle(
                        'Featured',
                        'اختيار مميز لك',
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: _buildFeaturedBook(
                        books.first,
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: _buildSectionTitle(
                        'Popular Books',
                        'الأكثر شعبية',
                      ),
                    ),
                  ],

                  // =========================
                  // BOOK LIST
                  // =========================
                  if (books.isNotEmpty)
                    SliverPadding(
                      padding:
                      const EdgeInsets.fromLTRB(
                        20,
                        0,
                        20,
                        30,
                      ),
                      sliver: SliverList(
                        delegate:
                        SliverChildBuilderDelegate(
                              (context, index) {
                            return _AnimatedBookCard(
                              book: books[index],
                              index: index,
                              onTap: () =>
                                  _openReader(
                                    books[index],
                                  ),
                            );
                          },
                          childCount: books.length,
                        ),
                      ),
                    ),

                  // =========================
                  // NO BOOKS AT ALL
                  // =========================
                  if (books.isEmpty &&
                      _searchQuery.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildNoBooks(),
                    ),
                ],
              ),
            );
          },
        ),
      ),

      bottomNavigationBar:
      _buildBottomNavigation(),
    );
  }

  // =========================================================
  // HEADER
  // =========================================================

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        20,
        20,
        12,
      ),
      child:Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مرحباً بك 👋',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'اكتشف عالم الكتب',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 44,
            height: 44,
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.contain,
            ),
          ),
        ],
      )
    );
  }

  // =========================================================
  // SEARCH
  // =========================================================

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        8,
        20,
        24,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
          BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color:
              Colors.black.withOpacity(.05),
              blurRadius: 20,
              offset:
              const Offset(0, 8),
            ),
          ],
        ),
        child: TextField(
          controller:
          _searchController,
          textInputAction:
          TextInputAction.search,
          decoration: InputDecoration(
            hintText:
            'ابحث عن كتاب أو مؤلف...',
            hintStyle: TextStyle(
              color:
              Colors.grey.shade400,
              fontSize: 14,
            ),

            prefixIcon:
            const Icon(
              Icons.search_rounded,
              color:
              Color(0xFF6C63FF),
            ),

            suffixIcon:
            _searchQuery.isNotEmpty
                ? IconButton(
              onPressed:
              _clearSearch,
              icon: const Icon(
                Icons
                    .close_rounded,
              ),
            )
                : null,

            border:
            InputBorder.none,

            contentPadding:
            const EdgeInsets.symmetric(
              vertical: 18,
              horizontal: 10,
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // SEARCH EMPTY
  // =========================================================

  Widget _buildSearchEmpty() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        25,
        45,
        25,
        80,
      ),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color:
              const Color(0xFFEDEBFF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off_rounded,
              size: 48,
              color:
              Color(0xFF6C63FF),
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'مفيش نتائج 😔',
            textAlign:
            TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight:
              FontWeight.w800,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            'ملقيناش كتاب أو مؤلف باسم\n'
                '"$_searchQuery"',
            textAlign:
            TextAlign.center,
            style: TextStyle(
              color:
              Colors.grey.shade600,
              fontSize: 14,
              height: 1.6,
            ),
          ),

          const SizedBox(height: 25),

          ElevatedButton.icon(
            onPressed:
            _clearSearch,
            style:
            ElevatedButton.styleFrom(
              backgroundColor:
              const Color(
                  0xFF6C63FF),
              foregroundColor:
              Colors.white,
              elevation: 0,
              padding:
              const EdgeInsets.symmetric(
                horizontal: 22,
                vertical: 13,
              ),
              shape:
              RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(
                    15),
              ),
            ),
            icon: const Icon(
              Icons.refresh_rounded,
            ),
            label: const Text(
              'عرض كل الكتب',
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // SECTION TITLE
  // =========================================================

  Widget _buildSectionTitle(
      String title,
      String subtitle,
      ) {
    return Padding(
      padding:
      const EdgeInsets.fromLTRB(
        20,
        4,
        20,
        14,
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                  const TextStyle(
                    fontSize: 21,
                    fontWeight:
                    FontWeight.w800,
                  ),
                ),

                const SizedBox(
                    height: 3),

                Text(
                  subtitle,
                  style: TextStyle(
                    color:
                    Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          const Icon(
            Icons
                .arrow_forward_ios_rounded,
            size: 14,
            color:
            Color(0xFF6C63FF),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // FEATURED BOOK
  // =========================================================

  Widget _buildFeaturedBook(
      BookModel book) {
    return Padding(
      padding:
      const EdgeInsets.fromLTRB(
        20,
        0,
        20,
        28,
      ),
      child: GestureDetector(
        onTap: () =>
            _openReader(book),
        child: Container(
          height: 210,
          decoration:
          BoxDecoration(
            borderRadius:
            BorderRadius.circular(
                28),

            gradient:
            const LinearGradient(
              begin:
              Alignment.topLeft,
              end:
              Alignment.bottomRight,
              colors: [
                Color(0xFF6C63FF),
                Color(0xFF5148D8),
              ],
            ),

            boxShadow: [
              BoxShadow(
                color:
                const Color(
                  0xFF6C63FF,
                ).withOpacity(.25),
                blurRadius: 25,
                offset:
                const Offset(
                  0,
                  12,
                ),
              ),
            ],
          ),

          child: Row(
            children: [
              Padding(
                padding:
                const EdgeInsets.all(
                    18),
                child: ClipRRect(
                  borderRadius:
                  BorderRadius.circular(
                      16),
                  child:
                  book.coverUrl != null
                      ? Image.network(
                    book.coverUrl!,
                    width: 115,
                    height: 174,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, __, ___) =>
                        _featuredPlaceholder(),
                  )
                      : _featuredPlaceholder(),
                ),
              ),

              Expanded(
                child: Padding(
                  padding:
                  const EdgeInsets.fromLTRB(
                    0,
                    24,
                    20,
                    24,
                  ),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                    mainAxisAlignment:
                    MainAxisAlignment
                        .center,
                    children: [
                      Container(
                        padding:
                        const EdgeInsets
                            .symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration:
                        BoxDecoration(
                          color:
                          Colors.white24,
                          borderRadius:
                          BorderRadius
                              .circular(
                              20),
                        ),
                        child:
                        const Text(
                          'FEATURED',
                          style:
                          TextStyle(
                            color:
                            Colors.white,
                            fontSize: 10,
                            fontWeight:
                            FontWeight
                                .bold,
                            letterSpacing:
                            1,
                          ),
                        ),
                      ),

                      const SizedBox(
                          height: 12),

                      Text(
                        book.title,
                        maxLines: 3,
                        overflow:
                        TextOverflow
                            .ellipsis,
                        style:
                        const TextStyle(
                          color:
                          Colors.white,
                          fontSize: 19,
                          fontWeight:
                          FontWeight
                              .w800,
                          height: 1.2,
                        ),
                      ),

                      const SizedBox(
                          height: 8),

                      Text(
                        book.authors
                            .isNotEmpty
                            ? book.authors
                            .first
                            : 'Unknown Author',
                        maxLines: 1,
                        overflow:
                        TextOverflow
                            .ellipsis,
                        style:
                        const TextStyle(
                          color:
                          Colors.white70,
                          fontSize: 12,
                        ),
                      ),

                      const Spacer(),

                      Container(
                        padding:
                        const EdgeInsets
                            .symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration:
                        BoxDecoration(
                          color:
                          Colors.white,
                          borderRadius:
                          BorderRadius
                              .circular(
                              14),
                        ),
                        child:
                        const Row(
                          mainAxisSize:
                          MainAxisSize.min,
                          children: [
                            Text(
                              'ابدأ القراءة',
                              style:
                              TextStyle(
                                color:
                                Color(
                                  0xFF5148D8,
                                ),
                                fontWeight:
                                FontWeight
                                    .bold,
                                fontSize:
                                12,
                              ),
                            ),
                            SizedBox(
                                width: 6),
                            Icon(
                              Icons
                                  .arrow_forward_rounded,
                              size: 15,
                              color:
                              Color(
                                0xFF5148D8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featuredPlaceholder() {
    return Container(
      width: 115,
      height: 174,
      color: Colors.white24,
      child: const Icon(
        Icons.menu_book_rounded,
        color: Colors.white,
        size: 45,
      ),
    );
  }

  // =========================================================
  // BOTTOM NAVIGATION
  // =========================================================

  Widget _buildBottomNavigation() {
    return NavigationBar(
      height: 72,
      selectedIndex: _currentIndex,
      onDestinationSelected: (index) {
        setState(() {
          _currentIndex = index;
        });

        if (index == 1) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const Fav(),
            ),
          );
        } else if (index == 2) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const UserProfileView(),
            ),
          );
        }
      },
      backgroundColor: Colors.white,
      elevation: 10,
      indicatorColor: const Color(0xFFEDEBFF),
      destinations: const [
        NavigationDestination(
          icon: Icon(
            Icons.home_outlined,
          ),
          selectedIcon: Icon(
            Icons.home_rounded,
          ),
          label: 'الرئيسية',
        ),
        NavigationDestination(
          icon: Icon(
            Icons.bookmark_border_rounded,
          ),
          selectedIcon: Icon(
            Icons.bookmark_rounded,
          ),
          label: 'المحفوظات',
        ),
        NavigationDestination(
            icon: Icon(
              Icons.person_outline_rounded,
            ),
            selectedIcon: Icon(
              Icons.person_rounded,
            ),
            label: 'حسابي',
        ),
      ],
    );
  }

  // =========================================================
  // LOADING
  // =========================================================

  Widget _buildLoading() {
    return ListView(
      padding:
      const EdgeInsets.all(20),
      children: [
        Container(
          height: 40,
          width: 180,
          decoration:
          BoxDecoration(
            color:
            Colors.grey.shade200,
            borderRadius:
            BorderRadius.circular(
                10),
          ),
        ),

        const SizedBox(height: 20),

        Container(
          height: 55,
          decoration:
          BoxDecoration(
            color:
            Colors.grey.shade200,
            borderRadius:
            BorderRadius.circular(
                18),
          ),
        ),

        const SizedBox(height: 30),

        Container(
          height: 210,
          decoration:
          BoxDecoration(
            color:
            Colors.grey.shade200,
            borderRadius:
            BorderRadius.circular(
                28),
          ),
        ),

        const SizedBox(height: 30),

        ...List.generate(
          5,
              (index) => Container(
            height: 105,
            margin:
            const EdgeInsets.only(
              bottom: 14,
            ),
            decoration:
            BoxDecoration(
              color:
              Colors.grey.shade200,
              borderRadius:
              BorderRadius.circular(
                  20),
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================
  // ERROR
  // =========================================================

  Widget _buildError() {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration:
              const BoxDecoration(
                color:
                Color(0xFFFFEEEE),
                shape:
                BoxShape.circle,
              ),
              child: const Icon(
                Icons
                    .wifi_off_rounded,
                size: 40,
                color:
                Colors.redAccent,
              ),
            ),

            const SizedBox(
                height: 20),

            const Text(
              'يبدو أن هناك مشكلة في الاتصال',
              textAlign:
              TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight:
                FontWeight.bold,
              ),
            ),

            const SizedBox(
                height: 8),

            Text(
              'تأكدي من اتصال الإنترنت وحاولي مرة أخرى.',
              textAlign:
              TextAlign.center,
              style: TextStyle(
                color:
                Colors.grey.shade600,
              ),
            ),

            const SizedBox(
                height: 25),

            FilledButton.icon(
              onPressed: _refresh,
              icon: const Icon(
                Icons
                    .refresh_rounded,
              ),
              label: const Text(
                'إعادة المحاولة',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // NO BOOKS
  // =========================================================

  Widget _buildNoBooks() {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Icon(
              Icons
                  .menu_book_rounded,
              size: 70,
              color:
              Colors.grey.shade300,
            ),

            const SizedBox(
                height: 20),

            const Text(
              'لم نجد أي كتب',
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                FontWeight.bold,
              ),
            ),

            const SizedBox(
                height: 8),

            Text(
              'حاولي تحديث الصفحة مرة أخرى.',
              style: TextStyle(
                color:
                Colors.grey.shade600,
              ),
            ),

            const SizedBox(
                height: 20),

            OutlinedButton.icon(
              onPressed: _refresh,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text(
                'تحديث',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================
// BOOK CARD
// ===========================================================

class _AnimatedBookCard
    extends StatefulWidget {
  final BookModel book;
  final int index;
  final VoidCallback onTap;

  const _AnimatedBookCard({
    required this.book,
    required this.index,
    required this.onTap,
  });

  @override
  State<_AnimatedBookCard>
  createState() =>
      _AnimatedBookCardState();
}

class _AnimatedBookCardState
    extends State<_AnimatedBookCard>
    with
        SingleTickerProviderStateMixin {
  late AnimationController
  _controller;

  late Animation<double>
  _animation;

  @override
  void initState() {
    super.initState();

    _controller =
        AnimationController(
          vsync: this,
          duration:
          const Duration(
            milliseconds: 500,
          ),
        );

    _animation =
        CurvedAnimation(
          parent: _controller,
          curve:
          Curves.easeOutCubic,
        );

    Future.delayed(
      Duration(
        milliseconds:
        widget.index * 70,
      ),
          () {
        if (mounted) {
          _controller.forward();
        }
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(
      BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child:
      SlideTransition(
        position:
        Tween<Offset>(
          begin:
          const Offset(0, .12),
          end: Offset.zero,
        ).animate(
          _animation,
        ),
        child:
        _buildCard(),
      ),
    );
  }

  Widget _buildCard() {
    final favBox = Hive.box('favorites');

    return ValueListenableBuilder(
      valueListenable: favBox.listenable(),
      builder: (context, Box box, _) {
        bool isFav = box.containsKey(widget.book.id);

        return GestureDetector(
          onTap: widget.onTap,
          child: Container(
            margin:
            const EdgeInsets.only(
              bottom: 14,
            ),
            padding:
            const EdgeInsets.all(
              10,
            ),
            decoration:
            BoxDecoration(
              color: Colors.white,
              borderRadius:
              BorderRadius.circular(
                  22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withOpacity(.045),
                  blurRadius: 18,
                  offset:
                  const Offset(
                    0,
                    7,
                  ),
                ),
              ],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius:
                  BorderRadius.circular(
                      14),
                  child:
                  widget.book.coverUrl !=
                      null
                      ? Image.network(
                    widget.book
                        .coverUrl!,
                    width: 72,
                    height: 96,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, __, ___) =>
                        _placeholder(),
                  )
                      : _placeholder(),
                ),

                const SizedBox(
                    width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                    children: [
                      Text(
                        widget.book.title,
                        maxLines: 2,
                        overflow:
                        TextOverflow
                            .ellipsis,
                        style:
                        const TextStyle(
                          fontSize: 16,
                          fontWeight:
                          FontWeight.w800,
                          height: 1.25,
                        ),
                      ),

                      const SizedBox(
                          height: 8),

                      Text(
                        widget.book
                            .authors
                            .isNotEmpty
                            ? widget.book
                            .authors
                            .join(', ')
                            : 'مؤلف غير معروف',
                        maxLines: 1,
                        overflow:
                        TextOverflow
                            .ellipsis,
                        style: TextStyle(
                          color:
                          Colors.grey
                              .shade600,
                          fontSize: 12,
                        ),
                      ),

                      const SizedBox(
                          height: 12),

                      Row(
                        children: [
                          Container(
                            padding:
                            const EdgeInsets
                                .symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration:
                            BoxDecoration(
                              color:
                              const Color(
                                0xFFEDEBFF,
                              ),
                              borderRadius:
                              BorderRadius
                                  .circular(
                                  8),
                            ),
                            child:
                            const Text(
                              'FREE',
                              style:
                              TextStyle(
                                color:
                                Color(
                                  0xFF6C63FF,
                                ),
                                fontWeight:
                                FontWeight
                                    .bold,
                                fontSize:
                                10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // زرار الحفظ (Bookmark)
                IconButton(
                  icon: Icon(
                    isFav
                        ? Icons.bookmark
                        : Icons.bookmark_border,
                    color:
                    const Color(0xFF6C63FF),
                  ),
                  onPressed: () {
                    if (isFav) {
                      box.delete(widget.book.id);
                    } else {
                      box.put(widget.book.id, {
                        'id': widget.book.id,
                        'title': widget.book.title,
                        'authors': widget.book.authors,
                        'coverUrl': widget.book.coverUrl,
                        'formats': widget.book.formats,
                        'subjects': widget.book.subjects,
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _placeholder() {
    return Container(
      width: 72,
      height: 96,
      decoration: BoxDecoration(
        color: const Color(0xFFEDEBFF),
        borderRadius:
        BorderRadius.circular(14),
      ),
      child: const Icon(
        Icons.menu_book_rounded,
        color: Color(0xFF6C63FF),
        size: 30,
      ),
    );
  }
}