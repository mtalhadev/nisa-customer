import 'package:customer/constant/show_toast_dialog.dart';
import 'package:customer/ui/auth_screen/login_screen.dart';
import 'package:customer/ui/contact_us/contact_us_screen.dart';
import 'package:customer/ui/faq/faq_screen.dart';
import 'package:customer/ui/home_screens/home_screen.dart';
import 'package:customer/ui/orders/order_screen.dart';
import 'package:customer/ui/profile_screen/profile_screen.dart';
import 'package:customer/ui/settings_screen/setting_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

class DashBoardController extends GetxController {
  RxList<DrawerItem> drawerItems = [
    DrawerItem('City'.tr, "assets/icons/ic_city.svg"),
    DrawerItem('OutStation'.tr, "assets/icons/ic_intercity.svg"),
    DrawerItem('Rides'.tr, "assets/icons/ic_order.svg"),
    DrawerItem('OutStation Rides'.tr, "assets/icons/ic_order.svg"),
    DrawerItem('My Wallet'.tr, "assets/icons/ic_wallet.svg"),
    DrawerItem('Settings'.tr, "assets/icons/ic_settings.svg"),
    DrawerItem('Referral a friends'.tr, "assets/icons/ic_referral.svg"),
    DrawerItem('Inbox'.tr, "assets/icons/ic_inbox.svg"),
    DrawerItem('Profile'.tr, "assets/icons/ic_profile.svg"),
    DrawerItem('Contact us'.tr, "assets/icons/ic_contact_us.svg"),
    DrawerItem('FAQs'.tr, "assets/icons/ic_faq.svg"),
    DrawerItem('Log out'.tr, "assets/icons/ic_logout.svg"),
  ].obs;

  // Define which indices are implemented
  final List<int> implementedIndices = [0, 2, 5, 8, 9, 10, 11];

  Widget getDrawerItemWidget(int pos) {
    switch (pos) {
      case 0:
        return const HomeScreen();
      case 2:
        return const OrderScreen();
      case 5:
        return const SettingScreen();
      case 8:
        return const ProfileScreen();
      case 9:
        return const ContactUsScreen();
      case 10:
        return const FaqScreen();
      default:
        // Return a placeholder widget for unimplemented screens
        return const SizedBox.shrink();
    }
  }

  @override
  void onInit() {
    super.onInit();
  }

  RxInt selectedDrawerIndex = 0.obs;

  onSelectItem(int index) async {
    if (index == 11) {
      await FirebaseAuth.instance.signOut();
      Get.offAll(const LoginScreen());
    } else if (!implementedIndices.contains(index)) {
      // Show "Coming Soon" popup for unimplemented screens
      ShowToastDialog.showToast(
        "Coming Soon",
        position: EasyLoadingToastPosition.center,
        duration: const Duration(seconds: 3),
      );
      Get.back(); // Close the drawer
    } else {
      selectedDrawerIndex.value = index;
      Get.back(); // Close the drawer
    }
  }

  Rx<DateTime> currentBackPressTime = DateTime.now().obs;

  Future<bool> onWillPop() {
    DateTime now = DateTime.now();
    if (now.difference(currentBackPressTime.value) > const Duration(seconds: 2)) {
      currentBackPressTime.value = now;
      ShowToastDialog.showToast(
        "Double press to exit",
        position: EasyLoadingToastPosition.center,
      );
      return Future.value(false);
    }
    return Future.value(true);
  }
}

class DrawerItem {
  String title;
  String icon;

  DrawerItem(this.title, this.icon);
}