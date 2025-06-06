import 'package:cached_network_image/cached_network_image.dart';
import 'package:customer/constant/constant.dart';
import 'package:customer/controller/dash_board_controller.dart';
import 'package:customer/model/user_model.dart';
import 'package:customer/themes/app_colors.dart';
import 'package:customer/themes/responsive.dart';
import 'package:customer/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class DashBoardScreen extends StatelessWidget {
  const DashBoardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetX<DashBoardController>(
      init: DashBoardController(),
      builder: (controller) {
        final GlobalKey<ScaffoldState> _scaffoldKey =
            GlobalKey<ScaffoldState>();
        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: Colors.white,
          body: Stack(
            children: [
              WillPopScope(
                onWillPop: controller.onWillPop,
                child: controller.getDrawerItemWidget(
                    controller.selectedDrawerIndex.value),
              ),
              Positioned(
                top: 40,
                left: 16,
                child: FloatingActionButton(
                  onPressed: () {
                    _scaffoldKey.currentState?.openDrawer();
                  },
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  mini: true,
                  child: SvgPicture.asset(
                    'assets/icons/ic_humber.svg',
                    color: AppColors.primary,
                    width: 20,
                    height: 15,
                  ),
                ),
              ),
            ],
          ),
          drawer: buildAppDrawer(context, controller),
        );
      },
    );
  }

  Widget buildAppDrawer(BuildContext context, DashBoardController controller) {
    var drawerOptions = <Widget>[];
    for (var i = 0; i < controller.drawerItems.length; i++) {
      var d = controller.drawerItems[i];
      drawerOptions.add(
        InkWell(
          onTap: () {
            controller.onSelectItem(i);
          },
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              decoration: BoxDecoration(
                color: i == controller.selectedDrawerIndex.value
                    ? const Color(0xffE75480)
                    : Colors.transparent,
                borderRadius: const BorderRadius.all(Radius.circular(10)),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  SvgPicture.asset(
                    d.icon,
                    width: 20,
                    color: i == controller.selectedDrawerIndex.value
                        ? Colors.white
                        : AppColors.drawerIcon,
                  ),
                  const SizedBox(width: 20),
                  Text(
                    d.title,
                    style: GoogleFonts.poppins(
                      color: i == controller.selectedDrawerIndex.value
                          ? Colors.white
                          : Colors.black,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        children: [
          DrawerHeader(
            child: FutureBuilder<UserModel?>(
              future: FireStoreUtils.getUserProfile(
                  FireStoreUtils.getCurrentUid()),
              builder: (context, snapshot) {
                switch (snapshot.connectionState) {
                  case ConnectionState.waiting:
                    return Constant.loader();
                  case ConnectionState.done:
                    if (snapshot.hasError) {
                      return Text(snapshot.error.toString());
                    } else {
                      UserModel driverModel = snapshot.data!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(60),
                            child: CachedNetworkImage(
                              height: Responsive.width(20, context),
                              width: Responsive.width(20, context),
                              imageUrl: driverModel.profilePic.toString(),
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Constant.loader(),
                              errorWidget: (context, url, error) =>
                                  Image.network(Constant.userPlaceHolder),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              driverModel.fullName.toString(),
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              driverModel.email.toString(),
                              style: GoogleFonts.poppins(),
                            ),
                          ),
                        ],
                      );
                    }
                  default:
                    return Text('Error'.tr);
                }
              },
            ),
          ),
          Column(children: drawerOptions),
        ],
      ),
    );
  }
}