import '../core/utils/image_resolver.dart';

class Review {
  final String userName;
  final String comment;
  final double rating;
  final String date;

  Review({
    required this.userName,
    required this.comment,
    required this.rating,
    required this.date,
  });
}

class Property {
  final String? id;
  final String title;
  final String location;
  /// Canonical city used for filters (e.g. "Bengaluru").
  final String city;
  final int price;
  final double rating;
  final String imageUrl;
  final List<String> tags;
  final String category;
  final String foodDetails;
  final List<Review> reviews;
  final double distance;

  Property({
    this.id,
    required this.title,
    required this.location,
    required this.city,
    required this.price,
    required this.rating,
    required this.imageUrl,
    required this.tags,
    required this.category,
    required this.foodDetails,
    required this.reviews,
    this.distance = 1.5,
  });

  factory Property.fromBuildingJson(Map<String, dynamic> json) {
    final images = json['images'];
    var imageUrl = 'assets/images/property_1.jpg';
    if (images is List && images.isNotEmpty) {
      imageUrl = ImageResolver.resolve(images.first.toString());
    }

    final priceRaw = json['startingPrice'];
    final price = priceRaw is num
        ? priceRaw.toInt()
        : int.tryParse('$priceRaw') ?? 0;

    final ratingRaw = json['rating'];
    final rating = ratingRaw is num
        ? ratingRaw.toDouble()
        : double.tryParse('$ratingRaw') ?? 4.0;

    final cityRaw = json['locationCity']?.toString() ?? '';
    final city = canonicalizeCity(cityRaw);
    final address = json['address']?.toString() ?? '';
    final location =
        [address, city].where((s) => s.isNotEmpty).join(', ');

    final amenities = json['amenities'];
    final tags = amenities is List
        ? amenities.map((e) => e.toString()).toList()
        : <String>[];

    return Property(
      id: json['_id']?.toString(),
      title: json['name']?.toString() ?? 'Hostel',
      location: location.isEmpty ? city : location,
      city: city,
      price: price,
      rating: rating,
      imageUrl: imageUrl,
      tags: tags,
      category: _categoryFromGender(json['genderType']?.toString()),
      foodDetails: tags.isNotEmpty ? tags.take(3).join(', ') : 'Meals available',
      reviews: const [],
    );
  }

  /// Normalizes backend city spellings/aliases into a single canonical display.
  ///
  /// Policy: show canonical city (e.g. "Bengaluru") everywhere, but accept
  /// common aliases from backend or persisted UI selections (e.g. "Bangalore").
  static String canonicalizeCity(String? input) {
    final raw = (input ?? '').trim();
    if (raw.isEmpty) return '';
    final key = raw.toLowerCase();
    if (key == 'bangalore' || key == 'bengaluru' || key == 'bengalore') {
      return 'Bengaluru';
    }
    return raw;
  }

  static String _categoryFromGender(String? genderType) {
    final raw = (genderType ?? '').trim().toLowerCase();
    switch (raw) {
      case 'boys':
      case 'male':
      case 'men':
      case "men's":
        return "Men's Hostel";
      case 'girls':
      case 'female':
      case 'women':
      case "women's":
        return "Women's Hostel";
      case 'mixed':
      case 'co-living':
      case 'coliving':
      case 'co living':
        return 'Co-living';
      default:
        // Backends often send free-form values (e.g. "Boys", "Girls", "Mixed").
        // Default to the most inclusive bucket instead of misclassifying.
        return 'Co-living';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Property) return false;
    if (id != null && other.id != null) return id == other.id;
    return title == other.title && location == other.location;
  }

  @override
  int get hashCode => id?.hashCode ?? Object.hash(title, location);
}
