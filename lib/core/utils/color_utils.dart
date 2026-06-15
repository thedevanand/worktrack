import 'package:flutter/material.dart';

Color colorFromHex(String hex) {
  final cleaned = hex.replaceAll('#', '');
  final value = int.parse(
    cleaned.length == 6 ? 'FF$cleaned' : cleaned,
    radix: 16,
  );
  return Color(value);
}

String colorToHex(Color color) {
  final argb = color.toARGB32();
  return '#${argb.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
}
