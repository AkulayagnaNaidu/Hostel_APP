import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/property.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final ValueNotifier<int> mainTabIndexNotifier = ValueNotifier<int>(0);
final ValueNotifier<String?> savedNameNotifier = ValueNotifier<String?>(null);
final ValueNotifier<String?> savedEmailNotifier = ValueNotifier<String?>(null);
final ValueNotifier<String?> savedPhoneNotifier = ValueNotifier<String?>(null);
final ValueNotifier<String?> savedEmergencyNameNotifier =
    ValueNotifier<String?>(null);
final ValueNotifier<String?> savedEmergencyPhoneNotifier =
    ValueNotifier<String?>(null);
final ValueNotifier<Set<Property>> savedPropertiesNotifier =
    ValueNotifier<Set<Property>>({});
final ValueNotifier<XFile?> profileImageNotifier = ValueNotifier<XFile?>(null);
final ValueNotifier<String?> exploreCategoryFilterNotifier =
    ValueNotifier<String?>(null);
final ValueNotifier<String> exploreSearchQueryNotifier =
    ValueNotifier<String>('');

/// Shared filters from Home filter sheet → Explore tab.
final ValueNotifier<String?> exploreLocationFilterNotifier =
    ValueNotifier<String?>(null);
final ValueNotifier<RangeValues?> explorePriceRangeNotifier =
    ValueNotifier<RangeValues?>(null);
/// `'AC'` or `'Non AC'` (Home) / `'Non-AC'` (Explore) — normalized in Explore.
final ValueNotifier<String?> exploreRoomTypeFilterNotifier =
    ValueNotifier<String?>(null);
