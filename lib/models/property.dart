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

    final city = json['locationCity']?.toString() ?? '';
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
      price: price,
      rating: rating,
      imageUrl: imageUrl,
      tags: tags,
      category: _categoryFromGender(json['genderType']?.toString()),
      foodDetails: tags.isNotEmpty ? tags.take(3).join(', ') : 'Meals available',
      reviews: const [],
    );
  }

  static String _categoryFromGender(String? genderType) {
    switch (genderType?.toLowerCase()) {
      case 'male':
        return "Men's Hostel";
      case 'female':
        return "Women's";
      case 'mixed':
        return 'Co-living';
      default:
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
