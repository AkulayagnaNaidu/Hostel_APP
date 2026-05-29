import 'package:flutter/material.dart';

class HostelFullDetailsView extends StatefulWidget {
  final Map<String, dynamic> data;
  final List<String> fallbackAmenities;

  const HostelFullDetailsView({
    super.key,
    required this.data,
    this.fallbackAmenities = const [],
  });

  @override
  State<HostelFullDetailsView> createState() => _HostelFullDetailsViewState();
}

class _HostelFullDetailsViewState extends State<HostelFullDetailsView> {
  String _selectedRoomType = '2 Sharing';
  int _selectedBedIndex = 1;

  static int _asInt(dynamic v) =>
      v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

  static bool _asBool(dynamic v) {
    if (v is bool) return v;
    final s = '$v'.toLowerCase();
    return s == 'true' || s == '1' || s == 'yes';
  }

  static String _str(dynamic v, [String fallback = '-']) {
    if (v == null) return fallback;
    final s = v.toString();
    return s.isEmpty ? fallback : s;
  }

  List<Map<String, dynamic>> _allBeds(List<dynamic> floors) {
    final beds = <Map<String, dynamic>>[];
    for (final f in floors) {
      final fm = f is Map ? f.cast<String, dynamic>() : const <String, dynamic>{};
      final rooms = (fm['rooms'] as List?) ?? const [];
      for (final r in rooms) {
        final rm = r is Map ? r.cast<String, dynamic>() : const <String, dynamic>{};
        final roomBeds = (rm['beds'] as List?) ?? const [];
        for (final b in roomBeds) {
          if (b is Map) beds.add(b.cast<String, dynamic>());
        }
      }
    }
    return beds;
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final draft = (data['draftData'] as Map?)?.cast<String, dynamic>() ?? const {};
    final policies = (data['policies'] as Map?)?.cast<String, dynamic>() ?? const {};
    final smart = (data['smartConfig'] as Map?)?.cast<String, dynamic>() ?? const {};
    final floors = (data['floors'] as List?) ?? const [];
    final amenities = (data['amenities'] as List?)?.map((e) => e.toString()).toList() ??
        widget.fallbackAmenities;

    final beds = _allBeds(floors);
    final available = beds.where((b) {
      final s = (b['status']?.toString() ?? '').toUpperCase();
      return s == 'AVAILABLE' || s == 'VACANT' || s == 'FREE';
    }).length;
    final occupied = beds.length - available;
    final occupancyPct = beds.isNotEmpty ? ((occupied / beds.length) * 100).round() : 70;

    final rentSingle = _asInt(data['rentSingle'] ?? draft['rentSingle']);
    final rentDouble = _asInt(data['rentDouble'] ?? draft['rentDouble']);
    final rentTriple = _asInt(data['rentTriple'] ?? draft['rentTriple']);
    final starting = _asInt(data['startingPrice']);

    final sharing = draft['roomTypeSelect']?.toString().isNotEmpty == true
        ? '${draft['roomTypeSelect']} Sharing'
        : '2 Sharing';
    final category = _str(data['category'], 'Students');
    final gender = _str(data['genderType'], 'Boys');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('📊', 'Overview & Details'),
        const SizedBox(height: 8),
        const Text('Occupancy & Category',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _statCard('SHARING', sharing, const Color(0xFFEFF6FF))),
            const SizedBox(width: 10),
            Expanded(child: _statCard('CATEGORY', category, const Color(0xFFF5F3FF))),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _statCard('GENDER', gender, const Color(0xFFFFF7ED))),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard('OCCUPANCY', '$occupancyPct% Full', const Color(0xFFECFDF5)),
            ),
          ],
        ),
        const SizedBox(height: 28),
        _sectionTitle('🏢', 'Building & Security'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _iconTile('🏢', 'Floor', '${draft['numFloors'] ?? floors.length} Floor'),
            _iconTile('🛗', 'Lift', amenities.any((a) => a.toLowerCase().contains('lift')) ? 'Available' : 'Not listed'),
            _iconTile('🔋', 'Power Backup', amenities.any((a) => a.toLowerCase().contains('power')) ? '24/7 Generator' : 'Not listed'),
            _iconTile('📷', 'CCTV', amenities.any((a) => a.toLowerCase().contains('cctv')) ? 'All Common Areas' : 'Not listed'),
            _iconTile('👮', 'Security', amenities.any((a) => a.toLowerCase().contains('security')) ? '24/7 Guard' : 'Not listed'),
            _iconTile('🅿️', 'Parking', amenities.any((a) => a.toLowerCase().contains('parking')) ? '2-Wheeler' : 'Not listed'),
          ],
        ),
        const SizedBox(height: 28),
        const Text('Smart Safety & Security',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (_asBool(smart['hasCCTVAi']) || amenities.any((a) => a.toLowerCase().contains('cctv'))) _chip('CCTV Active'),
            if (draft['staffRole'] != null) _chip('Live-in Warden'),
            if (_asBool(smart['hasSmartAccess']) || amenities.contains('Biometric Access')) _chip('Biometric Entry'),
            _chip('Fire Safety Equipped'),
            if (gender.toLowerCase().contains('girl') || gender.toLowerCase().contains('women')) _chip('Female Safety Verified'),
            _chip('Emergency Contact'),
            _chip('Visitor Tracking'),
            _chip('Night Security Guard'),
          ],
        ),
        const SizedBox(height: 28),
        _sectionTitle('📍', 'Nearby Access & Transit'),
        const SizedBox(height: 12),
        ...[
          ('Metro Station', '800m'),
          ('Bus Stop', '200m'),
          ('Grocery Store', '100m'),
          ('Hospital', '1km'),
          ('Restaurants', '50m'),
          ('Gym', '300m'),
        ].map((e) => _nearbyRow(e.$1, e.$2)),
        const SizedBox(height: 28),
        _sectionTitle('🛏️', 'Select Room Type'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          children: ['Single Room', '2 Sharing', '3 Sharing'].map((type) {
            final selected = _selectedRoomType == type;
            return ChoiceChip(
              label: Text(type),
              selected: selected,
              onSelected: (_) => setState(() => _selectedRoomType = type),
              selectedColor: const Color(0xFF4F46E5).withOpacity(0.15),
              labelStyle: TextStyle(
                color: selected ? const Color(0xFF4F46E5) : Colors.black87,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        const Text('Room Dimensions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _dimCard('LENGTH', '12 ft')),
            const SizedBox(width: 10),
            Expanded(child: _dimCard('WIDTH', '14 ft')),
            const SizedBox(width: 10),
            Expanded(child: _dimCard('TOTAL AREA', '168 sq ft')),
          ],
        ),
        const SizedBox(height: 24),
        const Text('Room Insights', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['Sunlight', 'Ventilation', 'Quietness', 'Study Env', 'Privacy', 'Freshness']
              .map((t) => _chip(t))
              .toList(),
        ),
        const SizedBox(height: 8),
        const Text('Best For:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: ['Students', 'Exam Prep', 'Remote Work'].map((t) => _chip(t, filled: true)).toList(),
        ),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Bed Availability', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('AI Smart Match', style: TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: const Text(
            'Based on your profile, Bed 2 in 2-Sharing is a 95% match for your study-focused routine and quiet preferences.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          children: ['#BestValue', '#MostQuiet', '#ExamFriendly'].map((t) => _chip(t, filled: true)).toList(),
        ),
        const SizedBox(height: 12),
        Text('Total Beds: ${beds.isEmpty ? 2 : beds.length}  •  Available: ${beds.isEmpty ? 2 : available}  •  Occupied: ${beds.isEmpty ? 0 : occupied}',
            style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        if (beds.isEmpty)
          ...List.generate(2, (i) => _bedRow(i + 1, 'Single Cot • Window Side • Head → South', i == _selectedBedIndex))
        else
          ...beds.asMap().entries.map((e) {
            final b = e.value;
            final num = _str(b['bedNumber'], 'Bed ${e.key + 1}');
            final pos = _str(b['position'], 'Window Side');
            final status = (b['status']?.toString() ?? '').toUpperCase();
            final avail = status == 'AVAILABLE' || status == 'VACANT' || status == 'FREE';
            return _bedRow(e.key + 1, '$num • $pos', e.key == _selectedBedIndex, available: avail);
          }),
        const SizedBox(height: 20),
        const Text('Bed Details & Preferences', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            'Available', 'AC', 'Non-AC', 'Window Side', 'Quiet Zone', 'Study Friendly',
            'With Locker', 'Lower Bunk', 'Upper Bunk', 'Near Window', 'Best WiFi',
          ].map((t) => _chip(t)).toList(),
        ),
        const SizedBox(height: 16),
        ...List.generate(2, (i) => _luxuryBedCard(i + 1, i == _selectedBedIndex)),
        const SizedBox(height: 28),
        _sectionTitle('🤝', 'Roommate Compatibility'),
        const SizedBox(height: 12),
        _compatRow('SLEEP SCHEDULE', 'Early Birds (10 PM - 6 AM)'),
        _compatRow('STUDY FRIENDLY', 'Very High'),
        _compatRow('CLEANLINESS', 'Strictly Clean'),
        _compatRow('NOISE PREFERENCE', 'Pin-drop Quiet'),
        _compatRow('OCCUPANTS', '2 Engineering Students'),
        _compatRow('COMPATIBLE WITH', 'Students, Interns'),
        const SizedBox(height: 28),
        _sectionTitle('🛋️', 'Room Facilities'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _facility('🪭', 'Fans', '1'),
            _facility('💡', 'Lights', '2'),
            _facility('🪟', 'Windows', '2'),
            _facility('🔌', 'Sockets', '4'),
            _facility('🗄️', 'Cupboards', '2'),
            _facility('📚', 'Study Table', 'Yes'),
            _facility('🪑', 'Chair', '2'),
            _facility('📶', 'WiFi', 'High-Speed'),
            _facility('❄️', 'AC', _asBool(data['isAC']) ? 'AC' : 'Non-AC'),
          ],
        ),
        const SizedBox(height: 28),
        const Text('Bathroom Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        _compatRow('TYPE', 'Attached'),
        _compatRow('COUNT', '1 per room'),
        _compatRow('HOT WATER', '24/7 Geyser'),
        _compatRow('TOILET', 'Western'),
        const SizedBox(height: 28),
        const Text('Student-Friendly Features', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            'Study Table Available', 'Library 500m Away', 'Exam Quiet Hours', 'High-Speed WiFi',
            '4+ Charging Points', 'Laptop Friendly', 'Group Study Area', 'Online Class Friendly',
          ].map((t) => _chip(t)).toList(),
        ),
        const SizedBox(height: 28),
        _sectionTitle('🍽️', 'Dining & Food'),
        const SizedBox(height: 12),
        _compatRow('MEAL TYPE', _str(draft['foodType'], 'Veg + Non-Veg')),
        _compatRow('WEEKLY MENU', '7-day rotation'),
        _compatRow('CUSTOM MENU', 'On request'),
        if (draft['mealPlans'] is List && (draft['mealPlans'] as List).isNotEmpty)
          _compatRow('MEAL PLANS', (draft['mealPlans'] as List).join(', ')),
        const SizedBox(height: 28),
        _sectionTitle('🎉', 'Hostel Community & Lifestyle'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _lifestyle('🎉', 'Weekly Events'),
            _lifestyle('🍿', 'Weekend Movie Nights'),
            _lifestyle('🎮', 'Gaming Zone (PS5)'),
            _lifestyle('🛋️', 'Common AC Lounge'),
            _lifestyle('💪', 'Free Gym Access'),
            _lifestyle('🌅', 'Rooftop Chill Area'),
            _lifestyle('🤝', 'Startup Networking'),
            _lifestyle('🪔', 'Festival Celebrations'),
          ],
        ),
        const SizedBox(height: 28),
        _sectionTitle('💰', 'Pricing Comparison'),
        const SizedBox(height: 12),
        _pricingTable(
          single: rentSingle > 0 ? rentSingle : starting,
          doubleRent: rentDouble > 0 ? rentDouble : (starting > 0 ? (starting * 0.67).round() : 6667),
          triple: rentTriple > 0 ? rentTriple : (starting > 0 ? (starting * 0.5).round() : 5000),
        ),
        const SizedBox(height: 28),
        _sectionTitle('📜', 'House Rules'),
        const SizedBox(height: 12),
        if (policies.isEmpty)
          ...[
            '🚫 No smoking inside rooms or common areas',
            '⏰ Visitors allowed between 9 AM – 8 PM only',
            '🤫 Quiet hours from 10 PM – 7 AM',
            '🧹 Keep rooms clean; weekly inspection applies',
            '🐕 No pets allowed on premises',
            '🪪 ID verification mandatory for all residents',
          ].map((r) => _ruleRow(r))
        else
          ...policies.entries.map((e) => _ruleRow('${_policyEmoji(e.key)} ${_policyText(e.key, e.value)}')),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _sectionTitle(String emoji, String title) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _statCard(String label, String value, Color bg) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey[600], letterSpacing: 0.8)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _iconTile(String emoji, String label, String value) {
    return Container(
      width: (MediaQuery.of(context).size.width - 68) / 2,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _chip(String text, {bool filled = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: filled ? const Color(0xFF4F46E5).withOpacity(0.1) : Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: filled ? const Color(0xFF4F46E5).withOpacity(0.3) : Colors.grey[300]!),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: filled ? const Color(0xFF4F46E5) : const Color(0xFF374151),
        ),
      ),
    );
  }

  Widget _nearbyRow(String place, String distance) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(place, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(distance, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _dimCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _bedRow(int index, String subtitle, bool selected, {bool available = true}) {
    return GestureDetector(
      onTap: () => setState(() => _selectedBedIndex = index - 1),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF4F46E5).withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFF4F46E5) : Colors.grey[300]!,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bed $index', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF4F46E5)
                    : (available ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                selected ? 'SELECTED' : (available ? 'AVAILABLE' : 'OCCUPIED'),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.white : (available ? Colors.green[800] : Colors.orange[800]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _luxuryBedCard(int index, bool selected) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selected ? const Color(0xFF4F46E5) : Colors.grey[300]!, width: selected ? 2 : 1),
        color: selected ? const Color(0xFF4F46E5).withOpacity(0.04) : Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('#$index', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF4F46E5))),
              const SizedBox(width: 8),
              const Text('Luxury Bed', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF4F46E5) : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  selected ? 'SELECTED' : 'AVAILABLE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: selected ? Colors.white : Colors.green[800],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            index == 1 ? 'Single Cot • Near Door' : 'Lower Bunk • Window Side',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: ['Quiet Zone', 'Charging Socket', 'Study Friendly', 'AC', '4.5', 'Quiet']
                .map((t) => _chip(t))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _compatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(label, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w700, fontSize: 12)),
          ),
          Expanded(
            flex: 6,
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _facility(String emoji, String label, String value) {
    return Container(
      width: (MediaQuery.of(context).size.width - 68) / 2,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _lifestyle(String emoji, String label) {
    return Container(
      width: (MediaQuery.of(context).size.width - 68) / 2,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _pricingTable({required int single, required int doubleRent, required int triple}) {
    return Table(
      border: TableBorder.all(color: Colors.grey[300]!),
      columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(3), 2: FlexColumnWidth(2)},
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey[100]),
          children: const [
            Padding(padding: EdgeInsets.all(10), child: Text('Room Type', style: TextStyle(fontWeight: FontWeight.bold))),
            Padding(padding: EdgeInsets.all(10), child: Text('Description', style: TextStyle(fontWeight: FontWeight.bold))),
            Padding(padding: EdgeInsets.all(10), child: Text('Monthly Rent', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        _priceRow('Single Room', 'Private room', single),
        _priceRow('2 Sharing', '2 beds per room', doubleRent),
        _priceRow('3 Sharing', '3 beds per room', triple),
      ],
    );
  }

  TableRow _priceRow(String type, String desc, int rent) {
    return TableRow(
      children: [
        Padding(padding: const EdgeInsets.all(10), child: Text(type, style: const TextStyle(fontWeight: FontWeight.w600))),
        Padding(padding: const EdgeInsets.all(10), child: Text(desc)),
        Padding(padding: const EdgeInsets.all(10), child: Text('₹${rent.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
      ],
    );
  }

  Widget _ruleRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
        ],
      ),
    );
  }

  String _policyEmoji(String key) {
    switch (key.toLowerCase()) {
      case 'smoking':
        return '🚫';
      case 'alcohol':
        return '🚫';
      case 'pets':
        return '🐕';
      case 'visitors':
        return '⏰';
      default:
        return '📌';
    }
  }

  String _policyText(String key, dynamic value) {
    final v = value?.toString() ?? '';
    switch (key.toLowerCase()) {
      case 'smoking':
        return 'No smoking: $v';
      case 'alcohol':
        return 'Alcohol: $v';
      case 'pets':
        return 'Pets: $v';
      case 'visitors':
        return 'Visitors: $v';
      default:
        return '${key[0].toUpperCase()}${key.substring(1)}: $v';
    }
  }
}
