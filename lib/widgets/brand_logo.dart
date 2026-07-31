import 'package:flutter/material.dart';

class BrandLogo extends StatelessWidget {
  static const String assetPath = 'assets/images/nekocast_logo.png';

  final double height;
  final double? width;
  final BoxFit fit;

  const BrandLogo({
    super.key,
    this.height = 72,
    this.width,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      height: height,
      width: width,
      fit: fit,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          Icons.inventory_2_rounded,
          size: height * 0.7,
          color: Colors.white,
        );
      },
    );
  }
}
