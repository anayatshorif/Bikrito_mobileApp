import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

const _pageDuration = Duration(milliseconds: 260);
const _reverseDuration = Duration(milliseconds: 220);
const _destinationDuration = Duration(milliseconds: 240);
const _dialogDuration = Duration(milliseconds: 200);

/// Page navigation: slides in horizontally while fading in.
class AppPageRoute<T> extends PageRouteBuilder<T> {
  AppPageRoute({required WidgetBuilder builder, super.settings})
    : super(
        transitionDuration: _pageDuration,
        reverseTransitionDuration: _reverseDuration,
        pageBuilder: (context, animation, secondaryAnimation) =>
            builder(context),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.horizontal,
              child: child,
            ),
      );
}

/// Modal form pages: slide up while fading in.
class AppFormRoute<T> extends PageRouteBuilder<T> {
  AppFormRoute({required WidgetBuilder builder, super.settings})
    : super(
        transitionDuration: _pageDuration,
        reverseTransitionDuration: _reverseDuration,
        pageBuilder: (context, animation, secondaryAnimation) =>
            builder(context),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.vertical,
              child: child,
            ),
      );
}

/// Bottom-navigation destination switches: fade only, no slide.
class AppDestinationRoute<T> extends PageRouteBuilder<T> {
  AppDestinationRoute({required WidgetBuilder builder, super.settings})
    : super(
        transitionDuration: _destinationDuration,
        reverseTransitionDuration: _destinationDuration,
        pageBuilder: (context, animation, secondaryAnimation) =>
            builder(context),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeThroughTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              child: child,
            ),
      );
}

/// Dialogs: scale up while fading in.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) => showGeneralDialog<T>(
  context: context,
  barrierDismissible: barrierDismissible,
  barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  barrierColor: Colors.black54,
  transitionDuration: _dialogDuration,
  pageBuilder: (context, animation, secondaryAnimation) => builder(context),
  transitionBuilder: (context, animation, secondaryAnimation, child) =>
      FadeScaleTransition(animation: animation, child: child),
);
