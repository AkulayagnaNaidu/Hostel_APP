import 'package:flutter/material.dart';

import 'app_state.dart';

/// Central navigation helpers for tab shell + root navigator.
class AppNavigation {
  AppNavigation._();

  static const int tabHome = 0;
  static const int tabExplore = 1;
  static const int tabPortal = 2;
  static const int tabSaved = 3;
  static const int tabProfile = 4;

  static void goToTab(int index) {
    mainTabIndexNotifier.value = index;
  }

  static void goToHome() {
    goToTab(tabHome);
    final nav = navigatorKey.currentState;
    if (nav != null && nav.canPop()) {
      nav.popUntil((route) => route.isFirst);
    }
  }

  static void goToProfileSignIn() {
    goToTab(tabProfile);
    final nav = navigatorKey.currentState;
    if (nav != null && nav.canPop()) {
      nav.popUntil((route) => route.isFirst);
    }
  }

  static void promptSignIn(String message) {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'Sign in',
          onPressed: goToProfileSignIn,
        ),
      ),
    );
    goToProfileSignIn();
  }
}
