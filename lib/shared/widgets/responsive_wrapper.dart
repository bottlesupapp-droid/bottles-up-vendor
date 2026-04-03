import 'package:flutter/material.dart';
import 'package:responsive_builder/responsive_builder.dart';
import '../../core/utils/responsive_utils.dart';

class ResponsiveWrapper extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final bool centerContent;
  final double? maxWidth;

  const ResponsiveWrapper({
    super.key,
    required this.child,
    this.padding,
    this.centerContent = false,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final responsivePadding = padding ?? ResponsiveUtils.getResponsiveMargin(context);
    final responsiveMaxWidth = maxWidth ?? ResponsiveUtils.getMaxWidth(context);

    return ResponsiveBuilder(
      builder: (context, sizingInformation) {
        Widget content = Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxWidth: responsiveMaxWidth,
          ),
          padding: responsivePadding,
          child: child,
        );

        if (centerContent && sizingInformation.deviceScreenType != DeviceScreenType.mobile) {
          content = Center(child: content);
        }

        return content;
      },
    );
  }
}

class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Decoration? decoration;
  final double? width;
  final double? height;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.decoration,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, sizingInformation) {
        final responsivePadding = padding ?? EdgeInsets.all(ResponsiveUtils.getResponsiveCardPadding(context));
        
        return Container(
          width: width,
          height: height,
          margin: margin,
          padding: responsivePadding,
          decoration: decoration,
          child: child,
        );
      },
    );
  }
}

class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double? mainAxisSpacing;
  final double? crossAxisSpacing;
  final double? childAspectRatio;
  final int? crossAxisCount;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.mainAxisSpacing,
    this.crossAxisSpacing,
    this.childAspectRatio,
    this.crossAxisCount,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, sizingInformation) {
        final responsiveCrossAxisCount = crossAxisCount ?? ResponsiveUtils.getGridCrossAxisCount(context);
        final responsiveSpacing = ResponsiveUtils.getResponsiveSpacing(context);
        final responsiveChildAspectRatio = childAspectRatio ?? ResponsiveUtils.getChildAspectRatio(context);

        return GridView.count(
          crossAxisCount: responsiveCrossAxisCount,
          crossAxisSpacing: crossAxisSpacing ?? responsiveSpacing,
          mainAxisSpacing: mainAxisSpacing ?? responsiveSpacing,
          childAspectRatio: responsiveChildAspectRatio,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: children,
        );
      },
    );
  }
}

class ResponsiveText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final ResponsiveTextType type;

  const ResponsiveText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.type = ResponsiveTextType.body,
  });

  const ResponsiveText.headlineLarge(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  }) : type = ResponsiveTextType.headlineLarge;

  const ResponsiveText.headlineMedium(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  }) : type = ResponsiveTextType.headlineMedium;

  const ResponsiveText.headlineSmall(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  }) : type = ResponsiveTextType.headlineSmall;

  const ResponsiveText.titleLarge(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  }) : type = ResponsiveTextType.titleLarge;

  const ResponsiveText.titleMedium(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  }) : type = ResponsiveTextType.titleMedium;

  const ResponsiveText.titleSmall(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  }) : type = ResponsiveTextType.titleSmall;

  const ResponsiveText.bodyLarge(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  }) : type = ResponsiveTextType.bodyLarge;

  const ResponsiveText.bodyMedium(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  }) : type = ResponsiveTextType.bodyMedium;

  const ResponsiveText.bodySmall(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  }) : type = ResponsiveTextType.bodySmall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    TextStyle? responsiveStyle;
    switch (type) {
      case ResponsiveTextType.headlineLarge:
        responsiveStyle = getValueForScreenType<TextStyle?>(
          context: context,
          mobile: theme.textTheme.headlineLarge?.copyWith(fontSize: 28),
          tablet: theme.textTheme.headlineLarge?.copyWith(fontSize: 32),
          desktop: theme.textTheme.headlineLarge?.copyWith(fontSize: 36),
        );
        break;
      case ResponsiveTextType.headlineMedium:
        responsiveStyle = getValueForScreenType<TextStyle?>(
          context: context,
          mobile: theme.textTheme.headlineMedium?.copyWith(fontSize: 24),
          tablet: theme.textTheme.headlineMedium?.copyWith(fontSize: 28),
          desktop: theme.textTheme.headlineMedium?.copyWith(fontSize: 32),
        );
        break;
      case ResponsiveTextType.headlineSmall:
        responsiveStyle = getValueForScreenType<TextStyle?>(
          context: context,
          mobile: theme.textTheme.headlineSmall?.copyWith(fontSize: 20),
          tablet: theme.textTheme.headlineSmall?.copyWith(fontSize: 22),
          desktop: theme.textTheme.headlineSmall?.copyWith(fontSize: 24),
        );
        break;
      case ResponsiveTextType.titleLarge:
        responsiveStyle = getValueForScreenType<TextStyle?>(
          context: context,
          mobile: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
          tablet: theme.textTheme.titleLarge?.copyWith(fontSize: 20),
          desktop: theme.textTheme.titleLarge?.copyWith(fontSize: 22),
        );
        break;
      case ResponsiveTextType.titleMedium:
        responsiveStyle = getValueForScreenType<TextStyle?>(
          context: context,
          mobile: theme.textTheme.titleMedium?.copyWith(fontSize: 16),
          tablet: theme.textTheme.titleMedium?.copyWith(fontSize: 18),
          desktop: theme.textTheme.titleMedium?.copyWith(fontSize: 20),
        );
        break;
      case ResponsiveTextType.titleSmall:
        responsiveStyle = getValueForScreenType<TextStyle?>(
          context: context,
          mobile: theme.textTheme.titleSmall?.copyWith(fontSize: 14),
          tablet: theme.textTheme.titleSmall?.copyWith(fontSize: 15),
          desktop: theme.textTheme.titleSmall?.copyWith(fontSize: 16),
        );
        break;
      case ResponsiveTextType.bodyLarge:
        responsiveStyle = getValueForScreenType<TextStyle?>(
          context: context,
          mobile: theme.textTheme.bodyLarge?.copyWith(fontSize: 16),
          tablet: theme.textTheme.bodyLarge?.copyWith(fontSize: 17),
          desktop: theme.textTheme.bodyLarge?.copyWith(fontSize: 18),
        );
        break;
      case ResponsiveTextType.bodyMedium:
        responsiveStyle = getValueForScreenType<TextStyle?>(
          context: context,
          mobile: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
          tablet: theme.textTheme.bodyMedium?.copyWith(fontSize: 15),
          desktop: theme.textTheme.bodyMedium?.copyWith(fontSize: 16),
        );
        break;
      case ResponsiveTextType.bodySmall:
        responsiveStyle = getValueForScreenType<TextStyle?>(
          context: context,
          mobile: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
          tablet: theme.textTheme.bodySmall?.copyWith(fontSize: 13),
          desktop: theme.textTheme.bodySmall?.copyWith(fontSize: 14),
        );
        break;
      case ResponsiveTextType.body:
        responsiveStyle = getValueForScreenType<TextStyle?>(
          context: context,
          mobile: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
          tablet: theme.textTheme.bodyMedium?.copyWith(fontSize: 15),
          desktop: theme.textTheme.bodyMedium?.copyWith(fontSize: 16),
        );
        break;
    }

    // Merge with custom style if provided
    if (style != null && responsiveStyle != null) {
      responsiveStyle = responsiveStyle.merge(style);
    } else if (style != null) {
      responsiveStyle = style;
    }

    return Text(
      text,
      style: responsiveStyle,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

enum ResponsiveTextType {
  headlineLarge,
  headlineMedium,
  headlineSmall,
  titleLarge,
  titleMedium,
  titleSmall,
  bodyLarge,
  bodyMedium,
  bodySmall,
  body,
}