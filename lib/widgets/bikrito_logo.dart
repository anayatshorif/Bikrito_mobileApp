import 'package:flutter/material.dart';

class BikritoLogo extends StatelessWidget {
  const BikritoLogo({super.key, this.size = 40, this.borderRadius});

  final double size;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(borderRadius ?? size * 0.28),
    child: Image.asset(
      'assets/logo.png',
      width: size,
      height: size,
      fit: BoxFit.cover,
    ),
  );
}
