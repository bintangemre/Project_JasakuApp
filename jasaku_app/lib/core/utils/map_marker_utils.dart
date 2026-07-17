import 'package:flutter/material.dart';

Widget buildProviderMarkerIcon(String status, {double size = 36}) {
  final isOnWay = status == 'accepted' || status == 'on_the_way';
  final iconSize = size * 0.61;
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: isOnWay ? const Color(0xFF0288D1) : const Color(0xFF10B981),
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 2.5),
      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
    ),
    child: isOnWay
        ? Icon(Icons.motorcycle, color: Colors.white, size: iconSize)
        : Icon(Icons.waving_hand, color: Colors.white, size: iconSize),
  );
}
