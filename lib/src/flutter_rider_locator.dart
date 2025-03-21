import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart' show ByteData, Uint8List, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:logger/logger.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: StoreFinder());
  }
}

class StoreFinder extends StatefulWidget {
  @override
  // ignore: library_private_types_in_public_api
  _StoreFinderState createState() => _StoreFinderState();
}

class _StoreFinderState extends State<StoreFinder> {
  bool isApiKeyValid = false;
  var logger = Logger();
  static const platform = MethodChannel('com.example.geo/navigation');

  Position? currentPosition;
  GoogleMapController? mapController;
  bool isRiderSelected = false;

  //เก็บค่า
  List<Map<String, dynamic>> nearbyStores = [];
  List<Map<String, dynamic>> nearbyDrivers = [];
  final List<Map<String, dynamic>> _selectedOrderStores = [];
  final List<Map<String, dynamic>> _newOrders = [];

  int _notificationCount = 0;

  Set<Marker> markers = {};
  Set<Circle> circles = {};
  Set<Polyline> polylines = {};

  // เลือก store, driver
  Map<String, dynamic>? selectedStore;
  Map<String, dynamic>? selectedDriver;
  Map<String, dynamic>? selectedRider;

  // Custom marker icons
  BitmapDescriptor? storeMarkerIcon;
  BitmapDescriptor? driverMarkerIcon;
  BitmapDescriptor? customerMarkerIcon;
  BitmapDescriptor? dotMarker;

  //สุ่มร้านในระยะ 10 กม.
  List<Map<String, dynamic>> initialStores = [];
  //สุ่มลูกค้าในระยะ 10 กม.
  List<Map<String, dynamic>> initialCustomer = [];

  @override
  void initState() {
    super.initState();
    _checkApiKey();
    _setCustomMarkerIcons();
    _loadMarkers();
    _getCurrentLocation();
    _generateRandomStores();
  }

  void _assignOrderToCustomer() {
    if (initialCustomer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("ไม่มีลูกค้าในระบบ")));
      return;
    }
    if (initialStores.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("ไม่มีร้านในระบบ")));
      return;
    }

    // เลือกร้านจากที่สุ่ม
    Map<String, dynamic> selectedStore = initialStores[Random().nextInt(initialStores.length)];

    showDialog(
      context: context,
      builder: (context) {
        Map<String, dynamic>? selectedCustomer;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text("Select a customer"),
              content: SingleChildScrollView(
                child: Column(
                  children:
                      initialCustomer.map((customer) {
                        return RadioListTile<Map<String, dynamic>>(
                          title: Text(customer["name"]),
                          subtitle: Text("ที่อยู่: ${customer["address"]}"),
                          value: customer,
                          groupValue: selectedCustomer,
                          onChanged: (value) {
                            setStateDialog(() {
                              selectedCustomer = value;
                            });
                          },
                        );
                      }).toList(),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: Text("Cancel")),
                TextButton(
                  onPressed: () {
                    if (selectedCustomer == null) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("กรุณาเลือกลูกค้า")));
                    } else {
                      // สร้างคำสั่ง mock สำหรับร้านที่เลือก
                      double distanceFromRider =
                          0.0; // คำนวณระยะทางจากไรเดอร์ไปยังร้านที่เลือก (หากมีการเลือกไรเดอร์แล้ว)
                      if (selectedRider != null) {
                        distanceFromRider = _calculateDistance(
                          selectedRider!['latitude'],
                          selectedRider!['longitude'],
                          selectedStore['latitude'],
                          selectedStore['longitude'],
                        );
                      }

                      Map<String, dynamic> newOrder = {
                        "orderId": Random().nextInt(1000),
                        "storeName": selectedStore["name"],
                        "storeAddress": selectedStore["storeAddress"],
                        "storeLatitude": selectedStore["latitude"],
                        "storeLongitude": selectedStore["longitude"],
                        "distanceFromRider": distanceFromRider,
                        "accepted": false,
                        "items": [
                          {"name": "ข้าวมันไก่", "quantity": 1},
                          {"name": "ข้าวขาหมู", "quantity": 1},
                        ],
                        "customerName": selectedCustomer!["name"],
                        "customerAddress": selectedCustomer!["address"],
                        "customerLatitude": selectedCustomer!["latitude"],
                        "customerLongitude": selectedCustomer!["longitude"],
                      };

                      // เพิ่มคำสั่งไปที่ลูกค้า
                      if (selectedCustomer!["orders"] == null) {
                        selectedCustomer!["orders"] = [];
                      }
                      selectedCustomer!["orders"].add(newOrder);

                      setState(() {
                        _newOrders.add(newOrder);
                        _notificationCount++;
                      });

                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text("Order ได้ถูกเพิ่มให้กับ ${selectedCustomer!['name']}")));
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text("Confirm"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _generateRandomStores() {
    if (currentPosition == null) return;

    final random = Random();
    final int numberOfStores = random.nextInt(9) + 2; // Gen btw 2 to 10 stores
    final List<Map<String, dynamic>> generatedStores = [];
    const double maxDistance = 10.0;

    for (int i = 0; i < numberOfStores; i++) {
      final double distanceKm = random.nextDouble() * maxDistance;
      final double angle = random.nextDouble() * 2 * pi;

      // ค่าสำหรับคำนวณระยะทางโดยประมาณ
      const double earthRadiusKm = 6371.0;

      final double deltaLat = (distanceKm / earthRadiusKm) * (180 / pi);
      final double deltaLng = deltaLat / cos(currentPosition!.latitude * pi / 180);

      final double newLat = currentPosition!.latitude + deltaLat * sin(angle);
      final double newLng = currentPosition!.longitude + deltaLng * cos(angle);

      generatedStores.add({
        "name": "Store ${String.fromCharCode(65 + i)}",
        "latitude": newLat,
        "longitude": newLng,
        "storeAddress": "Lat: ${newLat.toStringAsFixed(5)}, Lng: ${newLng.toStringAsFixed(5)}",
        "active": true,
        "isOpen": true,
      });
    }

    setState(() {
      initialStores.clear();
      initialStores.addAll(generatedStores);
    });
  }

  //Customer
  void _generateRandomCustomers() {
    if (currentPosition == null) return;

    final random = Random();
    final int numberOfStores = random.nextInt(9) + 1; // Gen btw 1 to 10 stores
    final List<Map<String, dynamic>> generatedCustomers = [];
    const double maxDistance = 10.0;

    for (int i = 0; i < numberOfStores; i++) {
      final double distanceKm = random.nextDouble() * maxDistance;
      final double angle = random.nextDouble() * 2 * pi;

      // คำนวณการเปลี่ยนแปลงตำแหน่ง
      const double earthRadiusKm = 6371.0;
      final double deltaLat = (distanceKm / earthRadiusKm) * (180 / pi);
      final double deltaLng = deltaLat / cos(currentPosition!.latitude * pi / 180);

      final double newLat = currentPosition!.latitude + deltaLat * sin(angle);
      final double newLng = currentPosition!.longitude + deltaLng * cos(angle);

      generatedCustomers.add({
        "name": "Customer ${String.fromCharCode(65 + i)}",
        "latitude": newLat,
        "longitude": newLng,
        "address": "Lat: ${newLat.toStringAsFixed(5)}, Lng: ${newLng.toStringAsFixed(5)}",
        "active": true,
      });
    }

    setState(() {
      initialCustomer.clear();
      initialCustomer.addAll(generatedCustomers);
    });
  }

  // void _addNewOrder(Map<String, dynamic> order) {
  //   setState(() {
  //     _newOrders.add(order);
  //     _notificationCount++;
  //   });
  // }

  void _adjustCameraToPolyline(List<LatLng> polylineCoordinates) {
    if (polylineCoordinates.isEmpty) return;

    double minLat = polylineCoordinates.first.latitude;
    double minLng = polylineCoordinates.first.longitude;
    double maxLat = polylineCoordinates.first.latitude;
    double maxLng = polylineCoordinates.first.longitude;

    for (var point in polylineCoordinates) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    LatLngBounds bounds = LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng));

    mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }

  // MARKER AND LOCATION HANDLING
  Future<void> _loadMarkers() async {
    dotMarker = await _createDotMarker();
    setState(() {});
  }

  double calculateStoreToRiderDistance(Map<String, dynamic> store, Map<String, dynamic> rider) {
    return _calculateDistance(store['latitude'], store['longitude'], rider['latitude'], rider['longitude']);
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      currentPosition = position;
      _addCircle();
      _addStore();
      _generateRandomStores();
      _generateRandomCustomers();
    });
    _addMarkers(initialCustomer, customerMarkerIcon);
  }

  // Custom Marker Icons
  Future<void> _setCustomMarkerIcons() async {
    storeMarkerIcon = await BitmapDescriptor.asset(
      ImageConfiguration(size: Size(48, 48)),
      'assets/images/restaurant.png',
    );
    driverMarkerIcon = await BitmapDescriptor.asset(ImageConfiguration(size: Size(48, 48)), 'assets/images/driver.png');
    customerMarkerIcon = await BitmapDescriptor.asset(ImageConfiguration(size: Size(48, 48)), 'assets/images/here.png');
  }

  // MARKER AND LOCATION ADDITIONAL FUNCTIONALITY
  Future<BitmapDescriptor> _createDotMarker() async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 24.0;
    final Paint fillPaint = Paint()..color = const ui.Color(0xFF1783FF);
    final Paint strokePaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;

    final double center = size / 2;
    canvas.drawCircle(Offset(center, center), 8, fillPaint);
    canvas.drawCircle(Offset(center, center), 8, strokePaint);

    final ui.Image image = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List bytes = byteData!.buffer.asUint8List();

    // return BitmapDescriptor.fromBytes(bytes);
    return BitmapDescriptor.bytes(bytes);
  }

  // Add markers to map
  void _addMarkers(List<Map<String, dynamic>> items, BitmapDescriptor? icon) {
    for (var item in items) {
      // คำนวณระยะทางจาก ตำแหน่งปัจจุบันของลูกค้า -> ตำแหน่งของร้าน
      double distance = _calculateDistance(
        currentPosition!.latitude,
        currentPosition!.longitude,
        item["latitude"],
        item["longitude"],
      );

      markers.add(
        Marker(
          markerId: MarkerId(item["name"]),
          position: LatLng(item["latitude"], item["longitude"]),
          infoWindow: InfoWindow(title: item["name"], snippet: 'ระยะทาง: : ${distance.toStringAsFixed(2)} km'),
          icon: icon ?? BitmapDescriptor.defaultMarker,
        ),
      );
    }
    setState(() {});
  }

  // FIND NEARBY STORES AND DRIVERS
  void _findNearbyStores() {
    if (currentPosition == null) return;
    List<Map<String, dynamic>> results = [];
    for (var store in initialStores) {
      if (store["active"] && store["isOpen"]) {
        double distance = _calculateDistance(
          currentPosition!.latitude,
          currentPosition!.longitude,
          store["latitude"],
          store["longitude"],
        );
        if (distance <= 10) {
          results.add({...store, "distance": distance});
        }
      }
    }
    setState(() {
      nearbyStores = results;
      _addMarkers(nearbyStores, storeMarkerIcon);
    });
  }

  // Utility functions
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371;
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);
    double a =
        sin(dLat / 2) * sin(dLat / 2) + cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * pi / 180;
  }

  void _addCircle() {
    circles.clear();
    if (currentPosition != null) {
      if (kIsWeb) {
        circles.add(
          Circle(
            circleId: CircleId('currentLocationCircle'),
            center: LatLng(currentPosition!.latitude, currentPosition!.longitude),
            radius: 10000,
            fillColor: Colors.blue.withValues(alpha: 0.1),
            strokeColor: Colors.blue.withValues(alpha: 0.5),
            strokeWidth: 2,
          ),
        );

        // เพิ่มวงกลมเล็กสีแดงตรงกลาง
        if (dotMarker != null && currentPosition != null) {
          markers.add(
            Marker(
              markerId: MarkerId('currentLocationDot'),
              position: LatLng(currentPosition!.latitude, currentPosition!.longitude),
              icon: dotMarker!,
            ),
          );
        }
      } else {
        circles.add(
          Circle(
            circleId: CircleId('currentLocationCircle'),
            center: LatLng(currentPosition!.latitude, currentPosition!.longitude),
            radius: 10000,
            fillColor: Colors.blue.withValues(alpha: 0.1),
            strokeColor: Colors.blue.withValues(alpha: 0.5),
            strokeWidth: 2,
          ),
        );
      }
    }
  }

  void _addStore() async {
    await _setCustomMarkerIcons();
    setState(() {
      _findNearbyStores();
    });
  }

  //API
  void _assignOrderToRiderConfirmed(Map<String, dynamic> rider, List<Map<String, dynamic>> orders) {
    // ดึงเฉพาะ order ที่ถูกรับ (accepted == true) จาก _newOrders
    List<Map<String, dynamic>> acceptedOrders = _newOrders.where((order) => order["accepted"] == true).toList();

    if (acceptedOrders.isEmpty) {
      logger.e("❌ No accepted orders, skipping polyline drawing.");
      return;
    }

    // check ลูกค้าทุก order ว่าเป็นคนเดียวกันไหม
    Set<String> customerNames = acceptedOrders.map((order) => order["customerName"] as String).toSet();
    if (customerNames.length > 1) {
      // if order จากลูกค้าหลายคน - แสดงแจ้งเตือน + block ประมวลผลเพิ่มเติม
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("ไม่สามารถรับออเดอร์จากลูกค้าหลายคนพร้อมกันได้")));
      return;
    }

    // สร้างพิกัดร้าน
    Set<LatLng> storeWaypoints =
        acceptedOrders.map((order) {
          return LatLng(order['storeLatitude'], order['storeLongitude']);
        }).toSet();

    // สร้างพิกัดลูกค้า
    Set<LatLng> customerWaypoints =
        acceptedOrders.map((order) {
          return LatLng(order['customerLatitude'], order['customerLongitude']);
        }).toSet();

    // รวม waypoints จากร้าน + ลูกค้า
    List<LatLng> waypoints = [...storeWaypoints, ...customerWaypoints];

    // ตำแหน่งเริ่มต้นของไรเดอร์
    LatLng riderLocation = LatLng(rider['latitude'], rider['longitude']);

    // ปลายทางเป็นลูกค้าคนเดียว (เนื่องจากมีเพียงลูกค้าคนเดียว)
    LatLng destination = customerWaypoints.first;

    // สร้าง polyline จาก waypoints ที่รวมแล้ว
    _getRouteAndDrawWithWaypoints(riderLocation, destination, waypoints);

    logger.d("✅ Polyline updated with orders from a single customer!");

    setState(() {
      selectedRider = rider;
    });
  }

  // ฟังก์ชันตรวจสอบ API Key
  Future<void> _checkApiKey() async {
    String apiKey = await _getApiKey();
    setState(() {
      isApiKeyValid = apiKey.isNotEmpty && apiKey != "YOUR_GOOGLE_MAPS_API_KEY";
    });
  }

  // ดึงค่า API Key จาก AndroidManifest.xml
  Future<String> _getApiKey() async {
    try {
      final String apiKey = await platform.invokeMethod('getApiKey');
      return apiKey;
    } on PlatformException catch (e) {
      logger.e("Failed to get API Key: '${e.message}'.");
      return "";
    }
  }

  //-->กลับมาใช้แบบเดิม
  Future<void> _getRouteAndDrawWithWaypoints(LatLng start, LatLng end, List<LatLng> waypoints) async {
    String apiKey = await _getApiKey(); // ดึง API Key

    // logger.e("🔑 API Key: ${apiKey ?? 'NULL'}");
    if (apiKey.trim().isEmpty || apiKey == "YOUR_GOOGLE_MAPS_API_KEY") {
      _showApiKeyDialog(
        "กรุณาใส่ API Key ที่ถูกต้องใน 'AndroidManifest.xml' แล้วรัน 'flutter clean' และ 'flutter run' อีกครั้ง",
      );
      return;
    }

    String waypointsString = waypoints.map((point) => '${point.latitude},${point.longitude}').join('|');
    String url =
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${start.latitude},${start.longitude}'
        '&destination=${end.latitude},${end.longitude}';
    if (waypoints.isNotEmpty) {
      url += '&waypoints=optimize:true|$waypointsString';
    }
    url += '&key=$apiKey';

    // Debug: พิมพ์ URL เพื่อเช็คข้อมูล
    logger.i("Directions API URL: $url");

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        logger.i("Directions API response: ${data['status']}");
        if (data['status'] == 'OK') {
          var route = data['routes'][0];
          String polyline = route['overview_polyline']['points'];
          List<PointLatLng> result = PolylinePoints().decodePolyline(polyline);
          List<LatLng> polylineCoordinates = result.map((point) => LatLng(point.latitude, point.longitude)).toList();

          setState(() {
            polylines.clear();
            polylines.add(
              Polyline(polylineId: PolylineId('route'), points: polylineCoordinates, color: Colors.blue, width: 6),
            );
          });

          _adjustCameraToPolyline(polylineCoordinates);
        } else {
          logger.e('Directions API error: ${data['status']}');
        }
      } else {
        logger.e('Request failed with status: ${response.statusCode}');
      }
    } catch (e) {
      logger.e('Error fetching directions: $e');
    }
  }

  // void _addCompleteRoute(List<LatLng> routePoints) {
  //   final PolylineId polylineId = PolylineId('completeRoute');

  //   final Polyline polyline = Polyline(
  //     polylineId: polylineId,
  //     points: routePoints, // ใช้เส้นทางที่รวมไรเดอร์, ร้าน, ตำแหน่งลูกค้า
  //     color: Colors.blue,
  //     width: 5,
  //   );

  //   setState(() {
  //     polylines.add(polyline); // เพิ่ม polyline ใหม่ลงใน set
  //   });
  // }

  // Final UI build
  @override
  Widget build(BuildContext context) {
    // bool hasAcceptedOrder = _newOrders.any((order) => order["accepted"] == true);
    return Scaffold(
      appBar: AppBar(
        title: Text("Find Nearby Stores"),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: Icon(Icons.notifications, color: const ui.Color.fromARGB(255, 255, 190, 51)),
                onPressed: _showOrderNotifications,
              ),
              if (_notificationCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                    constraints: BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$_notificationCount',
                      style: TextStyle(color: const ui.Color.fromARGB(255, 255, 255, 255), fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),

      body:
          currentPosition == null
              ? Center(child: CircularProgressIndicator())
              : Stack(
                children: [
                  GoogleMap(
                    onMapCreated: (GoogleMapController controller) {
                      mapController = controller;
                    },
                    initialCameraPosition: CameraPosition(
                      target: LatLng(currentPosition!.latitude, currentPosition!.longitude),
                      zoom: 12,
                    ),
                    markers: markers,
                    circles: circles,
                    polylines: polylines,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    compassEnabled: false,
                    trafficEnabled: false,
                  ),
                  Positioned(
                    bottom: 150,
                    right: 10,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // My Location
                        FloatingActionButton(
                          onPressed: _goToCurrentLocation,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.my_location, color: Colors.black),
                        ),
                        SizedBox(height: 10),
                        FloatingActionButton(
                          onPressed: _assignOrderToCustomer,
                          backgroundColor: Colors.green,
                          child: Icon(Icons.person_add, color: Colors.white),
                        ),
                        Visibility(
                          // visible: _newOrders.any((order) => order["accepted"] == true),
                          visible: _newOrders.any((order) => order["accepted"] == true) && isApiKeyValid,
                          child: Column(
                            children: [
                              SizedBox(height: 10),
                              FloatingActionButton(
                                onPressed: () async {
                                  if (selectedRider != null && currentPosition != null) {
                                    LatLng riderLocation = LatLng(
                                      selectedRider!['latitude'],
                                      selectedRider!['longitude'],
                                    );
                                    // ดึงเฉพาะ order ที่ถูกรับ (accepted == true) จาก _newOrders
                                    List<Map<String, dynamic>> acceptedOrders =
                                        _newOrders.where((order) => order["accepted"] == true).toList();

                                    // ตรวจสอบว่า acceptedOrders มีข้อมูลหรือไม่
                                    if (acceptedOrders.isNotEmpty) {
                                    } else {
                                      logger.e("❌ ไม่มี order ที่ถูก accept");
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(SnackBar(content: Text("ไม่มี order ที่ถูก accept")));
                                    }

                                    // ใช้ order ที่รับแล้วตัวแรกเป็นปลายทางลูกค้า
                                    LatLng customerLocation = LatLng(
                                      acceptedOrders.first['customerLatitude'],
                                      acceptedOrders.first['customerLongitude'],
                                    );

                                    // ดึงพิกัดร้านที่เป็น waypoint
                                    List<LatLng> storeWaypoints =
                                        acceptedOrders.map((order) {
                                          return LatLng(order['storeLatitude'], order['storeLongitude']);
                                        }).toList();

                                    // ตรวจสอบว่า waypoints มีค่าหรือไม่
                                    String waypointsParam =
                                        storeWaypoints.isNotEmpty
                                            ? storeWaypoints
                                                .map((point) => '${point.latitude},${point.longitude}')
                                                .join('/')
                                            : "";

                                    // สร้าง URL เปิด Google Maps App
                                    final googleMapsUrl =
                                        'https://www.google.com/maps/dir/${riderLocation.latitude},${riderLocation.longitude}/'
                                        '${waypointsParam.isNotEmpty ? '$waypointsParam/' : ''}'
                                        '${customerLocation.latitude},${customerLocation.longitude}/'
                                        '?travelmode=driving';

                                    logger.i("🔗 Google Maps URL: $googleMapsUrl");
                                    logger.i(
                                      "✅ Rider Location: ${selectedRider?['latitude']}, ${selectedRider?['longitude']}",
                                    );
                                    logger.i(
                                      "✅ Customer Destination: ${customerLocation.latitude}, ${customerLocation.longitude}",
                                    );
                                    logger.i(
                                      "✅ Store Waypoints: ${storeWaypoints.map((w) => '${w.latitude},${w.longitude}').toList()}",
                                    );

                                    if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
                                      await launchUrl(Uri.parse(googleMapsUrl), mode: LaunchMode.externalApplication);
                                    } else {
                                      throw 'Could not open Google Maps.';
                                    }
                                  }
                                },
                                backgroundColor: Colors.blue,
                                child: Icon(Icons.navigation, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
    );
  }

  void _goToCurrentLocation() {
    if (currentPosition != null && mapController != null) {
      mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(currentPosition!.latitude, currentPosition!.longitude), zoom: 14),
        ),
      );
    }
  }

  void _showOrderNotifications() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text("New Order Notifications"),
              content: SingleChildScrollView(
                child: Column(
                  children:
                      _newOrders.map((order) {
                        return Card(
                          color: order["accepted"] == true ? Colors.green[100] : null,
                          child: Column(
                            children: [
                              ListTile(
                                title: Text("Order ${order['orderId']} : ${order['storeName']}"),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("ที่อยู่ร้าน: ${order['storeAddress']}"),
                                    if (order.containsKey("distanceFromRider"))
                                      Text("ระยะทางร้าน-ไรเดอร์: ${order['distanceFromRider'].toStringAsFixed(2)} km"),
                                    Text("ลูกค้า: ${order['customerName']}"),
                                    Text("ที่อยู่ลูกค้า: ${order['customerAddress']}"),
                                  ],
                                ),
                              ),
                              order["accepted"] == true
                                  ? Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.check_circle, color: Colors.green),
                                        SizedBox(width: 4),
                                        Text(
                                          "รับงานนี้แล้ว",
                                          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  )
                                  : Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.check, color: Colors.green),
                                        onPressed: () {
                                          if (!isApiKeyValid) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(SnackBar(content: Text("กรุณาใส่ API Key ที่ถูกต้อง")));
                                            return;
                                          }

                                          if (currentPosition != null) {
                                            // ตรวจสอบว่า order ที่จะรับมีลูกค้าตรงกันกับ order ที่ accept อยู่แล้วหรือไม่
                                            List<Map<String, dynamic>> acceptedOrders =
                                                _newOrders.where((o) => o["accepted"] == true).toList();
                                            // ถ้าไม่มี order ที่ accept อยู่ ให้สามารถรับ order นี้ได้เลย
                                            if (acceptedOrders.isNotEmpty) {
                                              Set<String> customerNames =
                                                  acceptedOrders.map((o) => o["customerName"] as String).toSet();
                                              if (customerNames.isNotEmpty &&
                                                  !customerNames.contains(order["customerName"])) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text("ไม่สามารถรับออเดอร์จากลูกค้าหลายคนพร้อมกันได้"),
                                                  ),
                                                );
                                                return;
                                              }
                                            }

                                            double distanceFromRider = _calculateDistance(
                                              currentPosition!.latitude,
                                              currentPosition!.longitude,
                                              order['storeLatitude'],
                                              order['storeLongitude'],
                                            );

                                            setState(() {
                                              order["accepted"] = true;
                                              order["distanceFromRider"] = distanceFromRider; // อัปเดตระยะทาง
                                            });

                                            // หลังจาก set accepted แล้ว เรียกฟังก์ชันการยืนยัน order
                                            _assignOrderToRiderConfirmed(
                                              {
                                                'latitude': currentPosition!.latitude,
                                                'longitude': currentPosition!.longitude,
                                              },
                                              [order],
                                            );

                                            Navigator.of(context).pop();
                                          } else {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(SnackBar(content: Text("กรุณาตรวจสอบตำแหน่งไรเดอร์")));
                                          }
                                        },
                                      ),

                                      IconButton(
                                        icon: Icon(Icons.cancel, color: Colors.red),
                                        onPressed: () {
                                          if (order["accepted"] == true) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(SnackBar(content: Text("ไม่สามารถยกเลิกงานที่รับแล้วได้")));
                                          } else {
                                            setState(() {
                                              _newOrders.removeWhere((o) => o["orderId"] == order["orderId"]);
                                              _notificationCount = _newOrders.length;
                                            });
                                            setStateDialog(() {});
                                            if (_newOrders.isEmpty) {
                                              Navigator.of(context).pop();
                                            }
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                            ],
                          ),
                        );
                      }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _newOrders.clear();
                      _notificationCount = 0;
                      polylines.clear();
                      _selectedOrderStores.clear();
                    });
                    Navigator.of(context).pop();
                  },
                  child: Text("Clear all"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showApiKeyDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text("⚠️ API Key Error"),
            content: Text(message),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text("OK"))],
          ),
    );
  }
}
