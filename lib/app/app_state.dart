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
    ValueNotifier<String?>('John Doe (Father)');
final ValueNotifier<String?> savedEmergencyPhoneNotifier =
    ValueNotifier<String?>('9876543210');
final ValueNotifier<Set<Property>> savedPropertiesNotifier =
    ValueNotifier<Set<Property>>({});
final ValueNotifier<XFile?> profileImageNotifier = ValueNotifier<XFile?>(null);
