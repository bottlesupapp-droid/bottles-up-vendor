import 'package:flutter/material.dart';
import 'package:responsive_builder/responsive_builder.dart';

class ResponsiveUtils {
  static double getResponsivePadding(BuildContext context) {
    return getValueForScreenType<double>(
      context: context,
      mobile: 16.0,
      tablet: 24.0,
      desktop: 32.0,
    );
  }

  static double getResponsiveCardPadding(BuildContext context) {
    return getValueForScreenType<double>(
      context: context,
      mobile: 16.0,
      tablet: 20.0,
      desktop: 24.0,
    );
  }

  static double getResponsiveSpacing(BuildContext context) {
    return getValueForScreenType<double>(
      context: context,
      mobile: 16.0,
      tablet: 20.0,
      desktop: 24.0,
    );
  }

  static double getResponsiveIconSize(BuildContext context) {
    return getValueForScreenType<double>(
      context: context,
      mobile: 24.0,
      tablet: 28.0,
      desktop: 32.0,
    );
  }

  static int getGridCrossAxisCount(BuildContext context) {
    return getValueForScreenType<int>(
      context: context,
      mobile: 2,
      tablet: 3,
      desktop: 4,
    );
  }

  static double getChildAspectRatio(BuildContext context) {
    return getValueForScreenType<double>(
      context: context,
      mobile: 1.1,
      tablet: 1.2,
      desktop: 1.3,
    );
  }

  static double getMaxWidth(BuildContext context) {
    return getValueForScreenType<double>(
      context: context,
      mobile: double.infinity,
      tablet: 600.0,
      desktop: 1200.0,
    );
  }

  static EdgeInsets getResponsiveMargin(BuildContext context) {
    return getValueForScreenType<EdgeInsets>(
      context: context,
      mobile: const EdgeInsets.symmetric(horizontal: 16.0),
      tablet: const EdgeInsets.symmetric(horizontal: 32.0),
      desktop: const EdgeInsets.symmetric(horizontal: 64.0),
    );
  }
}