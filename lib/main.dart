import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'app/app_navigation.dart';
import 'app/app_services.dart';
import 'app/app_session.dart';
import 'app/app_state.dart';
import 'core/utils/api_exception.dart';
import 'services/beds_service.dart';
import 'data/dummy_properties.dart';
import 'models/property.dart';
import 'services/buildings_service.dart';
import 'widgets/async_state_widgets.dart';
import 'widgets/hostel_full_details_view.dart';
import 'widgets/property_image.dart';

/// Live catalog from API (falls back to [allDummyProperties] offline).
final ValueNotifier<List<Property>> propertyCatalogNotifier =
    ValueNotifier<List<Property>>(allDummyProperties);

final ValueNotifier<PlatformStats?> platformStatsNotifier = ValueNotifier<PlatformStats?>(null);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await AppServices.init();
  AppServices.apiClient.onUnauthorized = () async {
    await AppSession.logout();
    AppNavigation.goToProfileSignIn();
  };
  runApp(const LivoraApp());
  unawaited(_bootstrapCatalog());
}

Future<void> _bootstrapCatalog() async {
  try {
    final results = await Future.wait([
      AppServices.buildings.fetchPublicBuildings(),
      AppServices.buildings.fetchPublicStats(),
    ]);
    final buildings = results[0] as List<Property>;
    if (buildings.isNotEmpty) {
      propertyCatalogNotifier.value = buildings;
    }
    platformStatsNotifier.value = results[1] as PlatformStats;
  } catch (_) {
    // Keep offline dummy data; tell user when live catalog could not load.
    scaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(
        content: Text(
          'Could not load live hostels. Showing offline catalog. Check your internet connection.',
        ),
        duration: Duration(seconds: 4),
      ),
    );
  }
}

class LivoraApp extends StatelessWidget {
  const LivoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Livora | Digital Hostel Home',
      scaffoldMessengerKey: scaffoldMessengerKey,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)),
        useMaterial3: true,
      ),
      home: const AppRoot(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Splash: restore session, then welcome or main shell.
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await AppSession.hydrateFromStorage();
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
        ),
      );
    }
    if (AppServices.auth.isLoggedIn.value) {
      return const MainScreen();
    }
    return const WelcomeScreen();
  }
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeIn)),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic)),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF4F46E5),
                  Color(0xFF3730A3),
                  Color(0xFF1E1B4B),
                ],
              ),
            ),
          ),
          
          // Subtle Pattern Overlay
          Opacity(
            opacity: 0.05,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5),
              itemBuilder: (context, index) => Icon(Icons.home_outlined, color: Colors.white, size: 40),
            ),
          ),
          
          // Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: Colors.white.withOpacity(0.2)),
                            ),
                            child: const Text(
                              'WELCOME TO ELITE LIVING',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Livora',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 64,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.5,
                              height: 1,
                            ),
                          ),
                          const Text(
                            'Ultimate Hostel\nExperience',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.w300,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Discover a new standard of living with premium hostels tailored for your comfort and growth.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 56),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const MainScreen()),
                          );
                          AppNavigation.goToHome();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF4F46E5),
                          padding: const EdgeInsets.symmetric(vertical: 22),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 10,
                          shadowColor: Colors.black.withOpacity(0.3),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                'Explore Hostels',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: 12),
                            Icon(Icons.arrow_forward_rounded, size: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Text(
                        'Premium • Trusted • Secure',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 12,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const List<Widget> _pages = <Widget>[
    HomeScreen(),
    ExploreScreen(),
    ResidentPortalScreen(),
    SavedScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: mainTabIndexNotifier,
      builder: (context, selectedIndex, child) {
        return Scaffold(
          body: _pages[selectedIndex],
          bottomNavigationBar: Container(
            margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            height: 75,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(35),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F46E5).withOpacity(0.2),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(35),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(0, Icons.home_rounded, 'Home', selectedIndex),
                    _buildNavItem(1, Icons.explore_rounded, 'Explore', selectedIndex),
                    _buildNavItem(2, Icons.apartment_rounded, 'Portal', selectedIndex),
                    _buildNavItem(3, Icons.favorite_rounded, 'Saved', selectedIndex),
                    _buildNavItem(4, Icons.person_rounded, 'Profile', selectedIndex),
                  ],
                ),
              ),
            ),
          ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final Uri url = Uri.parse('https://wa.me/919876543213');
            if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
              debugPrint('Could not launch WhatsApp');
            }
          },
          backgroundColor: const Color(0xFF25D366), // WhatsApp Color
          child: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.white, size: 32),
        ),
        );
      },
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, int activeIndex) {
    final bool isSelected = index == activeIndex;
    return GestureDetector(
      onTap: () => AppNavigation.goToTab(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF4F46E5).withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              color: isSelected ? const Color(0xFF4F46E5) : Colors.grey[400],
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFF4F46E5) : Colors.grey[400],
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Property> _filteredProperties = propertyCatalogNotifier.value.take(3).toList();
  bool _isSearching = false;

  // Filter state
  String? _selectedLocation;
  RangeValues _priceRange = const RangeValues(5000, 30000);
  String? _selectedRoomType; // 'AC' or 'Non AC'
  String? _selectedCategory;
  final List<String> _recentSearches = ['Bangalore', 'Girls PG', 'Luxury', 'Near Metro', 'Under ₹10k'];

  @override
  void initState() {
    super.initState();
    propertyCatalogNotifier.addListener(_onCatalogChanged);
  }

  void _onCatalogChanged() {
    if (mounted) _applyFilters();
  }

  @override
  void dispose() {
    propertyCatalogNotifier.removeListener(_onCatalogChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    setState(() {
      _isSearching = true; // Shows 'Search Results' header
      _filteredProperties = propertyCatalogNotifier.value.where((prop) {
        // 1. Search Query / Quick Filter Logic
        if (_searchController.text.isNotEmpty) {
          final query = _searchController.text.toLowerCase();
          
          // Check for Quick Filter Keywords
          if (query == 'under ₹10k') {
            if (prop.price >= 10000) return false;
          } else if (query == 'ac rooms') {
            if (!prop.tags.any((t) => t.toUpperCase() == 'AC')) return false;
          } else if (query == 'girls only') {
            if (!prop.category.toLowerCase().contains('women')) return false;
          } else if (query == 'near metro') {
            if (prop.distance > 1.0) return false; // Simulated metro proximity
          } else {
            // Normal Title Search
            if (!prop.title.toLowerCase().contains(query)) return false;
          }
        }

        // 2. Location Filter
        if (_selectedLocation != null) {
          if (!prop.location.toLowerCase().contains(_selectedLocation!.toLowerCase())) return false;
        }

        // 3. Price Filter
        if (prop.price < _priceRange.start || prop.price > _priceRange.end) return false;

        // 4. Room Type Filter (AC/Non AC)
        if (_selectedRoomType != null) {
          bool hasAC = prop.tags.any((tag) => tag.toUpperCase() == 'AC');
          if (_selectedRoomType == 'AC' && !hasAC) return false;
          if (_selectedRoomType == 'Non AC' && hasAC) return false;
        }

        // 5. Category Filter
        if (_selectedCategory != null) {
          String propCat = prop.category.toLowerCase();
          String selCat = _selectedCategory!.toLowerCase().replaceAll("'s hostel", "").replaceAll(" hostel", "").trim();
          if (!propCat.contains(selCat)) return false;
        }

        return true;
      }).toList();
    });
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              controller: scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Filters', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Location
                  const Text('Location', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedLocation,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    hint: const Text('Select Location'),
                    items: ['Bangalore', 'Chennai', 'Pune', 'Delhi', 'Mumbai', 'Hyderabad']
                        .map((loc) => DropdownMenuItem(value: loc, child: Text(loc)))
                        .toList(),
                    onChanged: (value) {
                      setModalState(() => _selectedLocation = value);
                    },
                  ),
                  const SizedBox(height: 24),

                  // Price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Price Range', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(
                        '₹${_priceRange.start.round()} - ₹${_priceRange.end.round()}',
                        style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  RangeSlider(
                    values: _priceRange,
                    min: 0,
                    max: 40000,
                    divisions: 40,
                    activeColor: const Color(0xFF4F46E5),
                    inactiveColor: const Color(0xFF4F46E5).withOpacity(0.1),
                    labels: RangeLabels('₹${_priceRange.start.round()}', '₹${_priceRange.end.round()}'),
                    onChanged: (values) {
                      setModalState(() => _priceRange = values);
                    },
                  ),
                  const SizedBox(height: 24),

                  // AC / Non AC
                  const Text('Room Type', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildFilterChip('AC', _selectedRoomType == 'AC', () {
                        setModalState(() => _selectedRoomType = (_selectedRoomType == 'AC' ? null : 'AC'));
                      }),
                      const SizedBox(width: 12),
                      _buildFilterChip('Non AC', _selectedRoomType == 'Non AC', () {
                        setModalState(() => _selectedRoomType = (_selectedRoomType == 'Non AC' ? null : 'Non AC'));
                      }),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Categories
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      title: const Text('Categories', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
                      tilePadding: EdgeInsets.zero,
                      children: [
                        _buildCategoryOption('Men\'s Hostel', setModalState),
                        _buildCategoryOption('Women\'s Hostel', setModalState),
                        _buildCategoryOption('Co-living', setModalState),
                        _buildCategoryOption('Student', setModalState),
                        _buildCategoryOption('Working', setModalState),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        _applyFilters();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Apply Filters', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onSelected) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: const Color(0xFF4F46E5).withOpacity(0.1),
      checkmarkColor: const Color(0xFF4F46E5),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF4F46E5) : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? const Color(0xFF4F46E5) : Colors.grey[300]!,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildCategoryOption(String title, StateSetter setModalState) {
    bool isSelected = _selectedCategory == title;
    return ListTile(
      title: Text(title, style: TextStyle(color: isSelected ? const Color(0xFF4F46E5) : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      onTap: () {
        setModalState(() => _selectedCategory = (isSelected ? null : title));
      },
      selected: isSelected,
      dense: true,
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: RefreshIndicator(
        onRefresh: () async {
          await _bootstrapCatalog();
          if (mounted) _applyFilters();
        },
        color: const Color(0xFF4F46E5),
        child: CustomScrollView(
          slivers: [
          SliverAppBar(
            expandedHeight: 310.0,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF4F46E5),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF4F46E5), Color(0xFF3730A3)],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: -50,
                      right: -50,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 50,
                      left: -30,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 64.0, left: 24.0, right: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      ValueListenableBuilder<String?>(
                        valueListenable: savedNameNotifier,
                        builder: (context, name, child) {
                          final hour = DateTime.now().hour;
                          String greeting = 'Good Morning';
                          if (hour >= 12 && hour < 17) greeting = 'Good Afternoon';
                          else if (hour >= 17 || hour < 5) greeting = 'Good Evening';
                          
                          return Text(
                            name != null ? '$greeting, $name' : 'Discover Your',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.2,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Perfect\nStay Hub',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 44,
                          fontWeight: FontWeight.bold,
                          height: 1.0,
                          letterSpacing: -1.5,
                        ),
                      ),
                      ValueListenableBuilder<PlatformStats?>(
                        valueListenable: platformStatsNotifier,
                        builder: (context, stats, _) {
                          if (stats == null) return const SizedBox(height: 16);
                          return Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 4),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildStatPill('${stats.tenants}+ Tenants'),
                                _buildStatPill('${stats.properties} Hostels'),
                                _buildStatPill('${stats.cities} Cities'),
                                _buildStatPill(stats.rating),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => _applyFilters(),
                          textAlignVertical: TextAlignVertical.center,
                          decoration: InputDecoration(
                            hintText: 'Search city, location or hostel...',
                            hintStyle: const TextStyle(color: Colors.grey, fontSize: 16),
                            prefixIcon: const Icon(Icons.search, color: Colors.grey),
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            border: InputBorder.none,
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_searchController.text.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
                                    onPressed: () {
                                      setState(() {
                                        _searchController.clear();
                                        _isSearching = false;
                                        _applyFilters();
                                      });
                                    },
                                  ),
                                GestureDetector(
                                  onTap: _showFilterSheet,
                                  child: Container(
                                    margin: const EdgeInsets.all(8),
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4F46E5).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.tune, color: Color(0xFF4F46E5), size: 20),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            title: const Text(
              'LIVORA',
              style: TextStyle(
                fontWeight: FontWeight.w900, 
                color: Colors.white,
                letterSpacing: 2.0,
                fontSize: 22,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                onPressed: () => _showNotificationsSheet(context),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: GestureDetector(
                  onTap: () => AppNavigation.goToTab(AppNavigation.tabProfile),
                child: ValueListenableBuilder<XFile?>(
                  valueListenable: profileImageNotifier,
                  builder: (context, imageFile, child) {
                    ImageProvider? imageProvider;
                    if (imageFile != null) {
                      if (kIsWeb) {
                        imageProvider = NetworkImage(imageFile.path);
                      } else {
                        imageProvider = FileImage(File(imageFile.path));
                      }
                    }
                    return CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: imageProvider,
                      child: imageProvider == null
                          ? const Icon(Icons.person, size: 16, color: Colors.grey)
                          : null,
                    );
                  },
                ),
                ),
              )
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Explore Categories', context),
                  const SizedBox(height: 16),
                  _buildCategoriesList(),
                  const SizedBox(height: 32),
                  if (!_isSearching) ...[
                    _buildSectionHeader('Trending Hostels', context),
                    const SizedBox(height: 16),
                    _buildTrendingList(context),
                    const SizedBox(height: 32),
                    _buildSectionHeader('Quick Filters', context),
                    const SizedBox(height: 16),
                    _buildQuickFiltersRow(),
                    const SizedBox(height: 32),
                    _buildSectionHeader('Recent Searches', context),
                    const SizedBox(height: 16),
                    _buildRecentSearches(),
                    const SizedBox(height: 32),
                    _buildSectionHeader('Verified Managers', context),
                    const SizedBox(height: 16),
                    _buildVerifiedManagers(),
                    const SizedBox(height: 32),
                    _buildReferAndEarnCard(),
                    const SizedBox(height: 32),
                    _buildQuickSOSBanner(),
                    const SizedBox(height: 32),
                  ],
                  _buildSectionHeader(_isSearching ? 'Search Results' : 'Featured Properties', context),
                  const SizedBox(height: 16),
                  _buildFeaturedProperties(context),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  Future<void> _showNotificationsSheet(BuildContext context) async {
    List<Map<String, dynamic>> notifications = [];
    if (AppServices.auth.isLoggedIn.value) {
      try {
        notifications = await AppServices.notifications.fetchAll();
      } on ApiException catch (e) {
        if (context.mounted) {
          scaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(content: Text(e.message), backgroundColor: Colors.red),
          );
        }
      }
    }
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24.0),
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Notifications',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              if (notifications.isEmpty)
                Column(
                  children: [
                    Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      AppServices.auth.isLoggedIn.value
                          ? "Don't have any notifications at this moment"
                          : 'Sign in to see your notifications',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                )
              else
                ...notifications.take(10).map((n) {
                  final title = n['title']?.toString() ?? n['message']?.toString() ?? 'Notification';
                  return ListTile(
                    leading: const Icon(Icons.notifications, color: Color(0xFF4F46E5)),
                    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(n['body']?.toString() ?? ''),
                  );
                }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildRecentSearches() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _recentSearches.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: ActionChip(
              label: Text(_recentSearches[index]),
              onPressed: () {
                _searchController.text = _recentSearches[index];
                _applyFilters();
              },
              backgroundColor: Colors.white,
              labelStyle: const TextStyle(fontSize: 12, color: Colors.black87),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey[200]!)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVerifiedManagers() {
    final managers = [
      {'name': 'Rahul Sharma', 'property': 'Elite Living', 'rating': '4.9'},
      {'name': 'Priya Singh', 'property': 'Comfort PG', 'rating': '4.8'},
      {'name': 'Amit Kumar', 'property': 'Modern Hostel', 'rating': '4.9'},
    ];
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: managers.length,
        itemBuilder: (context, index) {
          return Container(
            width: 200,
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF4F46E5).withOpacity(0.1),
                  child: Text(managers[index]['name']![0], style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(managers[index]['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(managers[index]['property']!, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    ],
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 14),
                    Text(managers[index]['rating']!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickFiltersRow() {
    final filters = [
      {'label': 'Under ₹10k', 'icon': Icons.savings_outlined},
      {'label': 'AC Rooms', 'icon': Icons.ac_unit},
      {'label': 'Near Metro', 'icon': Icons.directions_subway},
      {'label': 'Girls Only', 'icon': Icons.female},
    ];

    return SizedBox(
      height: 45,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(right: 12),
            child: ActionChip(
              avatar: Icon(filters[index]['icon'] as IconData, size: 16, color: const Color(0xFF4F46E5)),
              label: Text(filters[index]['label'] as String),
              onPressed: () {
                _searchController.text = filters[index]['label'] as String;
                _applyFilters();
              },
              backgroundColor: Colors.white,
              side: BorderSide(color: Colors.grey[200]!),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ExploreScreen()),
              );
            },
            child: const Text('See All', style: TextStyle(color: Color(0xFF4F46E5))),
          ),
        ],
      ),
    );
  }

  Widget _buildReferAndEarnCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF818CF8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Refer & Earn ₹500', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Invite your friends to Livora and get credits for your next rent.', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    scaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text('Referral link copied to clipboard!')));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF4F46E5),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Share Now', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const Icon(Icons.card_giftcard, size: 80, color: Colors.white24),
        ],
      ),
    );
  }

  Widget _buildQuickSOSBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red[100]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.sos, color: Colors.red, size: 32),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Safety & Support SOS', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                Text('Instant help for any emergency', style: TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!AppServices.auth.isLoggedIn.value) {
                AppNavigation.promptSignIn('Sign in to send an SOS alert');
                return;
              }
              try {
                await AppServices.tenantPortal.postSosAlert(
                  type: 'Emergency',
                  message: 'SOS triggered by tenant',
                  location: 'Hostel premises',
                );
                scaffoldMessengerKey.currentState?.showSnackBar(
                  const SnackBar(content: Text('SOS alert sent to management'), backgroundColor: Colors.red),
                );
              } on ApiException catch (e) {
                scaffoldMessengerKey.currentState?.showSnackBar(
                  SnackBar(content: Text(e.message), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesList() {
    final categories = [
      {'name': 'Men\'s Hostel', 'img': 'https://images.unsplash.com/photo-1590490360182-c33d57733427?q=80&w=200&h=200&auto=format&fit=crop'},
      {'name': 'Women\'s', 'img': 'https://images.unsplash.com/photo-1522771739844-6a9f6d5f14af?q=80&w=200&h=200&auto=format&fit=crop'},
      {'name': 'Co-living', 'img': 'https://images.unsplash.com/photo-1529156069898-49953e39b3ac?q=80&w=200&h=200&auto=format&fit=crop'},
      {'name': 'Student', 'img': 'https://images.unsplash.com/photo-1497633762265-9d179a990aa6?q=80&w=200&h=200&auto=format&fit=crop'},
      {'name': 'Working', 'img': 'https://images.unsplash.com/photo-1497366216548-37526070297c?q=80&w=200&h=200&auto=format&fit=crop'},
    ];

    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final categoryName = categories[index]['name'] as String;
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CategoryScreen(categoryName: categoryName),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              child: Column(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: Colors.grey[100]!, width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(35),
                        child: Image.network(
                          categories[index]['img'] as String,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: Colors.grey[100],
                              child: const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5)),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) => Icon(
                            index % 2 == 0 ? Icons.male : Icons.female,
                            color: const Color(0xFF4F46E5),
                            size: 30,
                          ),
                        ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    categories[index]['name'] as String,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeaturedProperties(BuildContext context) {
    if (_filteredProperties.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Text(
            'No properties found matching your search.',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredProperties.length,
      itemBuilder: (context, index) {
        final prop = _filteredProperties[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PropertyDetailsScreen(property: prop),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 24.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Hero(
                      tag: 'image_${prop.title}',
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16.0)),
                        child: PropertyImage(
                          imageUrl: prop.imageUrl,
                          height: 200,
                          width: double.infinity,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 16,
                      right: 16,
                      child: ValueListenableBuilder<Set<Property>>(
                        valueListenable: savedPropertiesNotifier,
                        builder: (context, savedProps, child) {
                          final isSaved = savedProps.contains(prop);
                          return GestureDetector(
                            onTap: () {
                              final newSet = Set<Property>.from(savedProps);
                              if (isSaved) {
                                newSet.remove(prop);
                              } else {
                                newSet.add(prop);
                                if (prop.id != null && AppServices.auth.isLoggedIn.value) {
                                  unawaited(AppServices.tenantPortal.addToWishlist(
                                    hostelId: prop.id!,
                                    hostelName: prop.title,
                                  ));
                                }
                              }
                              savedPropertiesNotifier.value = newSet;
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isSaved ? Icons.favorite : Icons.favorite_border,
                                color: isSaved ? Colors.red : Colors.grey,
                                size: 20,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Positioned(
                      top: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              prop.rating.toString(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    )
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              prop.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                          ),
                          Text(
                            '₹${prop.price}/mo',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, color: Colors.grey, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            prop.location,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: prop.tags.map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tag,
                              style: const TextStyle(
                                color: Color(0xFF4F46E5),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrendingList(BuildContext context) {
    final trending = propertyCatalogNotifier.value.where((p) => p.rating >= 4.7).take(4).toList();
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: trending.length,
        itemBuilder: (context, index) {
          final prop = trending[index];
          return GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PropertyDetailsScreen(property: prop))),
            child: Container(
              width: 280,
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PropertyImage(imageUrl: prop.imageUrl, fit: BoxFit.cover),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.4), blurRadius: 8)],
                                ),
                                child: const Text('TRENDING', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.star, color: Colors.amber, size: 14),
                              const SizedBox(width: 4),
                              Text(prop.rating.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            prop.title,
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(prop.location, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  late List<Property> _filteredProperties;
  final TextEditingController _searchController = TextEditingController();

  // Filter state variables
  String _selectedLocation = 'Bangalore';
  double _currentPrice = 15000.0;
  String _selectedType = 'AC';
  String _sortBy = 'Price: Low to High';
  bool _isMapView = false;

  @override
  void initState() {
    super.initState();
    _filteredProperties = List<Property>.from(propertyCatalogNotifier.value);
    propertyCatalogNotifier.addListener(_onCatalogChanged);
  }

  void _onCatalogChanged() {
    if (mounted) _applyFilters();
  }

  @override
  void dispose() {
    propertyCatalogNotifier.removeListener(_onCatalogChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    setState(() {
      String query = _searchController.text.toLowerCase();
      _filteredProperties = propertyCatalogNotifier.value.where((property) {
        bool matchesSearch = property.title.toLowerCase().contains(query);
        bool matchesLocation = property.location.contains(_selectedLocation);
        bool matchesPrice = property.price <= _currentPrice;
        bool matchesType = true;
        if (_selectedType == 'AC') {
          matchesType = property.tags.contains('AC');
        } else if (_selectedType == 'Non-AC') {
          matchesType = !property.tags.contains('AC');
        }
        return matchesSearch && matchesLocation && matchesPrice && matchesType;
      }).toList();

      // Sort results
      if (_sortBy == 'Price: Low to High') {
        _filteredProperties.sort((a, b) => a.price.compareTo(b.price));
      } else if (_sortBy == 'Price: High to Low') {
        _filteredProperties.sort((a, b) => b.price.compareTo(a.price));
      } else if (_sortBy == 'Top Rated') {
        _filteredProperties.sort((a, b) => b.rating.compareTo(a.rating));
      }
    });
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Filters', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            _selectedLocation = 'Bangalore';
                            _currentPrice = 15000;
                            _selectedType = 'AC';
                          });
                        }, 
                        child: const Text('Clear All', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600))
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('Location', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF374151))),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['Bangalore', 'Hyderabad', 'Mumbai', 'Delhi', 'Pune'].map((loc) {
                      final isSelected = _selectedLocation == loc;
                      return ChoiceChip(
                        label: Text(loc),
                        selected: isSelected,
                        onSelected: (bool selected) {
                          setModalState(() {
                            _selectedLocation = loc;
                          });
                        },
                        selectedColor: const Color(0xFF4F46E5).withOpacity(0.1),
                        labelStyle: TextStyle(
                          color: isSelected ? const Color(0xFF4F46E5) : Colors.grey[700],
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  const Text('Price Range', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF374151))),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('₹5,000', style: TextStyle(color: Colors.grey[600])),
                      Text('₹${_currentPrice.round()}', style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                    value: _currentPrice,
                    min: 5000,
                    max: 30000,
                    divisions: 25,
                    label: '₹${_currentPrice.round()}',
                    activeColor: const Color(0xFF4F46E5),
                    inactiveColor: const Color(0xFF4F46E5).withOpacity(0.1),
                    onChanged: (value) {
                      setModalState(() {
                        _currentPrice = value;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text('Accommodation Type', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF374151))),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilterChip(
                        label: const Text('AC'),
                        selected: _selectedType == 'AC',
                        onSelected: (bool selected) {
                          if (selected) {
                            setModalState(() {
                              _selectedType = 'AC';
                            });
                          }
                        },
                        selectedColor: const Color(0xFF4F46E5).withOpacity(0.1),
                        checkmarkColor: const Color(0xFF4F46E5),
                        labelStyle: TextStyle(color: _selectedType == 'AC' ? const Color(0xFF4F46E5) : Colors.grey[700]),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Non-AC'),
                        selected: _selectedType == 'Non-AC',
                        onSelected: (bool selected) {
                          if (selected) {
                            setModalState(() {
                              _selectedType = 'Non-AC';
                            });
                          }
                        },
                        selectedColor: const Color(0xFF4F46E5).withOpacity(0.1),
                        checkmarkColor: const Color(0xFF4F46E5),
                        labelStyle: TextStyle(color: _selectedType == 'Non-AC' ? const Color(0xFF4F46E5) : Colors.grey[700]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        _applyFilters();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Apply Filters', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore Properties'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              AppNavigation.goToHome();
            }
          },
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isMapView ? Icons.list_rounded : Icons.map_outlined, color: const Color(0xFF4F46E5)),
            onPressed: () => setState(() => _isMapView = !_isMapView),
          ),
        ],
      ),
      body: _isMapView ? _buildMapView() : Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => _applyFilters(),
                    decoration: InputDecoration(
                      hintText: 'Search city, location or hostel...',
                      hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF4F46E5), size: 20),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _showFilterOptions,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFF4F46E5).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.tune, color: Color(0xFF4F46E5), size: 20),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_filteredProperties.length} Properties found', style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
                GestureDetector(
                  onTap: _showSortOptions,
                  child: Row(
                    children: [
                      const Text('Sort by', style: TextStyle(color: Color(0xFF4F46E5), fontSize: 12, fontWeight: FontWeight.bold)),
                      const Icon(Icons.keyboard_arrow_down, color: Color(0xFF4F46E5), size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _filteredProperties.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        const Text(
                          'No properties found',
                          style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: _filteredProperties.length,
                    itemBuilder: (context, index) {
                      final prop = _filteredProperties[index];
                      final occupancy = 60 + (index % 4) * 10; // demo indicator
                      final tags = prop.tags.take(3).toList();
                      final extraCount = prop.tags.length - tags.length;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: PropertyImage(
                                      imageUrl: prop.imageUrl,
                                      width: 92,
                                      height: 92,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                prop.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w900,
                                                  color: Color(0xFF111827),
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFFF7ED),
                                                borderRadius: BorderRadius.circular(16),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.star, size: 16, color: Colors.orange),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    prop.rating.toString(),
                                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Icon(Icons.location_on_outlined, color: Colors.grey, size: 18),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                prop.location,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'STARTS FROM',
                                                    style: TextStyle(
                                                      color: Colors.grey[500],
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w700,
                                                      letterSpacing: 0.8,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    '₹${prop.price}',
                                                    style: const TextStyle(
                                                      fontSize: 20,
                                                      fontWeight: FontWeight.w900,
                                                      color: Colors.green,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Icon(Icons.access_time, size: 16, color: Colors.grey[500]),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        'OCCUPANCY',
                                                        style: TextStyle(
                                                          color: Colors.grey[500],
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w700,
                                                          letterSpacing: 0.8,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    '$occupancy%',
                                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            ValueListenableBuilder<Set<Property>>(
                                              valueListenable: savedPropertiesNotifier,
                                              builder: (context, savedProps, child) {
                                                final isSaved = savedProps.contains(prop);
                                                return IconButton(
                                                  onPressed: () {
                                                    final newSet = Set<Property>.from(savedProps);
                                                    if (isSaved) {
                                                      newSet.remove(prop);
                                                    } else {
                                                      newSet.add(prop);
                                                      if (prop.id != null && AppServices.auth.isLoggedIn.value) {
                                                        unawaited(
                                                          AppServices.tenantPortal.addToWishlist(
                                                            hostelId: prop.id!,
                                                            hostelName: prop.title,
                                                          ),
                                                        );
                                                      }
                                                    }
                                                    savedPropertiesNotifier.value = newSet;
                                                  },
                                                  icon: Icon(
                                                    isSaved ? Icons.favorite : Icons.favorite_border,
                                                    color: isSaved ? Colors.red : Colors.grey,
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  ...tags.map((t) => _ExploreTagChip(text: t)),
                                  if (extraCount > 0) _ExploreTagChip(text: '+$extraCount More', isMore: true),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => PropertyDetailsScreen(
                                              property: prop,
                                              fullDetailsMode: true,
                                            ),
                                          ),
                                        );
                                      },
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        side: BorderSide(color: Colors.grey[300]!),
                                      ),
                                      child: const Text(
                                        'View Details',
                                        style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => PropertyDetailsScreen(
                                              property: prop,
                                              openBookingOnStart: true,
                                            ),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF4F46E5),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        elevation: 0,
                                      ),
                                      child: const Text(
                                        'Book Now',
                                        style: TextStyle(fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                  ),
                                ],
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

  Widget _buildMapView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: const Color(0xFF4F46E5).withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.map_rounded, size: 100, color: Color(0xFF4F46E5)),
          ),
          const SizedBox(height: 24),
          const Text('Interactive Map View', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text('Finding your perfect home is easier on the map. Zoom in to explore properties in your favorite area.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => setState(() => _isMapView = false),
            icon: const Icon(Icons.list_rounded),
            label: const Text('Back to List View'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sort Properties', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildSortOption('Price: Low to High', Icons.trending_up),
            _buildSortOption('Price: High to Low', Icons.trending_down),
            _buildSortOption('Top Rated', Icons.star_outline),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(String option, IconData icon) {
    bool isSelected = _sortBy == option;
    return ListTile(
      leading: Icon(icon, color: isSelected ? const Color(0xFF4F46E5) : Colors.grey),
      title: Text(option, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? const Color(0xFF4F46E5) : Colors.black87)),
      trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFF4F46E5)) : null,
      onTap: () {
        setState(() {
          _sortBy = option;
          _applyFilters();
        });
        Navigator.pop(context);
      },
    );
  }
}


class PropertyDetailsScreen extends StatefulWidget {
  final Property property;
  final bool openBookingOnStart;
  final bool fullDetailsMode;

  const PropertyDetailsScreen({
    super.key,
    required this.property,
    this.openBookingOnStart = false,
    this.fullDetailsMode = false,
  });

  @override
  State<PropertyDetailsScreen> createState() => _PropertyDetailsScreenState();
}

class _PropertyDetailsScreenState extends State<PropertyDetailsScreen> {
  late Future<Map<String, dynamic>?> _detailsFuture;

  @override
  void initState() {
    super.initState();
    final id = widget.property.id;
    _detailsFuture = (id != null && id.isNotEmpty)
        ? AppServices.buildings.fetchPublicBuildingDetails(id)
        : Future.value(null);
    if (widget.openBookingOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showBookingDialog();
      });
    }
  }

  Widget _buildInlineHostelDetails() {
    if (!widget.fullDetailsMode) return const SizedBox.shrink();

    return FutureBuilder<Map<String, dynamic>?>(
      future: _detailsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingStateView(message: 'Loading property details…');
        }
        if (snapshot.hasError) {
          return ErrorStateView(
            message: 'Could not load property details. Please try again.',
            onRetry: () {
              setState(() {
                _detailsFuture = AppServices.buildings.fetchPublicBuildingDetails(
                  widget.property.id!,
                );
              });
            },
          );
        }
        if (!snapshot.hasData) {
          return const ErrorStateView(
            message: 'Property details are not available.',
          );
        }
        return HostelFullDetailsView(
          data: snapshot.data!,
          fallbackAmenities: widget.property.tags,
        );
      },
    );
  }

  void _showBookingDialog() {
    final TextEditingController nameController = TextEditingController(text: savedNameNotifier.value);
    final TextEditingController emailController = TextEditingController(text: savedEmailNotifier.value);
    final TextEditingController phoneController = TextEditingController(text: savedPhoneNotifier.value);
    String selectedRoomType = 'Double Sharing';
    int stayDuration = 6;
    DateTime checkInDate = DateTime.now().add(const Duration(days: 7));
    String selectedPaymentMethod = 'UPI (Google Pay/PhonePe)';
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          maxChildSize: 0.95,
          minChildSize: 0.6,
          expand: false,
          builder: (context, scrollController) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Booking Details', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(widget.property.title, style: TextStyle(color: const Color(0xFF4F46E5), fontSize: 16, fontWeight: FontWeight.w600)),
                  const Divider(height: 32),
                  
                  // Summary Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF3730A3)]),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Column(
                      children: [
                        _buildSummaryRow('Monthly Rent', '₹${widget.property.price}', Colors.white70),
                        const SizedBox(height: 8),
                        _buildSummaryRow('Duration', '$stayDuration Months', Colors.white70),
                        const Divider(color: Colors.white24, height: 24),
                        _buildSummaryRow('Total Amount', '₹${widget.property.price * stayDuration}', Colors.white, isTotal: true),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  const _SectionTitle(title: 'Personal Information', icon: Icons.person_outline),
                  const SizedBox(height: 16),
                  _buildTextField('Full Name', nameController, Icons.person_outline),
                  const SizedBox(height: 12),
                  _buildTextField('Email Address', emailController, Icons.email_outlined),
                  const SizedBox(height: 12),
                  _buildTextField('Phone Number', phoneController, Icons.phone_android_outlined),
                  
                  const SizedBox(height: 32),
                  const _SectionTitle(title: 'Stay Preferences', icon: Icons.meeting_room_outlined),
                  const SizedBox(height: 16),
                  const Text('Room Type', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    children: ['Single', 'Double Sharing', '3-Sharing'].map((type) {
                      final isSelected = selectedRoomType == type;
                      return ChoiceChip(
                        label: Text(type),
                        selected: isSelected,
                        onSelected: (val) => setModalState(() => selectedRoomType = type),
                        selectedColor: const Color(0xFF4F46E5).withOpacity(0.1),
                        labelStyle: TextStyle(color: isSelected ? const Color(0xFF4F46E5) : Colors.grey[700], fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                        side: BorderSide(color: isSelected ? const Color(0xFF4F46E5) : Colors.grey[300]!),
                      );
                    }).toList(),
                  ),
                  
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Duration of Stay', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                      Text('$stayDuration Months', style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                    value: stayDuration.toDouble(),
                    min: 1,
                    max: 24,
                    divisions: 23,
                    activeColor: const Color(0xFF4F46E5),
                    onChanged: (val) => setModalState(() => stayDuration = val.round()),
                  ),
                  
                  const SizedBox(height: 16),
                  const Text('Move-in Date', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: checkInDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 90)),
                      );
                      if (date != null) setModalState(() => checkInDate = date);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month, size: 20, color: Color(0xFF4F46E5)),
                          const SizedBox(width: 12),
                          Text('${checkInDate.day} ${_getMonthName(checkInDate.month)} ${checkInDate.year}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  const _SectionTitle(title: 'Payment Method', icon: Icons.payment_outlined),
                  const SizedBox(height: 16),
                  _buildPaymentOption('UPI (Google Pay/PhonePe)', Icons.account_balance_wallet_outlined, selectedPaymentMethod, (val) => setModalState(() => selectedPaymentMethod = val!)),
                  _buildPaymentOption('Credit/Debit Card', Icons.credit_card_outlined, selectedPaymentMethod, (val) => setModalState(() => selectedPaymentMethod = val!)),
                  _buildPaymentOption('Net Banking', Icons.account_balance_outlined, selectedPaymentMethod, (val) => setModalState(() => selectedPaymentMethod = val!)),
                  
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                        final buildingId = widget.property.id;
                        if (!AppServices.auth.isLoggedIn.value) {
                          Navigator.pop(context);
                          AppNavigation.promptSignIn('Sign in to complete your booking');
                          return;
                        }
                        if (buildingId == null) {
                          Navigator.pop(context);
                          scaffoldMessengerKey.currentState?.showSnackBar(
                            const SnackBar(
                              content: Text('This property cannot be booked online yet'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }
                        if (nameController.text.trim().isEmpty ||
                            emailController.text.trim().isEmpty ||
                            phoneController.text.trim().isEmpty) {
                          scaffoldMessengerKey.currentState?.showSnackBar(
                            const SnackBar(content: Text('Please fill all personal details')),
                          );
                          return;
                        }
                        setModalState(() => isSubmitting = true);
                        try {
                          final moveIn = checkInDate;
                          final moveInStr =
                              '${moveIn.year}-${moveIn.month.toString().padLeft(2, '0')}-${moveIn.day.toString().padLeft(2, '0')}';
                          final total = widget.property.price * stayDuration;
                          final sharingType =
                              BedsService.sharingTypeFromRoomLabel(selectedRoomType);
                          final bed = await AppServices.beds.findAvailableBed(
                            buildingId: buildingId,
                            sharingType: sharingType,
                          );
                          if (bed == null) {
                            throw ApiException(
                              'No ${sharingType.toLowerCase()} beds available for this property. Try another room type.',
                            );
                          }
                          await AppServices.bookings.createBooking(
                            buildingId: buildingId,
                            bedId: bed.bedId,
                            category: selectedRoomType.contains('Single') ? 'Premium' : 'Standard',
                            moveInDate: moveInStr,
                            totalAmount: total,
                            securityDeposit: widget.property.price,
                            onboardingFee: 999,
                            method: selectedPaymentMethod.contains('UPI') ? 'UPI' : 'Bank Transfer',
                            guestName: nameController.text.trim(),
                            email: emailController.text.trim(),
                            phone: phoneController.text.trim(),
                            sharingType: bed.sharingType,
                            bedNumber: bed.bedNumber,
                          );
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          _showSuccessDialog();
                          AppNavigation.goToHome();
                        } on ApiException catch (e) {
                          setModalState(() => isSubmitting = false);
                          scaffoldMessengerKey.currentState?.showSnackBar(
                            SnackBar(content: Text(e.message), backgroundColor: Colors.red),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                        shadowColor: const Color(0xFF4F46E5).withOpacity(0.5),
                        disabledBackgroundColor: const Color(0xFF4F46E5).withOpacity(0.6),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Pay & Confirm Booking', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color color, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: color, fontSize: isTotal ? 18 : 14)),
        Text(value, style: TextStyle(color: color, fontSize: isTotal ? 22 : 16, fontWeight: isTotal ? FontWeight.bold : FontWeight.w600)),
      ],
    );
  }

  Widget _buildPaymentOption(String title, IconData icon, String selected, ValueChanged<String?> onChanged) {
    bool isSelected = selected == title;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF4F46E5).withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isSelected ? const Color(0xFF4F46E5) : Colors.grey[200]!, width: 1.5),
      ),
      child: RadioListTile<String>(
        value: title,
        groupValue: selected,
        onChanged: onChanged,
        activeColor: const Color(0xFF4F46E5),
        title: Text(title, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? const Color(0xFF4F46E5) : Colors.black87)),
        secondary: Icon(icon, color: isSelected ? const Color(0xFF4F46E5) : Colors.grey),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const Icon(Icons.check_circle, color: Colors.green, size: 80),
            const SizedBox(height: 24),
            const Text('Booking Successful!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
              'Your request for ${widget.property.title} has been sent. The manager will contact you shortly.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Great!', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF4F46E5)),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final property = widget.property;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'image_${property.title}',
                child: PropertyImage(
                  imageUrl: property.imageUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          property.title,
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 20),
                                const SizedBox(width: 4),
                                Text(
                                  property.rating.toString(),
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          ValueListenableBuilder<Set<Property>>(
                            valueListenable: savedPropertiesNotifier,
                            builder: (context, savedProps, child) {
                              final isSaved = savedProps.contains(property);
                              return GestureDetector(
                                onTap: () {
                                  final newSet = Set<Property>.from(savedProps);
                                  if (isSaved) {
                                    newSet.remove(property);
                                  } else {
                                    newSet.add(property);
                                  }
                                  savedPropertiesNotifier.value = newSet;
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isSaved ? Colors.red.withOpacity(0.1) : Colors.grey[100],
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isSaved ? Icons.favorite : Icons.favorite_border,
                                    color: isSaved ? Colors.red : Colors.grey,
                                    size: 24,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.grey, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        property.location,
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (!widget.fullDetailsMode) _buildVirtualTourButton(context),
                  if (!widget.fullDetailsMode) const SizedBox(height: 32),
                  if (widget.fullDetailsMode) const SizedBox(height: 8),
                  _buildInlineHostelDetails(),
                  if (!widget.fullDetailsMode) ...[
                  const SizedBox(height: 32),

                  const Text('Rent & Inclusion', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildRentBreakdownCard(),
                  const SizedBox(height: 32),
                  const Text('Amenities & Services', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildAmenityGrid(property.tags),
                  const SizedBox(height: 32),

                  const Text('Property Performance', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildPerformanceScorecard(),
                  const SizedBox(height: 32),
                  const SizedBox(height: 24),
                  const Text('Food & Dining', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.orange.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.restaurant, color: Colors.orange),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            property.foodDetails,
                            style: const TextStyle(fontSize: 16, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('House Rules & Requirements', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _RequirementRow(icon: Icons.assignment_ind, text: 'Valid Government ID (Aadhar/PAN)'),
                        _RequirementRow(icon: Icons.smoke_free, text: 'No smoking or alcohol allowed'),
                        _RequirementRow(icon: Icons.people_outline, text: 'Visitors allowed 10 AM - 8 PM'),
                        _RequirementRow(icon: Icons.notifications_paused, text: 'Quiet hours after 10 PM'),
                        _RequirementRow(icon: Icons.security, text: 'Gate closing time: 11 PM'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text('Safety & Support', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.shield_outlined, color: Colors.red),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Your safety is our priority. Access emergency support or report issues anytime.',
                                style: TextStyle(fontSize: 14, color: Colors.black87),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                                builder: (context) => Container(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.emergency, color: Colors.red, size: 48),
                                      const SizedBox(height: 16),
                                      const Text('Emergency Support', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      const Text('Who would you like to contact?', textAlign: TextAlign.center),
                                      const SizedBox(height: 24),
                                      ListTile(
                                        leading: const Icon(Icons.phone, color: Colors.blue),
                                        title: const Text('Contact Hostel Warden'),
                                        onTap: () => Navigator.pop(context),
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.local_police, color: Colors.indigo),
                                        title: const Text('Contact Local Police'),
                                        onTap: () => Navigator.pop(context),
                                      ),
                                      ValueListenableBuilder<String?>(
                                        valueListenable: savedEmergencyPhoneNotifier,
                                        builder: (context, phone, child) {
                                          if (phone == null || phone.isEmpty) return const SizedBox.shrink();
                                          return ListTile(
                                            leading: const Icon(Icons.favorite, color: Colors.red),
                                            title: Text('Call Emergency Contact ($phone)'),
                                            onTap: () => Navigator.pop(context),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.sos, color: Colors.white),
                            label: const Text('Emergency Help Center', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Reviews', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      TextButton(onPressed: () {}, child: const Text('See All')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (property.reviews.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text('No reviews yet.', style: TextStyle(color: Colors.grey)),
                    )
                  else
                    ...property.reviews.map((review) => _buildReviewCard(review)).toList(),
                  const SizedBox(height: 120), // Bottom padding for content
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          scaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text('Connecting to Hostel Manager...')));
        },
        backgroundColor: const Color(0xFF4F46E5),
        child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
      ),
      bottomNavigationBar: _buildBottomBookingBar(context, property),
    );
  }

  Widget _buildVirtualTourButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _showVirtualTourOverlay(context),
      child: Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          image: DecorationImage(
            image: AssetImage(widget.property.imageUrl),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken),
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.threed_rotation, color: Colors.white, size: 48),
            SizedBox(height: 8),
            Text('360° VIRTUAL TOUR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2)),
          ],
        ),
      ),
    );
  }

  void _showVirtualTourOverlay(BuildContext context) {
    final TransformationController transformationController = TransformationController();
    bool isAutoRotating = false;
    Timer? rotationTimer;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Tour',
      pageBuilder: (context, anim1, anim2) => StatefulBuilder(
        builder: (context, setTourState) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
            title: const Text('360° Virtual Tour', style: TextStyle(fontWeight: FontWeight.bold)),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                rotationTimer?.cancel();
                Navigator.pop(context);
              },
            ),
          ),
          body: Stack(
            children: [
              InteractiveViewer(
                transformationController: transformationController,
                minScale: 0.5,
                maxScale: 4.0,
                boundaryMargin: const EdgeInsets.all(1000),
                child: Stack(
                  children: [
                    Image.network(
                      'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?q=80&w=2500&auto=format&fit=crop',
                      fit: BoxFit.none,
                      width: 2500,
                      height: 1500,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)));
                      },
                    ),
                    Positioned(top: 600, left: 800, child: _buildHotspotIcon('Living Space', Icons.chair_rounded, () {})),
                    Positioned(top: 500, left: 1600, child: _buildHotspotIcon('Dining Hub', Icons.restaurant_rounded, () {})),
                  ],
                ),
              ),
              
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    if (isAutoRotating)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: Colors.red.withOpacity(0.8), borderRadius: BorderRadius.circular(20)),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.videocam, color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text('AUTO-TOUR ACTIVE', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildTourControl(Icons.add, 'Zoom In', () {
                          setTourState(() {
                            transformationController.value = Matrix4.identity()..scale(2.0);
                          });
                        }),
                        const SizedBox(width: 16),
                        _buildTourControl(Icons.remove, 'Zoom Out', () {
                          setTourState(() {
                            transformationController.value = Matrix4.identity();
                          });
                        }),
                        const SizedBox(width: 16),
                        _buildTourControl(
                          isAutoRotating ? Icons.videocam_off_outlined : Icons.videocam_outlined, 
                          isAutoRotating ? 'Stop Tour' : 'Auto Tour', 
                          () {
                            setTourState(() {
                              isAutoRotating = !isAutoRotating;
                              if (isAutoRotating) {
                                rotationTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
                                  final Matrix4 currentMatrix = transformationController.value;
                                  final double currentTranslationX = currentMatrix.getTranslation().x;
                                  // Slowly pan horizontally
                                  transformationController.value = Matrix4.copy(currentMatrix)
                                    ..translate(-2.0, 0, 0);
                                  
                                  // Reset if panned too far (simple wrap-around simulation)
                                  if (currentTranslationX < -1500) {
                                    transformationController.value = Matrix4.identity();
                                  }
                                });
                              } else {
                                rotationTimer?.cancel();
                              }
                            });
                          }
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTourControl(IconData icon, String tooltip, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Tooltip(
          message: tooltip,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }


  Widget _buildHotspotIcon(String label, IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 15, spreadRadius: 2)],
                border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRentBreakdownCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          _buildBreakdownRow('Monthly Rent', '₹${widget.property.price}', isBold: true),
          const Divider(height: 24),
          _buildBreakdownRow('Electricity', 'Included'),
          _buildBreakdownRow('High-speed WiFi', 'Included'),
          _buildBreakdownRow('Water & Maintenance', 'Included'),
          _buildBreakdownRow('Daily Cleaning', 'Included'),
          const Divider(height: 24),
          _buildBreakdownRow('Security Deposit', '₹${widget.property.price}', color: const Color(0xFF4F46E5)),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.w500, fontSize: 14, color: color ?? Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildBottomBookingBar(BuildContext context, Property property) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Starting from', style: TextStyle(color: Colors.grey, fontSize: 12)),
                Text('₹${property.price}/mo', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _showBookingDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              shadowColor: const Color(0xFF4F46E5).withOpacity(0.5),
            ),
            child: const Text('Book Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }


  Widget _buildReviewCard(Review review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(review.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(review.date, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (index) {
              return Icon(
                index < review.rating.floor() ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 16,
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(review.comment, style: TextStyle(color: Colors.grey[800], height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildAmenityGrid(List<String> amenities) {
    return Wrap(
      spacing: 12, // Consistent horizontal spacing
      runSpacing: 16, // Consistent vertical spacing
      alignment: WrapAlignment.center,
      children: amenities.map((amenity) {
        final iconData = _getAmenityIcon(amenity);
        return SizedBox(
          width: 65, // Fixed width for each item to ensure equal visual spacing
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(iconData, color: const Color(0xFF4F46E5), size: 22),
              ),
              const SizedBox(height: 6),
              Text(
                amenity,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.black87),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  IconData _getAmenityIcon(String amenity) {
    final a = amenity.toLowerCase();
    if (a.contains('wifi')) return Icons.wifi;
    if (a.contains('ac')) return Icons.ac_unit;
    if (a.contains('gym')) return Icons.fitness_center;
    if (a.contains('parking')) return Icons.local_parking;
    if (a.contains('laundry') || a.contains('washing')) return Icons.local_laundry_service;
    if (a.contains('security') || a.contains('cctv')) return Icons.security;
    if (a.contains('housekeeping') || a.contains('cleaning')) return Icons.cleaning_services;
    if (a.contains('backup')) return Icons.power;
    if (a.contains('elevator')) return Icons.elevator;
    if (a.contains('food') || a.contains('mess')) return Icons.restaurant;
    if (a.contains('study')) return Icons.menu_book;
    if (a.contains('water')) return Icons.water_drop;
    return Icons.star_border;
  }

  Widget _buildPerformanceScorecard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          _buildScoreRow('Cleanliness', 0.95),
          const SizedBox(height: 16),
          _buildScoreRow('Safety & Security', 0.98),
          const SizedBox(height: 16),
          _buildScoreRow('Connectivity', 0.90),
          const SizedBox(height: 16),
          _buildScoreRow('Value for Money', 0.88),
        ],
      ),
    );
  }

  Widget _buildScoreRow(String label, double score) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            Text('${(score * 100).toInt()}%', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: score,
            backgroundColor: Colors.grey[100],
            color: const Color(0xFF4F46E5),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

class _RequirementRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _RequirementRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.blue[700]),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: Colors.black87))),
        ],
      ),
    );
  }
}

class _ExploreTagChip extends StatelessWidget {
  final String text;
  final bool isMore;

  const _ExploreTagChip({required this.text, this.isMore = false});

  @override
  Widget build(BuildContext context) {
    final bg = isMore ? const Color(0xFFE9F7EF) : const Color(0xFFF3F4F6);
    final fg = isMore ? Colors.green[700] : const Color(0xFF374151);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF4F46E5), size: 22),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
      ],
    );
  }
}

class ResidentPortalScreen extends StatelessWidget {
  const ResidentPortalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Resident Portal', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_outlined)),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Welcome Card
            _buildWelcomeCard(),
            const SizedBox(height: 32),
            
            // Quick Actions
            const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildActionItem(context, Icons.exit_to_app, 'Outpass', Colors.orange, () => _showOutpassSheet(context)),
                _buildActionItem(context, Icons.report_problem_outlined, 'Complaint', Colors.red, () => _showComplaintSheet(context)),
                _buildActionItem(context, Icons.payments_outlined, 'Rent', Colors.green, () => _showRentSheet(context)),
                _buildActionItem(context, Icons.restaurant_menu, 'Mess', Colors.blue, () => _showMessSheet(context)),
              ],
            ),
            const SizedBox(height: 24),
            _buildDigitalIDCard(context),
            const SizedBox(height: 32),

            // Active Pass Card
            const Text('Your Active Pass', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildActivePassCard(),
            const SizedBox(height: 32),

            // Notice Board
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Notice Board', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton(onPressed: () {}, child: const Text('See All')),
              ],
            ),
            const SizedBox(height: 8),
            _buildNoticeList(),
            const SizedBox(height: 32),

            // Complaint Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Complaint Tracker', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton(onPressed: () => _showMaintenanceHistory(context), child: const Text('History')),
              ],
            ),
            const SizedBox(height: 16),
            _buildComplaintTracker(),
            const SizedBox(height: 32),

            // Mess Menu Preview
            const Text('Mess Menu Today', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildMessMenuPreview(context),
            const SizedBox(height: 32),

            // Help & Support
            const Text('Help & Support', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildHelpSupportSection(context),
            const SizedBox(height: 100), // Bottom padding
          ],
        ),
      ),
    );
  }

  Widget _buildMessMenuPreview(BuildContext context) {
    return GestureDetector(
      onTap: () => _showMessSheet(context),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.orange.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            const Icon(Icons.restaurant, color: Colors.orange),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Lunch: Veg Biryani & Raita', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text('Served till 02:30 PM', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpSupportSection(BuildContext context) {
    return Column(
      children: [
        _buildSupportItem(Icons.help_outline, 'Frequently Asked Questions', () {}),
        const SizedBox(height: 12),
        _buildSupportItem(Icons.chat_bubble_outline, 'Chat with Support', () {}),
        const SizedBox(height: 12),
        _buildSupportItem(Icons.phone_outlined, 'Contact Manager', () {}),
      ],
    );
  }

  Widget _buildSupportItem(IconData icon, String title, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[100]!)),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF4F46E5), size: 20),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
        onTap: onTap,
        dense: true,
      ),
    );
  }

  void _showMaintenanceHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            const Text('Maintenance History', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                children: [
                  _buildHistoryItem('Fan Repair', 'Resolved', '12 Apr 2026', Icons.check_circle, Colors.green),
                  _buildHistoryItem('Door Lock Change', 'Resolved', '05 Mar 2026', Icons.check_circle, Colors.green),
                  _buildHistoryItem('WiFi Connectivity', 'Resolved', '18 Feb 2026', Icons.check_circle, Colors.green),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(String title, String status, String date, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Status: $status • $date', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return ValueListenableBuilder<String?>(
      valueListenable: savedNameNotifier,
      builder: (context, name, child) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF3730A3)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white24,
                child: Icon(Icons.person, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name ?? 'Resident',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Room 304 • Elite Men\'s PG',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDigitalIDCard(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDigitalID(context),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF4F46E5).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.badge_outlined, color: Color(0xFF4F46E5)),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Digital Resident ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('Tap to view your verifiable ID', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showDigitalID(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Color(0xFF4F46E5),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            const Text('LIVORA RESIDENT ID', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const Spacer(),
            Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircleAvatar(radius: 50, backgroundColor: Color(0xFF4F46E5), child: Icon(Icons.person, size: 50, color: Colors.white)),
                  const SizedBox(height: 24),
                  ValueListenableBuilder<String?>(
                    valueListenable: savedNameNotifier,
                    builder: (context, name, child) => Text(name ?? 'Resident', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
                  const Text('Elite Men\'s PG • Room 304', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 32),
                  const Icon(Icons.qr_code_2, size: 150),
                  const SizedBox(height: 32),
                  const Text('VERIFIED RESIDENT', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Text('Valid till May 2026', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white70),
                label: const Text('Close ID', style: TextStyle(color: Colors.white70)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildActivePassCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.qr_code_2, size: 40, color: Colors.black87),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Weekend Outpass', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('Valid till: 12 May, 2026', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(20)),
            child: Text('APPROVED', style: TextStyle(color: Colors.green[700], fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeList() {
    final notices = [
      {'title': 'Mess Timing Update', 'desc': 'Breakfast will be served from 7:30 AM tomorrow.', 'date': 'Today'},
      {'title': 'Maintenance Notice', 'desc': 'Water tank cleaning scheduled for Sunday.', 'date': 'Yesterday'},
    ];
    return Column(
      children: notices.map((n) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[100]!),
        ),
        child: Row(
          children: [
            const Icon(Icons.campaign, color: Color(0xFF4F46E5), size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n['title']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(n['desc']!, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            Text(n['date']!, style: const TextStyle(color: Colors.grey, fontSize: 10)),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildComplaintTracker() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          _buildComplaintItem('WiFi Signal Issue', 'Pending', Colors.orange),
          const Divider(height: 24),
          _buildComplaintItem('Leaky Tap in Washroom', 'Resolved', Colors.green),
        ],
      ),
    );
  }

  Widget _buildComplaintItem(String title, String status, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Text(status, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  void _showOutpassSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            const Text('Request Outpass', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Fill in the details to request permission to leave the premises.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 32),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildSheetTextField('Destination', Icons.map_outlined),
                    const SizedBox(height: 16),
                    _buildSheetTextField('Reason for Outpass', Icons.info_outline),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildSheetTextField('From Date', Icons.calendar_today)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildSheetTextField('To Date', Icons.calendar_today)),
                      ],
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('Submit Request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showComplaintSheet(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String category = 'Maintenance';
    String priority = 'Medium';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 24),
              const Text('Raise Complaint', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          labelText: 'Title',
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: category,
                        decoration: InputDecoration(
                          labelText: 'Category',
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        ),
                        items: ['Maintenance', 'Safety', 'Cleanliness', 'Other']
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) => setModalState(() => category = v ?? category),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: priority,
                        decoration: InputDecoration(
                          labelText: 'Priority',
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        ),
                        items: ['High', 'Medium', 'Low']
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) => setModalState(() => priority = v ?? priority),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: descController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Describe the issue...',
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (!AppServices.auth.isLoggedIn.value) {
                              AppNavigation.promptSignIn('Sign in to submit a complaint');
                              return;
                            }
                            if (titleController.text.trim().isEmpty || descController.text.trim().isEmpty) {
                              scaffoldMessengerKey.currentState?.showSnackBar(
                                const SnackBar(content: Text('Please fill title and description')),
                              );
                              return;
                            }
                            try {
                              await AppServices.complaints.createComplaint(
                                title: titleController.text.trim(),
                                description: descController.text.trim(),
                                category: category,
                                priority: priority,
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                              scaffoldMessengerKey.currentState?.showSnackBar(
                                const SnackBar(content: Text('Complaint submitted'), backgroundColor: Colors.green),
                              );
                            } on ApiException catch (e) {
                              scaffoldMessengerKey.currentState?.showSnackBar(
                                SnackBar(content: Text(e.message), backgroundColor: Colors.red),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text('Submit Complaint', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  void _showRentSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Rent & Payments', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(20)),
                  child: const Text('UNPAID', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withOpacity(0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Current Month', style: TextStyle(color: Colors.grey)),
                      Text('May 2026', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(height: 32),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Amount Due', style: TextStyle(color: Colors.grey)),
                      Text('₹8,500', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Due Date', style: TextStyle(color: Colors.grey)),
                      Text('10 May, 2026', style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text('Recent Payments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  _buildPaymentItem('April 2026', '₹8,500', 'Paid on 05 Apr', true),
                  _buildPaymentItem('March 2026', '₹8,500', 'Paid on 03 Mar', true),
                  _buildPaymentItem('February 2026', '₹8,500', 'Paid on 07 Feb', true),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close Rent Sheet
                  _showPaymentMethodSheet(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 5,
                  shadowColor: const Color(0xFF4F46E5).withOpacity(0.5),
                ),
                child: const Text('Pay Rent Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            const Text('Mess Menu & Timings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Check what\'s cooking today at Livora Kitchen.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 32),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMenuCard('Breakfast', '07:30 AM - 09:30 AM', 'Idli, Vada, Sambar, Chutney, Tea/Coffee', Icons.wb_sunny_outlined, Colors.orange),
                    _buildMenuCard('Lunch', '12:30 PM - 02:30 PM', 'Veg Biryani, Raita, Dal Tadka, Roti, Curd', Icons.light_mode_outlined, Colors.blue),
                    _buildMenuCard('Snacks', '05:00 PM - 06:00 PM', 'Onion Pakora, Masala Chai', Icons.coffee_outlined, Colors.brown),
                    _buildMenuCard('Dinner', '07:30 PM - 09:30 PM', 'Phulka, Paneer Butter Masala, Rice, Rasam', Icons.bedtime_outlined, Colors.indigo),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green[100]!),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.green),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Special Sunday Feast: Chicken Curry & Sweet will be served!',
                              style: TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  side: const BorderSide(color: Color(0xFF4F46E5)),
                ),
                child: const Text('Back to Portal', style: TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentMethodSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 24),
              const Text('Select Payment Method', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Choose your preferred way to pay rent securely.', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              _buildPaymentOption(context, 'UPI Apps', 'GPay, PhonePe, Paytm', Icons.account_balance_wallet_outlined, Colors.purple),
              _buildPaymentOption(context, 'Credit / Debit Card', 'Visa, Mastercard, RuPay', Icons.credit_card_outlined, Colors.blue),
              _buildPaymentOption(context, 'Net Banking', 'All major Indian banks', Icons.account_balance_outlined, Colors.orange),
              _buildPaymentOption(context, 'Wallets', 'Amazon Pay, Mobikwik', Icons.wallet_outlined, Colors.teal),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentOption(BuildContext context, String title, String subtitle, IconData icon, Color color) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context); // Close Method Sheet
        _showPaymentDetailsSheet(context, title);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[100]!),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  void _showPaymentDetailsSheet(BuildContext context, String method) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 12),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black87),
                      onPressed: () {
                        Navigator.pop(context);
                        _showPaymentMethodSheet(context);
                      },
                    ),
                    Text('Enter $method Details', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 24),
                if (method == 'UPI Apps') ...[
                  _buildSheetTextField('Enter UPI ID (e.g. name@okaxis)', Icons.alternate_email),
                  const SizedBox(height: 12),
                  const Text('Example: yourname@upi', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ] else if (method == 'Credit / Debit Card') ...[
                  _buildSheetTextField('Card Number', Icons.credit_card),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildSheetTextField('Expiry (MM/YY)', Icons.calendar_today)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildSheetTextField('CVV', Icons.lock_outline)),
                    ],
                  ),
                ] else if (method == 'Net Banking') ...[
                  const Text('Select Your Bank', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildBankChip('SBI'),
                      _buildBankChip('HDFC'),
                      _buildBankChip('ICICI'),
                      _buildBankChip('Axis'),
                      _buildBankChip('KOTAK'),
                    ],
                  ),
                ] else ...[
                  _buildSheetTextField('Enter Phone Number', Icons.phone),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Close details sheet
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PaymentProcessingScreen(method: method, amount: '₹8,500'),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Confirm & Pay Securely', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBankChip(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  Widget _buildSheetTextField(String hint, IconData icon) {
    return TextField(
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.grey),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
      ),
    );
  }

  Widget _buildPaymentItem(String month, String amount, String status, bool isPaid) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.green[50], shape: BoxShape.circle),
            child: const Icon(Icons.check, color: Colors.green, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(month, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(status, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Text(amount, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMenuCard(String meal, String time, String items, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(meal, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(time, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(items, style: TextStyle(color: Colors.grey[700], fontSize: 14, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PaymentProcessingScreen extends StatefulWidget {
  final String method;
  final String amount;
  const PaymentProcessingScreen({super.key, required this.method, required this.amount});

  @override
  State<PaymentProcessingScreen> createState() => _PaymentProcessingScreenState();
}

class _PaymentProcessingScreenState extends State<PaymentProcessingScreen> {
  bool _isProcessing = true;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _startSimulation();
  }

  void _startSimulation() async {
    // Simulate processing
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      setState(() {
        _isProcessing = false;
        _isSuccess = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isProcessing) ...[
                  const SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      strokeWidth: 8,
                      color: Color(0xFF4F46E5),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text( 
                    widget.method == 'UPI Apps' 
                      ? 'Authorizing UPI Transaction...' 
                      : widget.method == 'Credit / Debit Card'
                        ? 'Verifying Card Details...'
                        : 'Connecting to Secure Server...',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Please do not close the app or press back.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ] else if (_isSuccess) ...[
                  Container(
                    width: 100,
                    height: 100,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 60),
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    'Payment Successful!',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        _buildReceiptRow('Transaction ID', 'TXN${DateTime.now().millisecondsSinceEpoch}'),
                        const Divider(height: 32),
                        _buildReceiptRow('Payment Method', widget.method),
                        const Divider(height: 32),
                        _buildReceiptRow('Amount Paid', widget.amount),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Back to Home', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600])),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Wishlist'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              AppNavigation.goToHome();
            }
          },
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ValueListenableBuilder<Set<Property>>(
        valueListenable: savedPropertiesNotifier,
        builder: (context, savedProps, child) {
          if (savedProps.isEmpty) {
            return const Center(child: Text('Your wishlist is empty.', style: TextStyle(fontSize: 16, color: Colors.grey)));
          }
          final properties = savedProps.toList();
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: properties.length,
            itemBuilder: (context, index) {
              final prop = properties[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16.0),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(8.0),
                  leading: Hero(
                    tag: 'image_saved_${prop.title}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: PropertyImage(
                        imageUrl: prop.imageUrl,
                        width: 80,
                        height: 80,
                      ),
                    ),
                  ),
                  title: Text(prop.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(prop.location),
                  trailing: IconButton(
                    icon: const Icon(Icons.favorite, color: Colors.red),
                    onPressed: () {
                      final newSet = Set<Property>.from(savedPropertiesNotifier.value);
                      newSet.remove(prop);
                      savedPropertiesNotifier.value = newSet;
                    },
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PropertyDetailsScreen(property: prop),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _emergencyNameController = TextEditingController();
  final TextEditingController _emergencyPhoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _generatedOTP;
  bool _isLoginMode = true;
  bool _authLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = savedNameNotifier.value ?? '';
    _emailController.text = savedEmailNotifier.value ?? '';
    _phoneController.text = savedPhoneNotifier.value ?? '';
    _emergencyNameController.text = savedEmergencyNameNotifier.value ?? '';
    _emergencyPhoneController.text = savedEmergencyPhoneNotifier.value ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.length < 6) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Enter email and password (min 6 characters)')),
      );
      return;
    }
    if (!_isLoginMode) {
      if (_nameController.text.trim().isEmpty) {
        scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Please enter your full name')),
        );
        return;
      }
      if (_phoneController.text.length != 10) {
        scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Please enter a valid 10-digit phone number')),
        );
        return;
      }
    }
    setState(() => _authLoading = true);
    try {
      if (_isLoginMode) {
        final user = await AppServices.auth.login(email: email, password: password);
        await AppSession.applyAuthUser(user, email: email);
      } else {
        final user = await AppServices.auth.register(
          name: _nameController.text.trim(),
          email: email,
          password: password,
          phone: _phoneController.text.trim(),
        );
        await AppSession.applyAuthUser(
          user,
          email: email,
          phone: _phoneController.text.trim(),
        );
      }
      if (!mounted) return;
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(_isLoginMode ? 'Logged in successfully' : 'Account created successfully'),
          backgroundColor: Colors.green,
        ),
      );
      AppNavigation.goToHome();
    } on ApiException catch (e) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _authLoading = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? selected = await _picker.pickImage(source: ImageSource.gallery);
      if (selected != null) {
        profileImageNotifier.value = selected;
        if (AppServices.auth.isLoggedIn.value) {
          try {
            await AppServices.tenantPortal.uploadProfilePhoto(selected);
            scaffoldMessengerKey.currentState?.showSnackBar(
              const SnackBar(content: Text('Profile photo uploaded'), backgroundColor: Colors.green),
            );
          } on ApiException catch (e) {
            scaffoldMessengerKey.currentState?.showSnackBar(
              SnackBar(content: Text(e.message), backgroundColor: Colors.orange),
            );
          }
        }
      }
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      });
    }
  }

  void _removeImage() {
    profileImageNotifier.value = null;
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFF4F46E5)),
                title: const Text('Upload Profile'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove Profile', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _removeImage();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOTPDialog(BuildContext context) {
    // Validate all fields first
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Please Enter the Required Fields'),
            backgroundColor: Colors.orange,
          ),
        );
      });
      return;
    }

    if (_phoneController.text.length != 10) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Please enter a valid 10-digit phone number')),
        );
      });
      return;
    }

    // Generate a random 6-digit OTP
    final random = DateTime.now().millisecond.toString().padRight(6, '0').substring(0, 6);
    _generatedOTP = random;
    
    debugPrint('Attempting to verify phone: ${_phoneController.text}');
    debugPrint('Generated OTP: $_generatedOTP');

    // For demo purposes, we'll show the OTP in a snackbar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Demo OTP sent to ${_phoneController.text}: $_generatedOTP'),
          duration: const Duration(seconds: 5),
        ),
      );
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Verify Phone Number'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter the 6-digit OTP sent to\n+91 ${_phoneController.text}'),
            const SizedBox(height: 16),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 8),
              decoration: InputDecoration(
                counterText: '',
                hintText: '000000',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _otpController.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              debugPrint('Verifying OTP: ${_otpController.text} against $_generatedOTP');
              if (_otpController.text == _generatedOTP) {
                Navigator.pop(context);
                _otpController.clear();
                
                // Save the profile details globally
                savedNameNotifier.value = _nameController.text.trim();
                savedEmailNotifier.value = _emailController.text.trim();
                savedPhoneNotifier.value = _phoneController.text.trim();
                savedEmergencyNameNotifier.value = _emergencyNameController.text.trim();
                savedEmergencyPhoneNotifier.value = _emergencyPhoneController.text.trim();

                Future<void> runSuccessSequence() async {
                  debugPrint('Starting success sequence...');

                  scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
                  scaffoldMessengerKey.currentState?.showSnackBar(
                    const SnackBar(
                      content: Text('Verified Successfully'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );

                  await Future.delayed(const Duration(milliseconds: 1500));

                  if (!mounted) return;
                  AppNavigation.goToHome();

                  scaffoldMessengerKey.currentState?.showSnackBar(
                    const SnackBar(
                      content: Text('Login Credentials are Saved'),
                      backgroundColor: Color(0xFF4F46E5),
                      duration: Duration(seconds: 2),
                    ),
                  );

                  debugPrint('Success sequence complete.');
                }

                runSuccessSequence();
              } else {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  scaffoldMessengerKey.currentState?.showSnackBar(
                    const SnackBar(
                      content: Text('Enter Correct OTP'),
                      backgroundColor: Colors.red,
                    ),
                  );
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
            ),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppServices.auth.isLoggedIn,
      builder: (context, loggedIn, child) {
        if (!loggedIn) {
          return _buildAuthView();
        }
        return _buildProfileDetailsView(savedNameNotifier.value ?? 'Resident');
      },
    );
  }

  Widget _buildAuthView() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: AppNavigation.goToHome,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Livora',
              style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Color(0xFF4F46E5), letterSpacing: -1.5),
            ),
            const SizedBox(height: 8),
            Text(
              _isLoginMode ? 'Welcome back! Please login to your account.' : 'Join the elite community. Create your account today.',
              style: const TextStyle(fontSize: 16, color: Colors.grey, height: 1.4),
            ),
            const SizedBox(height: 48),
            
            if (!_isLoginMode) ...[
              _buildAuthField('Full Name', Icons.person_outline, _nameController),
              const SizedBox(height: 20),
            ],
            _buildAuthField('Email Address', Icons.email_outlined, _emailController),
            const SizedBox(height: 20),
            _buildAuthField('Phone Number', Icons.phone_outlined, _phoneController),
            const SizedBox(height: 20),
            _buildAuthField('Password', Icons.lock_outline, _passwordController, obscure: true),
            const SizedBox(height: 40),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _authLoading ? null : _submitAuth,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 8,
                  shadowColor: const Color(0xFF4F46E5).withOpacity(0.4),
                ),
                child: _authLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_isLoginMode ? 'Login' : 'Sign Up', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 32),
            
            Center(
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _isLoginMode = !_isLoginMode;
                  });
                },
                child: RichText(
                  text: TextSpan(
                    text: _isLoginMode ? "Don't have an account yet? " : "Already have an account? ",
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                    children: [
                      TextSpan(
                        text: _isLoginMode ? "Sign Up" : "Login",
                        style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthField(String label, IconData icon, TextEditingController controller, {bool obscure = false}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: const Color(0xFF4F46E5)),
        filled: true,
        fillColor: Colors.grey[50],
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.grey[200]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFF4F46E5))),
      ),
    );
  }

  Widget _buildProfileDetailsView(String name) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: AppNavigation.goToHome,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () async {
              await AppSession.logout();
              if (!context.mounted) return;
              scaffoldMessengerKey.currentState?.showSnackBar(
                const SnackBar(content: Text('Logged out successfully')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Center(
              child: Stack(
                children: [
                  ValueListenableBuilder<XFile?>(
                    valueListenable: profileImageNotifier,
                    builder: (context, imageFile, child) {
                      ImageProvider? profileImage;
                      if (imageFile != null) {
                        if (kIsWeb) {
                          profileImage = NetworkImage(imageFile.path);
                        } else {
                          profileImage = FileImage(File(imageFile.path));
                        }
                      }
                      return Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF4F46E5), width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 65,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: profileImage,
                          child: profileImage == null
                              ? const Icon(Icons.person, size: 65, color: Colors.grey)
                              : null,
                        ),
                      );
                    },
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _showImageOptions,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF4F46E5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const Text('Premium Resident • Room 304', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 32),

            // Digital ID Card Section
            _buildSectionHeader('Digital ID Card', Icons.badge_outlined),
            const SizedBox(height: 16),
            _buildDigitalIDCard(name),
            const SizedBox(height: 32),

            // Booking History Section
            _buildSectionHeader('My Bookings', Icons.history),
            const SizedBox(height: 16),
            _buildBookingHistory(),
            const SizedBox(height: 32),

            _buildSectionHeader('Profile Information', Icons.info_outline),
            const SizedBox(height: 16),
            _buildProfileField('Name', 'Enter your name', controller: _nameController),
            const SizedBox(height: 8),
            _buildProfileField('Email ID', 'Enter your email id', controller: _emailController),
            const SizedBox(height: 8),
            _buildProfileField('Phone Number', 'Enter your number', controller: _phoneController),
            const SizedBox(height: 16),
            SwitchListTile(
              value: false, // Placeholder for state
              onChanged: (val) {
                scaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text('Night Mode will be available in the next update!')));
              },
              title: const Text('Night Mode', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              secondary: const Icon(Icons.dark_mode_outlined, color: Color(0xFF4F46E5)),
              activeColor: const Color(0xFF4F46E5),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 24),
            const Row(
              children: [
                Icon(Icons.emergency_share, color: Colors.red),
                SizedBox(width: 8),
                Text('Emergency Contact', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
              ],
            ),
            const SizedBox(height: 16),
            _buildProfileField('Contact Name', 'Emergency contact name', controller: _emergencyNameController),
            const SizedBox(height: 16),
            _buildProfileField('Contact Number', 'Emergency contact number', controller: _emergencyPhoneController),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 24),
            const Row(
              children: [
                Icon(Icons.help_outline, color: Color(0xFF4F46E5)),
                SizedBox(width: 8),
                Text('Help & Support', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            _buildSupportTile(Icons.question_answer_outlined, 'Frequently Asked Questions', () {
              _showFAQDialog(context);
            }),
            _buildSupportTile(Icons.support_agent_outlined, 'Contact Customer Support', () async {
              final Uri url = Uri.parse('https://wa.me/919876543213');
              if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                debugPrint('Could not launch WhatsApp');
              }
            }),
            _buildSupportTile(Icons.feedback_outlined, 'Share App Feedback', () {
              _showFeedbackDialog(context);
            }),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _showOTPDialog(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Save Profile Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () async {
                await AppSession.logout();
                scaffoldMessengerKey.currentState?.showSnackBar(
                  const SnackBar(content: Text('Logged out successfully')),
                );
              },
              child: const Text('Logout from Account', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileField(String label, String hint, {TextEditingController? controller}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
            const Text(' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: label == 'Phone Number' || label == 'Contact Number' ? TextInputType.phone : TextInputType.text,
          maxLength: label == 'Phone Number' || label == 'Contact Number' ? 10 : null,
          decoration: InputDecoration(
            counterText: '',
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey, fontWeight: FontWeight.normal),
            filled: true,
            fillColor: Colors.grey[100],
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
          ),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildSupportTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF4F46E5).withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF4F46E5), size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
      onTap: onTap,
    );
  }

  void _showFAQDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Frequently Asked Questions'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: const [
              _FAQItem(q: 'How do I book a hostel?', a: 'Tap on any hostel and click "Book Now" at the bottom.'),
              _FAQItem(q: 'Are the prices negotiable?', a: 'Prices are fixed but look out for exclusive seasonal discounts!'),
              _FAQItem(q: 'What is the refund policy?', a: 'Refunds are subject to the hostel\'s specific cancellation policy.'),
              _FAQItem(q: 'How to update my profile?', a: 'Enter new details and verify your phone number to save changes.'),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  void _showFeedbackDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Feedback'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('We value your experience! Tell us how we can improve Livora.'),
            const SizedBox(height: 16),
            TextField(
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Type your feedback here...',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              scaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text('Thank you for your feedback!')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF4F46E5), size: 20),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildDigitalIDCard(String name) {
    return Container(
      width: double.infinity,
      height: 200,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF818CF8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(Icons.apartment, size: 150, color: Colors.white.withOpacity(0.1)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('LIVORA ID', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 12)),
                  Icon(Icons.nfc, color: Colors.white70),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  const Text('RESIDENT ID: SN-2024-304', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ROOM NO', style: TextStyle(color: Colors.white70, fontSize: 10)),
                      Text('304', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('EXPIRES', style: TextStyle(color: Colors.white70, fontSize: 10)),
                      Text('DEC 2026', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.qr_code, size: 40, color: Color(0xFF4F46E5)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBookingHistory() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          _buildBookingItem('Starlight Men\'s PG', '12 Jan - 15 Feb', 'Completed', Colors.green),
          const Divider(height: 1),
          _buildBookingItem('Elite Boys Hostel', 'Upcoming Stay', 'Confirmed', Colors.blue),
        ],
      ),
    );
  }

  Widget _buildBookingItem(String title, String date, String status, Color color) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(date, style: const TextStyle(fontSize: 12)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Text(status, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _FAQItem extends StatelessWidget {
  final String q, a;
  const _FAQItem({required this.q, required this.a});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(q, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
          const SizedBox(height: 4),
          Text(a, style: const TextStyle(color: Colors.black87)),
        ],
      ),
    );
  }
}

class CategoryScreen extends StatelessWidget {
  final String categoryName;
  const CategoryScreen({super.key, required this.categoryName});

  @override
  Widget build(BuildContext context) {
    final filteredProps = propertyCatalogNotifier.value
        .where((p) => p.category == categoryName)
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(categoryName),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(24.0),
        itemCount: filteredProps.length,
        itemBuilder: (context, index) {
          final prop = filteredProps[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => PropertyDetailsScreen(property: prop)));
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 24.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Hero(
                    tag: 'image_cat_${prop.title}',
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16.0)),
                      child: PropertyImage(
                        imageUrl: prop.imageUrl,
                        height: 180,
                        width: double.infinity,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                prop.title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              '₹${prop.price}/mo',
                              style: const TextStyle(
                                color: Color(0xFF4F46E5),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(prop.location, style: TextStyle(color: Colors.grey[600])),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              prop.rating.toString(),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
