import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_rider_locator/flutter_rider_locator.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: StoreFinder(), // ใช้ StoreFinder จาก package ของคุณ
    );
  }
}
