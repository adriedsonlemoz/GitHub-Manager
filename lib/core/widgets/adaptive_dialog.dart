import 'package:flutter/material.dart';

class AdaptiveDialogBody extends StatelessWidget {
  const AdaptiveDialogBody({
    required this.child,
    this.maxWidth = 560,
    this.maxHeightFactor = .76,
    super.key,
  });

  final Widget child;
  final double maxWidth;
  final double maxHeightFactor;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final width = media.width - 48;
    final height = media.height * maxHeightFactor;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: width < maxWidth ? width : maxWidth,
        maxHeight: height,
      ),
      child: child,
    );
  }
}
