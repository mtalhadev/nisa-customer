import 'dart:convert';
import 'dart:developer';
import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:customer/constant/constant.dart';
import 'package:customer/constant/show_toast_dialog.dart';
import 'package:customer/controller/home_controller.dart';
import 'package:customer/model/airport_model.dart';
import 'package:customer/model/order/location_lat_lng.dart';
import 'package:customer/model/banner_model.dart';
import 'package:customer/model/contact_model.dart';
import 'package:customer/model/order/positions.dart';
import 'package:customer/model/order_model.dart';
import 'package:customer/model/service_model.dart';
import 'package:customer/themes/app_colors.dart';
import 'package:customer/themes/button_them.dart';
import 'package:customer/themes/responsive.dart';
import 'package:customer/themes/text_field_them.dart';
import 'package:customer/utils/fire_store_utils.dart';
import 'package:customer/utils/utils.dart';
import 'package:customer/widget/geoflutterfire/src/geoflutterfire.dart';
import 'package:customer/widget/geoflutterfire/src/models/point.dart';
import 'package:customer/widget/place_picker_osm.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dash/flutter_dash.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_place_picker_mb/google_maps_place_picker.dart';
import 'package:geocoding/geocoding.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GoogleMapController? mapController;
  Set<Marker> _markers = {};
  Map<PolylineId, Polyline> polylines = {};
  dynamic currentPlace;
  dynamic destinationPlace;
  LatLng? selectedLocation;
  bool _isMapReady = false;
  bool _isMapLoading = false;

  @override
  void initState() {
    super.initState();
    _checkInternetConnection();
    _requestLocationPermission();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));

    log("API KEY: ${Constant.mapAPIKey}");
  }

  @override
  void dispose() {
    mapController?.dispose();
    super.dispose();
  }

  Future<void> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        log('Internet connection available');
      }
    } on SocketException catch (_) {
      log('No internet connection');
      ShowToastDialog.showToast("Please connect to the internet.");
    }
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.location.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      ShowToastDialog.showToast(
          "Location permission is required to use this feature. Please enable it in settings.");
      if (status.isPermanentlyDenied) {
        await openAppSettings();
      }
    }
  }

  Future<void> _addMarker(LatLng position, HomeController controller,
      {bool isSource = true}) async {
    try {
      setState(() {
        _isMapLoading = true;
      });
      log('Adding marker at: ${position.latitude}, ${position.longitude}, isSource: $isSource');

      final markerId = MarkerId(isSource ? 'source' : 'destination');

      final icon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(28, 28)),
        isSource
            ? 'assets/images/green_mark.png'
            : 'assets/images/red_mark.png',
      );

      final marker = Marker(
        markerId: markerId,
        position: position,
        icon: icon,
      );

      setState(() {
        _markers
            .removeWhere((element) => element.markerId.value == markerId.value);
        _markers.add(marker);
      });
      String displayName = "${position.latitude}, ${position.longitude}";
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          displayName =
              "${place.street}, ${place.subLocality}, ${place.locality}, ${place.administrativeArea}, ${place.country}";
          displayName = displayName
              .split(', ')
              .where((element) => element.isNotEmpty && element != "null")
              .join(', ');
        }
      } catch (e) {
        log('Geocoding error: $e');
        ShowToastDialog.showToast(
            "Failed to get place name, using coordinates");
      }

      if (isSource) {
        controller.sourceLocationController.value.text = displayName;
        controller.sourceLocationLAtLng.value = LocationLatLng(
          latitude: position.latitude,
          longitude: position.longitude,
        );
        currentPlace = {
          'displayName': displayName,
          'lat': position.latitude,
          'lon': position.longitude
        };
        log('Source set: $displayName');
      } else {
        controller.destinationLocationController.value.text = displayName;
        controller.destinationLocationLAtLng.value = LocationLatLng(
          latitude: position.latitude,
          longitude: position.longitude,
        );
        destinationPlace = {
          'displayName': displayName,
          'lat': position.latitude,
          'lon': position.longitude
        };
        log('Destination set: $displayName');
      }

      if (mapController != null) {
        mapController!.animateCamera(CameraUpdate.newLatLng(position));
      }

      if (controller.sourceLocationLAtLng.value.latitude != null &&
          controller.destinationLocationLAtLng.value.latitude != null) {
        log('Both locations set, attempting to draw route');
        final start = LatLng(
          controller.sourceLocationLAtLng.value.latitude!,
          controller.sourceLocationLAtLng.value.longitude!,
        );
        final end = LatLng(
          controller.destinationLocationLAtLng.value.latitude!,
          controller.destinationLocationLAtLng.value.longitude!,
        );
        await _drawRoute(start, end);
        await controller.calculateAmount();
      }
    } catch (e, stackTrace) {
      log('Error adding marker: $e, stackTrace: $stackTrace');
      ShowToastDialog.showToast("Failed to add marker");
    } finally {
      setState(() {
        _isMapLoading = false;
        log('Hiding map loader');
      });
    }
  }

  Future<void> _drawRoute(LatLng start, LatLng end,
      {int retryCount = 0}) async {
    const maxRetries = 3;
    try {
      setState(() {
        _isMapLoading = true;
      });
      developer.log(
          'Drawing route from ${start.latitude},${start.longitude} to ${end.latitude},${end.longitude}, retryCount: $retryCount');

      if (!_isValidLatLng(start) || !_isValidLatLng(end)) {
        developer.log('Invalid coordinates: start=$start, end=$end');
        ShowToastDialog.showToast("Invalid coordinates for route");
        return;
      }

      developer.log("API Key: ${Constant.mapAPIKey}");
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${start.latitude},${start.longitude}'
        '&destination=${end.latitude},${end.longitude}'
        '&mode=driving'
        '&key=${'AIzaSyCCRRxa1OS0ezPBLP2fep93uEfW2oANKx4'}',
      );
      final response = await http.get(uri);
      developer.log("Response: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final points = data['routes'][0]['overview_polyline']['points'];
          final List<PointLatLng> polylinePoints =
              PolylinePoints().decodePolyline(points);

          final List<LatLng> polylineCoordinates = polylinePoints
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();

          PolylineId id = const PolylineId("route");
          Polyline polyline = Polyline(
            polylineId: id,
            color: AppColors.primary,
            points: polylineCoordinates,
            width: 5,
          );

          final distanceMeters = data['routes'][0]['legs'][0]['distance']
              ['value'] as int;
          final distanceKm = (distanceMeters / 1000)
              .toStringAsFixed(2);
          final durationText = data['routes'][0]['legs'][0]['duration']['text']
              as String;

          final controller = Get.find<HomeController>();
          controller.distance.value = distanceKm;
          controller.duration.value = durationText;
          await controller.calculateAmount();

          setState(() {
            polylines[id] = polyline;
          });

          LatLngBounds bounds = LatLngBounds(
            southwest: LatLng(
              start.latitude < end.latitude ? start.latitude : end.latitude,
              start.longitude < end.longitude ? start.longitude : end.longitude,
            ),
            northeast: LatLng(
              start.latitude > end.latitude ? start.latitude : end.latitude,
              start.longitude > end.longitude ? start.longitude : end.longitude,
            ),
          );

          if (mapController != null) {
            await mapController!
                .animateCamera(CameraUpdate.newLatLngBounds(bounds, 70));
            developer.log('Route drawn successfully');
          } else {
            developer.log('Map controller is null');
          }
        } else {
          developer.log('Route request failed: ${data['error_message']}');
          ShowToastDialog.showToast(
              "Failed to draw route");
        }
      } else {
        developer.log('HTTP Error: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      developer.log('Error drawing route: $e, stackTrace: $stackTrace');
      if (retryCount < maxRetries && !e.toString().contains('REQUEST_DENIED')) {
        developer.log('Retrying route drawing...');
        await Future.delayed(const Duration(milliseconds: 1000));
        await _drawRoute(start, end, retryCount: retryCount + 1);
      } else {
        ShowToastDialog.showToast("Failed to draw route");
      }
    } finally {
      setState(() {
        _isMapLoading = false;
        developer.log('Hiding map loader');
      });
    }
  }

  bool _isValidLatLng(LatLng point) {
    return point.latitude >= -90 &&
        point.latitude <= 90 &&
        point.longitude >= -180 &&
        point.longitude <= 180;
  }

  Future<void> _setUserLocation(HomeController controller) async {
    try {
      setState(() {
        _isMapLoading = true;
      });
      final status = await Permission.location.status;
      if (!status.isGranted) {
        log('Location permission not granted');
        await _requestLocationPermission();
        if (!(await Permission.location.status).isGranted) {
          ShowToastDialog.showToast("Location permission is required");
          return;
        }
      }

      final locationData = await Utils.getCurrentLocation();
      final userLocation = LatLng(
        locationData.latitude,
        locationData.longitude,
      );
      log('User location: ${userLocation.latitude}, ${userLocation.longitude}');

      if (mapController != null) {
        mapController!.animateCamera(CameraUpdate.newLatLng(userLocation));
      }

      await _addMarker(userLocation, controller, isSource: true);
    } catch (e, stackTrace) {
      log('Error setting user location: $e, stackTrace: $stackTrace');
      ShowToastDialog.showToast("Failed to get your location");
    } finally {
      setState(() {
        _isMapLoading = false;
        log('Hiding map loader');
      });
    }
  }

  Future<void> _clearMap(HomeController controller) async {
    try {
      setState(() {
        _isMapLoading = true;
      });
      setState(() {
        _markers.clear();
        polylines.clear();
        _resetLocations(controller);
      });
      log('Map cleared');
    } catch (e, stackTrace) {
      log('Error clearing map: $e, stackTrace: $stackTrace');
      ShowToastDialog.showToast("Failed to clear map");
    } finally {
      setState(() {
        _isMapLoading = false;
      });
    }
  }

  void _resetLocations(HomeController controller) {
    controller.sourceLocationController.value.text = "";
    controller.destinationLocationController.value.text = "";
    controller.sourceLocationLAtLng.value = LocationLatLng();
    controller.destinationLocationLAtLng.value = LocationLatLng();
    controller.amount.value = "";
    controller.distance.value = "0";
    currentPlace = null;
    destinationPlace = null;
    log('Locations reset');
  }

  Future<void> _handleSearchedLocation(
      dynamic place, HomeController controller) async {
    if (!mounted) return;
    try {
      setState(() {
        _isMapLoading = true;
      });

      double lat;
      double lon;
      String displayName;

      if (place is Map<String, dynamic>) {
        lat = (place['lat'] is String
                    ? double.tryParse(place['lat'])
                    : place['lat'])
                ?.toDouble() ??
            0.0;
        lon = (place['lon'] is String
                    ? double.tryParse(place['lon'])
                    : place['lon'])
                ?.toDouble() ??
            0.0;
        displayName = place['displayName']?.toString() ??
            place['name']?.toString() ??
            place['address']?.toString() ??
            "${lat}, ${lon}";
      } else if (place is PickResult) {
        lat = place.geometry?.location.lat ?? 0.0;
        lon = place.geometry?.location.lng ?? 0.0;
        displayName = place.formattedAddress ?? place.name ?? "${lat}, ${lon}";
      } else {
        if (kDebugMode) {
          log('Unsupported place format: ${place.runtimeType}');
        }
        throw Exception("Unsupported place format");
      }

      if (lat == 0.0 && lon == 0.0) {
        if (kDebugMode) {
          log('Invalid coordinates: lat=$lat, lon=$lon');
        }
        ShowToastDialog.showToast("Invalid location selected");
        return;
      }

      final position = LatLng(lat, lon);
      if (mapController != null) {
        mapController!.animateCamera(CameraUpdate.newLatLng(position));
      }

      await _addMarker(position, controller,
          isSource: controller.sourceLocationLAtLng.value.latitude == null);
    } catch (e, stackTrace) {
      if (kDebugMode) {
        log('Error handling searched location: $e, stackTrace: $stackTrace');
      }
      ShowToastDialog.showToast("Failed to handle searched location");
    } finally {
      setState(() {
        _isMapLoading = false;
        if (kDebugMode) {
          log('Hiding map loader');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetX<HomeController>(
      init: HomeController(),
      builder: (controller) {
        return Scaffold(
          body: SafeArea(
            top: false,
            child: Stack(
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height,
                  width: MediaQuery.of(context).size.width,
                  child: Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: const CameraPosition(
                          target: LatLng(0, 0),
                          zoom: 14,
                        ),
                        onMapCreated: (GoogleMapController mapCtrl) {
                          mapController = mapCtrl;
                          setState(() {
                            _isMapReady = true;
                            log('Map is ready');
                            _setUserLocation(controller);
                          });
                        },
                        markers: _markers,
                        polylines: Set<Polyline>.of(polylines.values),
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        mapType: MapType.normal,
                        onTap: (LatLng position) async {
                          await _addMarker(position, controller,
                              isSource: controller.sourceLocationLAtLng.value
                                          .latitude ==
                                      null ||
                                  controller.destinationLocationLAtLng.value
                                          .latitude !=
                                      null);
                        },
                      ),
                      if (_isMapLoading)
                        Container(
                          color: Colors.black.withOpacity(0.3),
                          child: const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.primary),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                _buildMainContent(context, controller),
              ],
            ),
          ),
        );
      },
    );
  }
Widget _buildMainContent(BuildContext context, HomeController controller) {
    return Stack(
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.only(left: 10, right: 10),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBannerSlider(context, controller),
                        SizedBox(height: 10),
                        _buildLocationInputs(context, controller),
                        if (controller.sourceLocationLAtLng.value.latitude !=
                                null &&
                            controller.destinationLocationLAtLng.value.latitude !=
                                null)
                          _buildServiceList(context, controller),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: _buildOfferRateField(context, controller),
                        ),
                        const SizedBox(height: 5),
                        _buildBookRideButton(context, controller),
                        const SizedBox(height: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: MediaQuery.of(context).size.height * 0.35,
          child: FloatingActionButton(
            onPressed: () => _setUserLocation(controller),
            backgroundColor: Colors.white,
            heroTag: "my_location_button",
            child: Icon(
              Icons.my_location,
              color: AppColors.primary,
            ),
            mini: true,
            elevation: 2,
          ),
        ),
      ],
    );
  }


  Widget _buildBannerSlider(BuildContext context, HomeController controller) {
    return Visibility(
      visible: controller.bannerList.isNotEmpty,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.20,
        child: PageView.builder(
          padEnds: false,
          itemCount: controller.bannerList.length,
          scrollDirection: Axis.horizontal,
          controller: controller.pageController,
          itemBuilder: (context, index) {
            final bannerModel = controller.bannerList[index];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: CachedNetworkImage(
                imageUrl: bannerModel.image.toString(),
                imageBuilder: (context, imageProvider) => Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    image: DecorationImage(
                      image: imageProvider,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                color: Colors.black.withOpacity(0.5),
                placeholder: (context, url) =>
                    const Center(child: CircularProgressIndicator()),
                fit: BoxFit.cover,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildServiceList(BuildContext context, HomeController controller) {
    // Helper function to format duration text
    String _formatDuration(String durationText) {
      if (durationText.isEmpty) return "5 min";

      // Parse hours and minutes from the duration text
      RegExp regExp = RegExp(r'(\d+)\s*hours?\s*(\d+)\s*minut');
      RegExpMatch? match = regExp.firstMatch(durationText);

      if (match != null) {
        int hours = int.parse(match.group(1) ?? "0");
        int minutes = int.parse(match.group(2) ?? "0");

        if (hours > 0) {
          return "$hours h $minutes min";
        } else {
          return "$minutes min";
        }
      }

      return durationText;
    }

    return SizedBox(
      height: Responsive.height(13, context),
      child: ListView.builder(
        itemCount: controller.serviceList.length,
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 11.0),
        itemBuilder: (context, index) {
          final serviceModel = controller.serviceList[index];

          // Calculate price for each service based on its own rate
          String priceDisplay = 'N/A';
          if (controller.distance.value.isNotEmpty &&
              controller.distance.value != "0" &&
              serviceModel.kmCharge != null &&
              double.tryParse(serviceModel.kmCharge!) != null &&
              double.parse(serviceModel.kmCharge!) > 0) {
            final distance = double.parse(controller.distance.value);
            final kmCharge = double.parse(serviceModel.kmCharge!);
            final price = distance * kmCharge;
            priceDisplay =
                Constant.amountShow(amount: price.toStringAsFixed(0));
          }

          return Obx(
            () => InkWell(
              onTap: () {
                if (serviceModel.kmCharge == null ||
                    double.parse(serviceModel.kmCharge!) <= 0) {
                  developer.log(
                      'Invalid kmCharge for service: ${serviceModel.title}');
                  ShowToastDialog.showToast(
                      "Selected vehicle has invalid pricing. Please try another vehicle.");
                  return;
                }
                controller.selectedType.value = serviceModel;
                developer.log(
                    'Selected vehicle: ${serviceModel.title}, kmCharge=${serviceModel.kmCharge}');

                if (controller.distance.value.isNotEmpty &&
                    controller.distance.value != "0") {
                  if (Constant.selectedMapType == 'osm') {
                    controller.calculateOsmAmount();
                  } else {
                    controller.calculateAmount();
                  }
                  developer.log(
                      'Amount calculation triggered for vehicle: ${serviceModel.title}');
                } else {
                  developer
                      .log('Distance not set, skipping amount calculation');
                  ShowToastDialog.showToast(
                      "Please select source and destination to calculate the fare.");
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3.0),
                child: Opacity(
                  opacity:
                      controller.selectedType.value == serviceModel ? 1.0 : 0.5,
                  child: Container(
                    width: Responsive.width(24, context),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius:
                              controller.selectedType.value == serviceModel
                                  ? 4
                                  : 2,
                          spreadRadius: 0.5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                alignment: Alignment.bottomLeft,
                                children: [
                                  SizedBox(
                                    height: Responsive.height(5, context),
                                    width: double.infinity,
                                    child: CachedNetworkImage(
                                      imageUrl: serviceModel.image.toString(),
                                      fit: BoxFit.contain,
                                      placeholder: (context, url) =>
                                          Constant.loader(),
                                      errorWidget: (context, url, error) =>
                                          Image.network(
                                              Constant.userPlaceHolder),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 2, horizontal: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.2),
                                            blurRadius: 2,
                                            spreadRadius: 0.5,
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        _formatDuration(
                                            controller.duration.value),
                                        style: GoogleFonts.poppins(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Divider(
                                color: AppColors.gray,
                                height: 1,
                                thickness: 1,
                                endIndent: 5,
                                indent: 5,
                              ),
                              const SizedBox(height: 2),
                              Padding(
                                padding: const EdgeInsets.only(left: 4.0),
                                child: Text(
                                  Constant.localizationTitle(
                                      serviceModel.title),
                                  style: GoogleFonts.poppins(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                  textAlign: TextAlign.start,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Padding(
                                padding: const EdgeInsets.only(left: 4.0),
                                child: Text(
                                  priceDisplay,
                                  style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                  textAlign: TextAlign.start,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRideDetails(BuildContext context, HomeController controller) {
    return Obx(
      () {
        developer.log(
            'RideDetails state: sourceLat=${controller.sourceLocationLAtLng.value.latitude}, '
            'destLat=${controller.destinationLocationLAtLng.value.latitude}, '
            'amount=${controller.amount.value}, '
            'distance=${controller.distance.value}, '
            'duration=${controller.duration.value}');

        if (controller.sourceLocationLAtLng.value.latitude != null &&
            controller.destinationLocationLAtLng.value.latitude != null &&
            controller.amount.value.isNotEmpty) {
          return Column(
            children: [
              const SizedBox(height: 10),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: Container(
                  width: Responsive.width(100, context),
                  decoration: const BoxDecoration(
                    color: AppColors.lightGray,
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    child: Center(
                      child: controller.selectedType.value.offerRate == true
                          ? RichText(
                              text: TextSpan(
                                text:
                                    'Recommended Price is ${Constant.amountShow(amount: controller.amount.value)}. Approx time ${controller.duration}. Approx distance ${double.parse(controller.distance.value).toStringAsFixed(Constant.currencyModel!.decimalDigits!)} ${Constant.distanceType}'
                                        .tr,
                                style: GoogleFonts.poppins(color: Colors.black),
                              ),
                            )
                          : RichText(
                              text: TextSpan(
                                text:
                                    'Your Price is ${Constant.amountShow(amount: controller.amount.value)}. Approx time ${controller.duration}. Approx distance ${double.parse(controller.distance.value).toStringAsFixed(Constant.currencyModel!.decimalDigits!)} ${Constant.distanceType}'
                                        .tr,
                                style: GoogleFonts.poppins(color: Colors.black),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          );
        } else {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Text(
              'Ride details not available. Please select source, destination, and a service type.',
              style: GoogleFonts.poppins(color: Colors.red, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          );
        }
      },
    );
  }

  Widget _buildLocationInputs(BuildContext context, HomeController controller) {
    return Padding(
      padding: EdgeInsets.only(left: 10, right: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // const SizedBox(height: 10),

          // const SizedBox(height: 20),
          controller.sourceLocationLAtLng.value.latitude == null
              ? InkWell(
                  onTap: () =>
                      _selectLocation(context, controller, isSource: true),
                  child: TextFieldThem.buildTextFiled(
                    context,
                    hintText: 'Enter Your Current Location'.tr,
                    controller: controller.sourceLocationController.value,
                    enable: false,
                  ),
                )
              : Row(
                  children: [
                    Column(
                      children: [
                        SvgPicture.asset(
                          'assets/icons/ic_destination_dark.svg',
                          width: 20,
                        ),
                        Dash(
                            direction: Axis.vertical,
                            length: Responsive.height(5, context),
                            dashLength: 5,
                            dashColor: AppColors.dottedDivider),
                        SvgPicture.asset('assets/icons/ic_destination.svg',
                            width: 20),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () => _selectLocation(context, controller,
                                isSource: true),
                            child: Row(
                              children: [
                                // Stack(
                                //   alignment: Alignment.center,
                                //   children: [
                                //     Container(
                                //       width: 20, // Outer circle diameter
                                //       height: 20,
                                //       decoration: BoxDecoration(
                                //         color: Colors.green, // Green outer circle
                                //         shape: BoxShape.circle,
                                //       ),
                                //     ),
                                //     Container(
                                //       width: 10, // Inner circle diameter (hole)
                                //       height: 10,
                                //       decoration: BoxDecoration(
                                //         color: Colors
                                //             .white, // Match this to the screen background color
                                //         shape: BoxShape.circle,
                                //       ),
                                //     ),
                                //   ],
                                // ),
                                // SizedBox(width: 2),
                                Expanded(
                                  child: TextFieldThem.buildTextFiled(
                                    context,
                                    hintText: 'Enter Location'.tr,
                                    controller: controller
                                        .sourceLocationController.value,
                                    enable: false,
                                  ),
                                ),
                                const SizedBox(width: 10),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () => _selectLocation(context, controller,
                                isSource: false),
                            child: Padding(
                              padding: const EdgeInsets.only(
                                top: 8.0,
                                right: 8.0,
                                bottom: 8.0,
                                left: 0.0,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.all(
                                      Radius.circular(8)),
                                  color: AppColors.gray,
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(width: 6),
                                    Icon(
                                      Icons.search,
                                    ),
                                    Expanded(
                                      child: TextFieldThem.buildTextFiled(
                                        context,
                                        hintText:
                                            'Enter destination Location'.tr,
                                        controller: controller
                                            .destinationLocationController
                                            .value,
                                        enable: false,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Future<void> _selectLocation(BuildContext context, HomeController controller,
      {required bool isSource}) async {
    try {
      if (kDebugMode) {
        log('Selecting location, isSource: $isSource, mapType: ${Constant.selectedMapType}');
      }
      if (Constant.selectedMapType == 'osm') {
        final value = await Get.to(() => const LocationPicker());
        if (value != null && value is Map<String, dynamic>) {
          final textController = isSource
              ? controller.sourceLocationController.value
              : controller.destinationLocationController.value;
          final locationLatLng = isSource
              ? controller.sourceLocationLAtLng
              : controller.destinationLocationLAtLng;

          final displayName = value['displayName']?.toString() ??
              "${value['lat']}, ${value['lon']}";
          final lat = (value['lat'] is String
                      ? double.tryParse(value['lat'])
                      : value['lat'])
                  ?.toDouble() ??
              0.0;
          final lon = (value['lon'] is String
                      ? double.tryParse(value['lon'])
                      : value['lon'])
                  ?.toDouble() ??
              0.0;

          if (lat == 0.0 && lon == 0.0) {
            ShowToastDialog.showToast("Invalid location selected");
            return;
          }

          textController.text = displayName;
          locationLatLng.value = LocationLatLng(latitude: lat, longitude: lon);
          if (kDebugMode) {
            log('Selected location: $displayName, lat: $lat, lon: $lon');
          }
          await _handleSearchedLocation(value, controller);
        } else {
          if (kDebugMode) {
            log('No location selected from LocationPicker');
          }
        }
      } else {
        log("ELSE");
        log("API: ${Constant.mapAPIKey}");
        try {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlacePicker(
                apiKey: 'AIzaSyCCRRxa1OS0ezPBLP2fep93uEfW2oANKx4',
                onPlacePicked: (result) {
                  Get.back();
                  final textController = isSource
                      ? controller.sourceLocationController.value
                      : controller.destinationLocationController.value;
                  final locationLatLng = isSource
                      ? controller.sourceLocationLAtLng
                      : controller.destinationLocationLAtLng;

                  textController.text = result.formattedAddress.toString();
                  locationLatLng.value = LocationLatLng(
                    latitude: result.geometry!.location.lat,
                    longitude: result.geometry!.location.lng,
                  );
                  if (kDebugMode) {
                    log('Google Maps place picked: ${result.formattedAddress}, lat: ${result.geometry!.location.lat}, lon: ${result.geometry!.location.lng}');
                  }
                  // Only calculate amount if both locations are set
                  if (controller.sourceLocationLAtLng.value.latitude != null &&
                      controller.destinationLocationLAtLng.value.latitude !=
                          null) {
                    controller.calculateAmount();
                  }
                },
                initialPosition: const LatLng(-33.8567844, 151.213108),
                useCurrentLocation: true,
                selectInitialPosition: true,
                usePinPointingSearch: true,
                usePlaceDetailSearch: true,
                zoomGesturesEnabled: true,
                zoomControlsEnabled: true,
                resizeToAvoidBottomInset: false,
              ),
            ),
          );
        } catch (e, stackTrace) {
          if (kDebugMode) {
            log('Google Maps PlacePicker error: $e, stackTrace: $stackTrace');
          }
          ShowToastDialog.showToast(
              "Failed to select Google Maps location");
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        log('Error selecting location: $e, stackTrace: $stackTrace');
      }
      ShowToastDialog.showToast("Failed to select location");
    }
  }

  Widget _buildOfferRateField(BuildContext context, HomeController controller) {
    return Visibility(
      visible: controller.selectedType.value.offerRate == true,
      child: Column(
        children: [
          InkWell(
            onTap: () => PriceDialog(context, controller),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.gray,
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                border: Border.all(color: Colors.transparent, width: 1),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "PKR Offer your Fare",
                      style: GoogleFonts.poppins(
                        color: const Color.fromARGB(255, 110, 109, 109),
                        fontSize: 11,
                        fontWeight: FontWeight.normal,
                      ),
                      textAlign: TextAlign.start,
                    ),
                  ),
                  Icon(
                    Icons.mode_edit_outline_outlined,
                    color: AppColors.darkBackground,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 5),
        ],
      ),
    );
  }

  Widget _buildBookRideButton(BuildContext context, HomeController controller) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth * 0.01;
    final buttonWidth = screenWidth * 0.55;
    final selectorWidth = screenWidth * 0.2;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 7,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            flex: 1,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: selectorWidth,
                minWidth: selectorWidth * 0.9,
              ),
              child: InkWell(
                onTap: () => paymentMethodDialog(context, controller),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.all(Radius.circular(4)),
                    border: Border.all(color: Colors.transparent, width: 1),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
                  child: Column(
                    spacing: 6,
                    children: [
                      const SizedBox(width: 1),
                      SvgPicture.asset(
                        'assets/icons/ic_payment.svg',
                        width: 32 * MediaQuery.of(context).textScaleFactor,
                        color: AppColors.darkBackground,
                      ),
                      Text(
                        'Wallet',
                        style: TextStyle(
                            color: const Color.fromARGB(255, 149, 148,
                                148), // Use a color from your theme
                            fontSize: 8,
                            fontWeight: FontWeight
                                .bold // Set font size (in logical pixels)
                            ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 4,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: buttonWidth,
                minWidth: buttonWidth * 0.8,
              ),
              child: ButtonThem.buildButton(
                context,
                title: "Book Ride".tr,
                btnWidthRatio: Responsive.width(50, context),
                onPress: () async {
                  try {
                    final isPaymentNotCompleted =
                        await FireStoreUtils.paymentStatusCheck();
                    if (controller.selectedPaymentMethod.value.isEmpty) {
                      ShowToastDialog.showToast(
                          "Please select a payment method".tr);
                      return;
                    }
                    if (controller
                        .sourceLocationController.value.text.isEmpty) {
                      ShowToastDialog.showToast(
                          "Please select a source location".tr);
                      return;
                    }
                    if (controller
                        .destinationLocationController.value.text.isEmpty) {
                      ShowToastDialog.showToast(
                          "Please select a destination location".tr);
                      return;
                    }
                    if (double.parse(controller.distance.value) <= 2) {
                      ShowToastDialog.showToast(
                          "Please select a location more than 2 ${Constant.distanceType} away"
                              .tr);
                      return;
                    }
                    if (controller.selectedType.value.offerRate == true &&
                        controller.offerYourRateController.value.text.isEmpty) {
                      ShowToastDialog.showToast(
                          "Please enter an offer rate".tr);
                      return;
                    }
                    if (isPaymentNotCompleted) {
                      showAlertDialog(context);
                      return;
                    }

                    ShowToastDialog.showLoader("Please wait".tr);
                    final orderModel = OrderModel()
                      ..id = Constant.getUuid()
                      ..userId = FireStoreUtils.getCurrentUid()
                      ..sourceLocationName =
                          controller.sourceLocationController.value.text
                      ..destinationLocationName =
                          controller.destinationLocationController.value.text
                      ..sourceLocationLAtLng =
                          controller.sourceLocationLAtLng.value
                      ..destinationLocationLAtLng =
                          controller.destinationLocationLAtLng.value
                      ..distance = controller.distance.value
                      ..distanceType = Constant.distanceType
                      ..offerRate =
                          controller.selectedType.value.offerRate == true
                              ? controller.offerYourRateController.value.text
                              : controller.amount.value
                      ..serviceId = controller.selectedType.value.id
                      ..position = Positions(
                        geoPoint: Geoflutterfire()
                            .point(
                              latitude: controller
                                  .sourceLocationLAtLng.value.latitude!,
                              longitude: controller
                                  .sourceLocationLAtLng.value.longitude!,
                            )
                            .geoPoint,
                        geohash: Geoflutterfire()
                            .point(
                              latitude: controller
                                  .sourceLocationLAtLng.value.latitude!,
                              longitude: controller
                                  .sourceLocationLAtLng.value.longitude!,
                            )
                            .hash,
                      )
                      ..createdDate = firestore.Timestamp.now()
                      ..status = Constant.ridePlaced
                      ..paymentType = controller.selectedPaymentMethod.value
                      ..paymentStatus = false
                      ..service = controller.selectedType.value
                      ..adminCommission = controller.selectedType.value
                                  .adminCommission!.isEnabled ==
                              false
                          ? controller.selectedType.value.adminCommission!
                          : Constant.adminCommission
                   
                      ..taxList = Constant.taxList;

                    if (controller.selectedTakingRide.value.fullName !=
                        "Myself") {
                      orderModel.someOneElse =
                          controller.selectedTakingRide.value;
                    }

                    bool zoneFound = false;
                    for (final zone in controller.zoneList) {
                      if (Constant.isPointInPolygon(
                        LatLng(
                          double.parse(controller
                              .sourceLocationLAtLng.value.latitude
                              .toString()),
                          double.parse(controller
                              .sourceLocationLAtLng.value.longitude
                              .toString()),
                        ),
                        zone.area!,
                      )) {
                        controller.selectedZone.value = zone;
                        orderModel.zoneId = zone.id;
                        orderModel.zone = zone;
                        final eventData = await FireStoreUtils()
                            .sendOrderDataFuture(orderModel);
                        for (final driver in eventData) {
                          if (driver.fcmToken != null) {
                            final playLoad = <String, dynamic>{
                              "type": "city_order",
                              "orderId": orderModel.id,
                            };
                           
                          }
                        }
                        await FireStoreUtils.setOrder(orderModel);
                        ShowToastDialog.showToast(
                            "Ride placed successfully".tr);
                        controller.dashboardController.selectedDrawerIndex(2);
                        ShowToastDialog.closeLoader();
                        zoneFound = true;
                        break;
                      }
                    }

                    if (!zoneFound) {
                      ShowToastDialog.showToast(
                        "Services are currently unavailable at the selected location. Please contact the administrator for assistance."
                            .tr,
                        position: EasyLoadingToastPosition.center,
                      );
                      ShowToastDialog.closeLoader();
                    }
                  } catch (e, stackTrace) {
                    log('Error booking ride: $e, stackTrace: $stackTrace');
                    ShowToastDialog.showToast("Failed to book ride");
                    ShowToastDialog.closeLoader();
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            flex: 1,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: selectorWidth,
                minWidth: selectorWidth * 0.8,
              ),
              child: InkWell(
                onTap: () => someOneTakingDialog(context, controller),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.all(Radius.circular(4)),
                    border: Border.all(color: Colors.transparent, width: 0),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  child: Column(
                    spacing: 4,
                    children: [
                      Icon(
                        Icons.airline_seat_recline_extra_rounded,
                        color: AppColors.darkBackground,
                        size: 28 * MediaQuery.of(context).textScaleFactor,
                      ),
                      Text(
                        'My Self',
                        style: TextStyle(
                            color: const Color.fromARGB(255, 149, 148,
                                148), // Use a color from your theme
                            fontSize: 8,
                            fontWeight: FontWeight
                                .bold // Set font size (in logical pixels)
                            ),
                      )
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

void PriceDialog(BuildContext context, HomeController controller) {
  showModalBottomSheet(
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topRight: Radius.circular(15),
        topLeft: Radius.circular(15),
      ),
    ),
    context: context,
    isScrollControlled: true,
    isDismissible: true, // Allow dismissing by tapping outside
    enableDrag: true,
    builder: (context1) {
      
      return SafeArea(
        top: false,
        child: StatefulBuilder(builder: (context1, setState) {
          return Obx(
            () => Container(
              constraints: BoxConstraints(
                maxHeight: Responsive.height(90, context),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Offer Your Fare",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        "Choose a price to offer for your ride",
                        style: GoogleFonts.poppins(),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius:
                              const BorderRadius.all(Radius.circular(10)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 0,
                            vertical: 0,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                // Wrap TextField in Expanded
                                child:
                                    TextFieldThem.buildTextFiledWithPrefixIcon(
                                  context,
                                  hintText: "Enter your offer rate".tr,
                                  controller:
                                      controller.offerYourRateController.value,
                                  inputFormatters: <TextInputFormatter>[
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9*]')),
                                  ],
                                  prefix: Icon(
                                    Icons.attach_money,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ButtonThem.buildButton(
                        context,
                        title:
                            "Book for ${controller.selectedTakingRide.value.fullName}",
                        onPress: () async {
                          Get.back();
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      );
    },
  );
}

paymentMethodDialog(BuildContext context, HomeController controller) {
  return showModalBottomSheet(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
              topRight: Radius.circular(15), topLeft: Radius.circular(15))),
      context: context,
      isScrollControlled: true,
         isDismissible: true, // Allow dismissing by tapping outside
    enableDrag: true,
      builder: (context1) {
      

        return SafeArea(
          top: false,
          child: FractionallySizedBox(
            heightFactor: 0.9,
            child: StatefulBuilder(builder: (context1, setState) {
              return Obx(
                () => Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10.0, vertical: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            InkWell(
                                onTap: () {
                                  Get.back();
                                },
                                child: const Icon(Icons.arrow_back_ios)),
                            const Expanded(
                                child: Center(
                                    child: Text(
                              "Payment Method",
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black),
                            ))),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(children: [
                            Visibility(
                              visible: controller.paymentModel.value.cash?.enable ?? false,
                              child: Obx(
                                () => Column(
                                  children: [
                                    const SizedBox(
                                      height: 10,
                                    ),
                                    InkWell(
                                      onTap: () {
                                        controller.selectedPaymentMethod.value =
                                            controller
                                                .paymentModel.value.cash!.name
                                                .toString();
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: const BorderRadius.all(
                                              Radius.circular(10)),
                                          border: Border.all(
                                              color: controller
                                                          .selectedPaymentMethod
                                                          .value ==
                                                      controller.paymentModel
                                                          .value.cash!.name
                                                          .toString()
                                                  ?  Colors.transparent
                                                     
                                                  : Colors.transparent,
                                              width: 1),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          child: Row(
                                            children: [
                                              Container(
                                                height: 40,
                                                width: 40,
                                                decoration: const BoxDecoration(
                                                    color: Colors.transparent,
                                                    borderRadius:
                                                        BorderRadius.all(
                                                            Radius.circular(
                                                                5))),
                                                child: const Padding(
                                                  padding: EdgeInsets.all(8.0),
                                                  child: Icon(Icons.money,
                                                      color: Colors.black),
                                                ),
                                              ),
                                              const SizedBox(
                                                width: 10,
                                              ),
                                              Expanded(
                                                child: Text(
                                                  controller.paymentModel.value
                                                      .cash!.name
                                                      .toString(),
                                                  style: GoogleFonts.poppins(),
                                                ),
                                              ),
                                              Radio(
                                                value: controller.paymentModel
                                                    .value.cash!.name
                                                    .toString(),
                                                groupValue: controller
                                                    .selectedPaymentMethod
                                                    .value,
                                                activeColor: AppColors.primary,
                                                onChanged: (value) {
                                                  controller
                                                          .selectedPaymentMethod
                                                          .value =
                                                      controller.paymentModel
                                                          .value.cash!.name
                                                          .toString();
                                                },
                                              )
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Divider(
                              color: Colors.black12,
                              height: 1,
                              thickness: 1,
                              endIndent: 15,
                              indent: 15,
                            ),
                            Visibility(
                                 visible: controller.paymentModel.value.wallet?.enable ?? false,
                              child: Obx(
                                () => Column(
                                  children: [
                                    const SizedBox(
                                      height: 10,
                                    ),
                                    InkWell(
                                      onTap: () {
                                        controller.selectedPaymentMethod.value =
                                            controller
                                                .paymentModel.value.wallet!.name
                                                .toString();
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: const BorderRadius.all(
                                              Radius.circular(10)),
                                          border: Border.all(
                                              color: controller
                                                          .selectedPaymentMethod
                                                          .value ==
                                                      controller.paymentModel
                                                          .value.wallet!.name
                                                          .toString()
                                                  ?  Colors.transparent
                                                    
                                                  : Colors.transparent,
                                              width: 1),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 10),
                                          child: Row(
                                            children: [
                                              Container(
                                                height: 40,
                                                width: 40,
                                                decoration: const BoxDecoration(
                                                    color: Colors.transparent,
                                                    borderRadius:
                                                        BorderRadius.all(
                                                            Radius.circular(
                                                                5))),
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.all(8.0),
                                                  child: SvgPicture.asset(
                                                      'assets/icons/ic_wallet.svg',
                                                      color: AppColors.primary),
                                                ),
                                              ),
                                              const SizedBox(
                                                width: 10,
                                              ),
                                              Expanded(
                                                child: Text(
                                                  controller.paymentModel.value
                                                      .wallet!.name
                                                      .toString(),
                                                  style: GoogleFonts.poppins(),
                                                ),
                                              ),
                                              Radio(
                                                value: controller.paymentModel
                                                    .value.wallet!.name
                                                    .toString(),
                                                groupValue: controller
                                                    .selectedPaymentMethod
                                                    .value,
                                                activeColor: AppColors.primary,
                                                onChanged: (value) {
                                                  controller
                                                          .selectedPaymentMethod
                                                          .value =
                                                      controller.paymentModel
                                                          .value.wallet!.name
                                                          .toString();
                                                },
                                              )
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Divider(
                              color: Colors.black12,
                              height: 1,
                              thickness: 1,
                              endIndent: 15,
                              indent: 15,
                            ),
                            Visibility(
                              visible:
                                  controller.paymentModel.value.strip!.enable ==
                                      true,
                              child: Obx(
                                () => Column(
                                  children: [
                                    const SizedBox(
                                      height: 10,
                                    ),
                                    InkWell(
                                      onTap: () {
                                        controller.selectedPaymentMethod.value =
                                            controller
                                                .paymentModel.value.strip!.name
                                                .toString();
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: const BorderRadius.all(
                                              Radius.circular(10)),
                                          border: Border.all(
                                              color: controller
                                                          .selectedPaymentMethod
                                                          .value ==
                                                      controller.paymentModel
                                                          .value.strip!.name
                                                          .toString()
                                                  ?  Colors.transparent
                                                  : Colors.transparent,
                                              width: 1),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 10),
                                          child: Row(
                                            children: [
                                              Container(
                                                height: 40,
                                                width: 40,
                                                decoration: const BoxDecoration(
                                                    color: Colors.transparent,
                                                    borderRadius:
                                                        BorderRadius.all(
                                                            Radius.circular(
                                                                5))),
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.all(4.0),
                                                  child: Image.asset(
                                                      'assets/images/stripe.png'),
                                                ),
                                              ),
                                              const SizedBox(
                                                width: 10,
                                              ),
                                              Expanded(
                                                child: Text(
                                                  controller.paymentModel.value
                                                      .strip!.name
                                                      .toString(),
                                                  style: GoogleFonts.poppins(),
                                                ),
                                              ),
                                              Radio(
                                                value: controller.paymentModel
                                                    .value.strip!.name
                                                    .toString(),
                                                groupValue: controller
                                                    .selectedPaymentMethod
                                                    .value,
                                                activeColor: AppColors.primary,
                                                onChanged: (value) {
                                                  controller
                                                          .selectedPaymentMethod
                                                          .value =
                                                      controller.paymentModel
                                                          .value.strip!.name
                                                          .toString();
                                                },
                                              )
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ]),
                        ),
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      ButtonThem.buildButton(
                        context,
                        title: "Pay",
                        onPress: () async {
                          Get.back();
                        },
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        );
      });
}

someOneTakingDialog(BuildContext context, HomeController controller) {
  return showModalBottomSheet(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
              topRight: Radius.circular(15), topLeft: Radius.circular(15))),
      context: context,
      isScrollControlled: true,
        isDismissible: true, // Allow dismissing by tapping outside
    enableDrag: true,
      builder: (context1) {

        return StatefulBuilder(builder: (context1, setState) {
          return Obx(
            () => SafeArea(
              top: false,
              child: Container(
                constraints:
                    BoxConstraints(maxHeight: Responsive.height(90, context)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10.0, vertical: 10),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Someone else taking this ride?",
                          style: GoogleFonts.poppins(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          "Choose a contact and share a code to conform that ride.",
                          style: GoogleFonts.poppins(),
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                        InkWell(
                          onTap: () {
                            controller.selectedTakingRide.value = ContactModel(
                                fullName: "Myself", contactNumber: "");
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(10)),
                              border: Border.all(
                                  color: controller.selectedTakingRide.value
                                              .fullName ==
                                          "Myself"
                                      ?  AppColors.primary
                                      : AppColors.textFieldBorder,
                                  width: 1),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                              child: Row(
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child:
                                        Icon(Icons.person, color: Colors.black),
                                  ),
                                  const SizedBox(
                                    width: 10,
                                  ),
                                  Expanded(
                                    child: Text(
                                      "Myself",
                                      style: GoogleFonts.poppins(),
                                    ),
                                  ),
                                  Radio(
                                    value: "Myself",
                                    groupValue: controller
                                        .selectedTakingRide.value.fullName,
                                    activeColor:  AppColors.primary,
                                    onChanged: (value) {
                                      controller.selectedTakingRide.value =
                                          ContactModel(
                                              fullName: "Myself",
                                              contactNumber: "");
                                    },
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),
                        ListView.builder(
                          itemCount: controller.contactList.length,
                          shrinkWrap: true,
                          itemBuilder: (context, index) {
                            ContactModel contactModel =
                                controller.contactList[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: InkWell(
                                onTap: () {
                                  controller.selectedTakingRide.value =
                                      contactModel;
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: const BorderRadius.all(
                                        Radius.circular(10)),
                                    border: Border.all(
                                        color: controller.selectedTakingRide
                                                    .value.fullName ==
                                                contactModel.fullName
                                            ?   AppColors.primary
                                            : AppColors.textFieldBorder,
                                        width: 1),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 10),
                                    child: Row(
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Icon(Icons.person,
                                              color: Colors.black),
                                        ),
                                        const SizedBox(
                                          width: 10,
                                        ),
                                        Expanded(
                                          child: Text(
                                            contactModel.fullName.toString(),
                                            style: GoogleFonts.poppins(),
                                          ),
                                        ),
                                        Radio(
                                          value:
                                              contactModel.fullName.toString(),
                                          groupValue: controller
                                              .selectedTakingRide
                                              .value
                                              .fullName,
                                          activeColor: AppColors.primary,
                                          onChanged: (value) {
                                            controller.selectedTakingRide
                                                .value = contactModel;
                                          },
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(
                          height: 0,
                        ),
                        InkWell(
                          onTap: () async {
                            try {
                              // final FullContact contact = await FlutterContactPicker.pickFullContact();
                              // ContactModel contactModel = ContactModel();
                              // contactModel.fullName = "${contact.name!.firstName ?? ""} ${contact.name!.middleName ?? ""} ${contact.name!.lastName ?? ""}";
                              // contactModel.contactNumber = contact.phones[0].number;

                              // if (!controller.contactList.contains(contactModel)) {
                              //   controller.contactList.add(contactModel);
                              //   controller.setContact();
                              // }
                            } catch (e) {
                              rethrow;
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                            child: Row(
                              children: [
                                const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child:
                                      Icon(Icons.contacts, color: Colors.black),
                                ),
                                const SizedBox(
                                  width: 10,
                                ),
                                Expanded(
                                  child: Text(
                                    "Choose another contact",
                                    style: GoogleFonts.poppins(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                        ButtonThem.buildButton(
                          context,
                          title:
                              "Book for ${controller.selectedTakingRide.value.fullName}",
                          onPress: () async {
                            Get.back();
                          },
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        });
      });
}

ariPortDialog(BuildContext context, HomeController controller, bool isSource) {
  return showModalBottomSheet(
      backgroundColor: Theme.of(context).colorScheme.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
              topRight: Radius.circular(15), topLeft: Radius.circular(15))),
      context: context,
      isScrollControlled: true,
         isDismissible: true, // Allow dismissing by tapping outside
    enableDrag: true,
      builder: (context1) {

        return StatefulBuilder(builder: (context1, setState) {
          return Container(
            constraints:
                BoxConstraints(maxHeight: Responsive.height(90, context)),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Do you want to travel for AirPort?",
                      style: GoogleFonts.poppins(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      "Choose a single AirPort",
                      style: GoogleFonts.poppins(),
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    ListView.builder(
                      itemCount: Constant.airaPortList!.length,
                      shrinkWrap: true,
                      itemBuilder: (context, index) {
                        AriPortModel airPortModel =
                            Constant.airaPortList![index];
                        return Obx(
                          () => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: InkWell(
                              onTap: () {
                                controller.selectedAirPort.value = airPortModel;
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.all(
                                      Radius.circular(10)),
                                  border: Border.all(
                                      color:
                                          controller.selectedAirPort.value.id ==
                                                  airPortModel.id
                                              ?  AppColors.primary
                                              : AppColors.textFieldBorder,
                                      width: 1),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 10),
                                  child: Row(
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: Icon(Icons.airplanemode_active,
                                            color: Colors.black),
                                      ),
                                      const SizedBox(
                                        width: 10,
                                      ),
                                      Expanded(
                                        child: Text(
                                          airPortModel.airportName.toString(),
                                          style: GoogleFonts.poppins(),
                                        ),
                                      ),
                                      Radio(
                                        value: airPortModel.id.toString(),
                                        groupValue:
                                            controller.selectedAirPort.value.id,
                                        activeColor:  AppColors.primary,
                                        onChanged: (value) {
                                          controller.selectedAirPort.value =
                                              airPortModel;
                                        },
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    ButtonThem.buildButton(
                      context,
                      title: "Book",
                      onPress: () async {
                        if (controller.selectedAirPort.value.id != null) {
                          if (isSource) {
                            controller.sourceLocationController.value.text =
                                controller.selectedAirPort.value.airportName
                                    .toString();
                            controller.sourceLocationLAtLng.value =
                                LocationLatLng(
                                    latitude: double.parse(
                                        controller
                                            .selectedAirPort.value.airportLat
                                            .toString()),
                                    longitude: double.parse(controller
                                        .selectedAirPort.value.airportLng
                                        .toString()));
                            if (Constant.selectedMapType == 'osm') {
                              controller.calculateOsmAmount();
                            } else {
                              controller.calculateAmount();
                            }
                          } else {
                            controller
                                    .destinationLocationController.value.text =
                                controller.selectedAirPort.value.airportName
                                    .toString();
                            controller.destinationLocationLAtLng.value =
                                LocationLatLng(
                                    latitude: double.parse(controller
                                        .selectedAirPort.value.airportLat
                                        .toString()),
                                    longitude: double.parse(controller
                                        .selectedAirPort.value.airportLng
                                        .toString()));
                            if (Constant.selectedMapType == 'osm') {
                              controller.calculateOsmAmount();
                            } else {
                              controller.calculateAmount();
                            }
                          }
                          Get.back();
                        } else {
                          ShowToastDialog.showToast("Please select one airport",
                              position: EasyLoadingToastPosition.center);
                        }
                      },
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      });
}

showAlertDialog(BuildContext context) {
  // set up the button
  Widget okButton = TextButton(
    child: const Text("OK"),
    onPressed: () {
      Get.back();
    },
  );

  // set up the AlertDialog
  AlertDialog alert = AlertDialog(
    title: const Text("Warning"),
    content: const Text(
        "You are not able book new ride please complete previous ride payment"),
    actions: [
      okButton,
    ],
  );
  // show the dialog
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return alert;
    },
  );
}

// warningDailog() {
//   return Dialog(
//     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)), //this right here
//     child: SizedBox(
//       height: 300.0,
//       width: 300.0,
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: <Widget>[
//           const Padding(
//             padding: EdgeInsets.all(15.0),
//             child: Text(
//               'Warning!',
//               style: TextStyle(color: Colors.red),
//             ),
//           ),
//           const Padding(
//             padding: EdgeInsets.all(15.0),
//             child: Text(
//               'You are not able book new ride please complete previous ride payment',
//               style: TextStyle(color: Colors.red),
//             ),
//           ),
//           const Padding(padding: EdgeInsets.only(top: 50.0)),
//           TextButton(
//               onPressed: () {
//                 Get.back();
//               },
//               child: const Text(
//                 'Ok',
//                 style: TextStyle(color: Colors.purple, fontSize: 18.0),
//               ))
//         ],
//       ),
//     ),
//   );
// }
