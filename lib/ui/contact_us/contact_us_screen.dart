import 'package:customer/constant/constant.dart';
import 'package:customer/constant/show_toast_dialog.dart';
import 'package:customer/controller/contact_us_controller.dart';
import 'package:customer/themes/app_colors.dart';
import 'package:customer/themes/button_them.dart';
import 'package:customer/themes/responsive.dart';
import 'package:customer/themes/text_field_them.dart';
import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // final themeChange = Provider.of<DarkThemeProvider>(context);
    return GetX<ContactUsController>(
        init: ContactUsController(),
        builder: (controller) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Column(
              children: [
                SizedBox(
                  height: Responsive.width(25, context),
                  width: Responsive.width(100, context),
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(25),
                            topRight: Radius.circular(25))),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: controller.isLoading.value
                          ? Constant.loader()
                          : Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: DefaultTabController(
                                length: 2,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text("Contact us".tr,
                                          style: GoogleFonts.poppins(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w600)),
                                      Text(
                                          "Let us know your issue & feedback"
                                              .tr,
                                          style: GoogleFonts.poppins()),
                                      const SizedBox(
                                        height: 20,
                                      ),
                                      TabBar(
                                        indicator: BoxDecoration(
                                          color: Colors
                                              .black, // Active tab background color
                                          borderRadius: BorderRadius.circular(
                                              8), // Rounded corners
                                        ),
                                        labelColor: Colors
                                            .white, // Active tab text color
                                        unselectedLabelColor: Colors.grey
                                            .withOpacity(
                                                0.9), // Inactive tab text color
                                        indicatorSize: TabBarIndicatorSize
                                            .tab, // Ensure indicator matches tab size
                                        overlayColor: WidgetStateProperty.all(Colors
                                            .transparent), // Remove default hover/click effects
                                        dividerColor: Colors.transparent,
                                        tabs: [
                                          Tab(
                                              child: Text(
                                            "Call Us".tr,
                                            style: GoogleFonts.poppins(),
                                          )),
                                          Tab(
                                              child: Text(
                                            "Email Us".tr,
                                            style: GoogleFonts.poppins(),
                                          )),
                                        ],
                                      ),
                                      Expanded(
                                        child: TabBarView(
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 20),
                                              child: Column(
                                                children: [
                                                  InkWell(
                                                    onTap: () {
                                                      Constant.makePhoneCall(
                                                          controller
                                                              .phone.value);
                                                    },
                                                    child: Row(
                                                      children: [
                                                        const Icon(Icons.call),
                                                        const SizedBox(
                                                          width: 20,
                                                        ),
                                                        Text(controller
                                                            .phone.value)
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(
                                                    height: 10,
                                                  ),
                                                  const Divider(),
                                                  const SizedBox(
                                                    height: 10,
                                                  ),
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                          Icons.location_on),
                                                      const SizedBox(
                                                        width: 20,
                                                      ),
                                                      Expanded(
                                                          child: Text(controller
                                                              .address.value))
                                                    ],
                                                  )
                                                ],
                                              ),
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 10),
                                              child: SingleChildScrollView(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text("Write us".tr,
                                                        style:
                                                            GoogleFonts.poppins(
                                                                fontSize: 20,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600)),
                                                    Text(
                                                        "Describe your issue"
                                                            .tr,
                                                        style: GoogleFonts
                                                            .poppins()),
                                                    const SizedBox(
                                                      height: 20,
                                                    ),
                                                    TextFieldThem.buildTextFiled(
                                                        context,
                                                        hintText: 'Email'.tr,
                                                        controller: controller
                                                            .emailController
                                                            .value),
                                                    const SizedBox(
                                                      height: 20,
                                                    ),
                                                    TextFieldThem.buildTextFiled(
                                                        context,
                                                        hintText:
                                                            'Describe your issue and feedback'
                                                                .tr,
                                                        controller: controller
                                                            .feedbackController
                                                            .value,
                                                        maxLine: 5),
                                                    const SizedBox(
                                                      height: 20,
                                                    ),
                                                    ButtonThem.buildButton(
                                                      context,
                                                      title: "Submit".tr,
                                                      onPress: () async {
                                                        if (controller
                                                            .emailController
                                                            .value
                                                            .text
                                                            .isEmpty) {
                                                          ShowToastDialog.showToast(
                                                              "Please enter email"
                                                                  .tr);
                                                        } else if (controller
                                                            .feedbackController
                                                            .value
                                                            .text
                                                            .isEmpty) {
                                                          ShowToastDialog.showToast(
                                                              "Please enter feedback"
                                                                  .tr);
                                                        } else {
                                                          final Email email =
                                                              Email(
                                                            body: controller
                                                                .feedbackController
                                                                .value
                                                                .text,
                                                            subject: controller
                                                                .subject.value,
                                                            recipients: [
                                                              controller
                                                                  .email.value
                                                            ],
                                                            cc: [
                                                              controller
                                                                  .emailController
                                                                  .value
                                                                  .text
                                                            ],
                                                            isHTML: false,
                                                          );
                                                          await FlutterEmailSender
                                                              .send(email);
                                                          controller
                                                              .emailController
                                                              .value
                                                              .clear();
                                                          controller
                                                              .feedbackController
                                                              .value
                                                              .clear();
                                                        }
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            )
                                          ],
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          );
        });
  }
}
