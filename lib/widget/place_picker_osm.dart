import 'dart:developer';

import 'package:customer/constant/constant.dart';
import 'package:customer/themes/app_colors.dart';
import 'package:customer/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
// import 'package:flutter_dotenv/flutter_dotenv.dart';

class LocationPicker extends StatefulWidget {
  const LocationPicker({super.key});

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  LatLng? selectedLocation;
  GoogleMapController? mapController;
  Set<Marker> _markers = {};
  String? placeName;
  TextEditingController textController = TextEditingController();
  bool isMapLoading = true;
  CameraPosition initialCameraPosition = const CameraPosition(
    target: LatLng(0, 0),
    zoom: 14,
  );

  @override
  void initState() {
    super.initState();
    _setUserLocation();
  }

  Future<void> _setUserLocation() async {
    try {
      final locationData = await Utils.getCurrentLocation();
      setState(() {
        selectedLocation = LatLng(
          locationData.latitude,
          locationData.longitude,
        );
        initialCameraPosition = CameraPosition(
          target: selectedLocation!,
          zoom: 14,
        );
        _addMarker(selectedLocation!);
      });
    } catch (e) {
      print("Error getting location: $e");
      // Handle error (e.g., show a snackbar to the user)
      Get.snackbar(
        'Location Error',
        'Unable to get current location. Please check your permissions.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String address =
            "${place.street}, ${place.subLocality}, ${place.locality}, ${place.administrativeArea}, ${place.country}";

        // Clean up the address by removing empty components
        address = address
            .split(', ')
            .where((element) => element.isNotEmpty && element != "null")
            .join(', ');

        setState(() {
          placeName = address;
          textController.text = address;
        });
      } else {
        setState(() {
          placeName = "${position.latitude}, ${position.longitude}";
          textController.text = placeName!;
        });
      }
    } catch (e) {
      print("Error getting address: $e");
      setState(() {
        placeName = "${position.latitude}, ${position.longitude}";
        textController.text = placeName!;
      });
    }
  }

  void _addMarker(LatLng position) async {
    setState(() {
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('selected_location'),
          position: position,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
      selectedLocation = position;
    });

    await _getAddressFromLatLng(position);
    if (mapController != null) {
      mapController!.animateCamera(CameraUpdate.newLatLng(position));
    }
  }

  @override
  void dispose() {
    mapController?.dispose();
    textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: initialCameraPosition,
            mapType: MapType.normal,
            markers: _markers,
            onMapCreated: (GoogleMapController controller) {
              mapController = controller;
              setState(() {
                isMapLoading = false;
              });
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onTap: (LatLng position) {
              _addMarker(position);
            },
          ),
          if (isMapLoading) const Center(child: CircularProgressIndicator()),
          if (placeName != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.only(bottom: 100, left: 40, right: 40),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        placeName ?? '',
                        style:
                            const TextStyle(fontSize: 14, color: Colors.black),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        // Return a place-like object
                        Get.back(result: {
                          'displayName': placeName,
                          'lat': selectedLocation!.latitude,
                          'lon': selectedLocation!.longitude,
                        });
                      },
                      icon: const Icon(
                        Icons.check_circle,
                        size: 40,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Container(
            margin: const EdgeInsets.only(
              top: 50,
              left: 20,
            ),
            child: FloatingActionButton(
              onPressed: () => Get.back(),
              mini: true,
              backgroundColor: Colors.white,
              child: Icon(
                Icons.arrow_back,
                color: AppColors.primary,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 110, left: 10, right: 10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0),
                child: InkWell(
                  onTap: () async {
                    // Navigate to a search place screen
                    final result = await showSearch(
                      context: context,
                      delegate: LocationSearchDelegate(
                        onSelect: (LatLng position, String address) {
                          textController.text = address;
                          _addMarker(position);
                        },
                      ),
                    );
                    if (result != null) {
                      print("Search result: $result");
                    }
                  },
                  child: buildTextField(
                    title: "Search Address".tr,
                    textController: textController,
                  ),
                ),
              ),
            ),
          ),
          // Positioned(
          //   bottom: 30,
          //   right: 20,
          //   child: FloatingActionButton(
          //     onPressed: _setUserLocation,
          //     backgroundColor: Colors.white,
          //     child: Icon(
          //       Icons.my_location,
          //       color: themeChange.getThem()
          //           ? AppColors.darkModePrimary
          //           : AppColors.primary,
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget buildTextField(
      {required String title, required TextEditingController textController}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10.0),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: textController,
          textInputAction: TextInputAction.done,
          style: const TextStyle(
              color: Color.fromARGB(255, 51, 50, 50), fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: IconButton(
              icon: const Icon(Icons.location_on, color: Colors.black),
              onPressed: () {},
            ),
            fillColor: Colors.white,
            filled: true,
            hintText: title,
            hintStyle: const TextStyle(color: Color.fromARGB(255, 53, 52, 52)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20.0),
              borderSide: BorderSide.none, // Transparent border
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20.0),
              borderSide: BorderSide.none, // Transparent border
            ),
            enabled: false,
          ),
        ),
      ),
    );
  }
}

// Implementation of location search with Google Places API
class LocationSearchDelegate extends SearchDelegate<String> {
  final Function(LatLng position, String address) onSelect;
  final String apiKey = 'AIzaSyCCRRxa1OS0ezPBLP2fep93uEfW2oANKx4';
  List<PlaceSearchResult> searchResults = [];
  bool isLoading = false;
  bool hasSearched = false; // Add a flag to track if search was performed

  LocationSearchDelegate({required this.onSelect});

  Future<void> searchPlaces(String query) async {
    if (query.isEmpty || apiKey.isEmpty) return;

    setState(() {
      isLoading = false; // Set to true when starting the search
      hasSearched = true; // Mark that a search was performed
    });

    try {
      final response = await http
          .get(
           Uri.parse(
  'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$query&key=$apiKey',
),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final predictions = data['predictions'] as List;
          setState(() {
            searchResults = predictions
                .map((prediction) => PlaceSearchResult(
                      placeId: prediction['place_id'],
                      description: prediction['description'],
                    ))
                .toList();
            log('Search result: ${searchResults.length} items found');
            for (var result in searchResults) {
              log('Place: ${result.description}');
            }
            isLoading = false;
          });
        } else {
          log('Places API error: ${data['status']} - ${data['error_message'] ?? 'No error message'}');
          setState(() {
            isLoading = false;
          });
        }
      } else {
        log('HTTP error: ${response.statusCode} - ${response.body}');
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      log('Exception: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> getPlaceDetails(String placeId) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=geometry,formatted_address&key=$apiKey',
        ),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final result = data['result'];
          final location = result['geometry']['location'];
          final lat = location['lat'];
          final lng = location['lng'];
          final address = result['formatted_address'];

          log('Selected place: $address at $lat,$lng');
          onSelect(LatLng(lat, lng), address);
        } else {
          log('Place Details API error: ${data['status']} - ${data['error_message'] ?? 'No error message'}');
        }
      } else {
        log('HTTP error in getPlaceDetails: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      log('Exception: $e');
    }
  }

  void setState(Function() fn) {
    fn();
    // Trigger a rebuild
    query = query;
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
          searchResults.clear();
          hasSearched = false;
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return buildSuggestions(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    log("my query: $query");
    
    // Only trigger search when query changes and is not empty
    if (query.isNotEmpty && !isLoading) {
      searchPlaces(query);
    }

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (query.isEmpty || (!hasSearched && searchResults.isEmpty)) {
      // Show saved locations or recent searches
      final suggestions = ['Current Location', 'Home', 'Work'];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Saved Places',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: suggestions.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: const Icon(Icons.star),
                  title: Text(suggestions[index]),
                  onTap: () {
                    if (suggestions[index] == 'Current Location') {
                      // Just close and let the main screen handle current location
                      close(context, 'CURRENT_LOCATION');
                    } else {
                      // In a real app, you'd look up the coordinates for saved places
                      // For demonstration, using dummy locations
                      var location = suggestions[index] == 'Home'
                          ? const LatLng(40.7128, -74.0060) // New York
                          : const LatLng(34.0522, -118.2437); // Los Angeles

                      onSelect(location, suggestions[index]);
                      close(context, suggestions[index]);
                    }
                  },
                );
              },
            ),
          ),
        ],
      );
    }

    // Show search results
    log("Displaying ${searchResults.length} search results");
    return ListView.builder(
      itemCount: searchResults.length,
      itemBuilder: (context, index) {
        final result = searchResults[index];
        log("Result ${index+1}: ${result.description}");
        return ListTile(
          leading: const Icon(Icons.location_on),
          title: Text(result.description),
          onTap: () async {
            log("Selected place ID: ${result.placeId}");
            await getPlaceDetails(result.placeId);
            close(context, result.description);
          },
        );
      },
    );
  }
}


  
  
class PlaceSearchResult {
  final String placeId;
  final String description;

  PlaceSearchResult({
    required this.placeId,
    required this.description,
  });
}
