import 'package:flutter/material.dart';
import 'package:flutter_rider_locator/flutter_rider_locator.dart'; 

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: StoreFinder(),  // ใช้ StoreFinder จาก package ของคุณ
    );
  }
}