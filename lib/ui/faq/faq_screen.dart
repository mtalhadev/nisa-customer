import 'package:customer/constant/constant.dart';
import 'package:customer/model/faq_model.dart';
import 'package:customer/themes/app_colors.dart';
import 'package:customer/themes/responsive.dart';
import 'package:customer/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {

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
              decoration: BoxDecoration(color:Colors.white, borderRadius: const BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25))),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("FAQs".tr, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600)),
                      Text("Read FAQs solution".tr, style: GoogleFonts.poppins()),
                      const SizedBox(
                        height: 0,
                      ),
                      Expanded(
                        child: FutureBuilder<List<FaqModel>?>(
                            future: FireStoreUtils.getFaq(),
                            builder: (context, snapshot) {
                              switch (snapshot.connectionState) {
                                case ConnectionState.waiting:
                                  return Constant.loader();
                                case ConnectionState.done:
                                  if (snapshot.hasError) {
                                    return Text(snapshot.error.toString());
                                  } else {
                                    List<FaqModel> faqList = snapshot.data!;
                                    return ListView.builder(
                                      itemCount: faqList.length,
                                      shrinkWrap: true,
                                      itemBuilder: (context, index) {
                                        FaqModel faqModel = faqList[index];
                                        return InkWell(
                                          onTap: () {
                                            faqModel.isShow = true;
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 5),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: const Color.fromARGB(255, 255, 255, 255),
                                                borderRadius: const BorderRadius.all(Radius.circular(10)),
                                                border: Border.all(color:  AppColors.containerBorder, width: 0.5),
                                                boxShadow:  [
                                                        BoxShadow(
                                                          color: Colors.grey.withOpacity(0.5),
                                                          blurRadius: 8,
                                                          offset: const Offset(0, 2), // changes position of shadow
                                                        ),
                                                      ],
                                              ),
                                              child: ExpansionTile(
                                                title: Text(Constant.localizationTitle(faqModel.title), style: GoogleFonts.poppins()),
                                                children: <Widget>[
                                                  ListTile(
                                                    title: Text(Constant.localizationDescription(faqModel.description), style: GoogleFonts.poppins()),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  }
                                default:
                                  return  Text('Error'.tr);
                              }
                            }),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
