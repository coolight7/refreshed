import 'package:flutter/material.dart';
import 'package:refreshed/route_manager.dart';
import 'package:refreshed/utils.dart';

extension ExtensionSnackbar on GetInterface {
  SnackbarController rawSnackbar(
    Widget content, {
    bool instantInit = true,
    double? maxWidth,
    EdgeInsets margin = const EdgeInsets.all(0.0),
    EdgeInsets padding = const EdgeInsets.all(16),
    double borderRadius = 0.0,
    Duration? duration = const Duration(seconds: 3),
    bool isDismissible = true,
    DismissDirection? dismissDirection,
    SnackPosition snackPosition = SnackPosition.bottom,
    SnackStyle snackStyle = SnackStyle.floating,
    Curve forwardAnimationCurve = Curves.easeOutCirc,
    Curve reverseAnimationCurve = Curves.easeOutCirc,
    Duration animationDuration = const Duration(seconds: 1),
    SnackbarStatusCallback? snackbarStatus,
    double barBlur = 0.0,
    double overlayBlur = 0.0,
    Color? overlayColor,
  }) {
    final getSnackBar = GetSnackBar(
      content,
      snackbarStatus: snackbarStatus,
      snackPosition: snackPosition,
      borderRadius: borderRadius,
      margin: margin,
      duration: duration,
      barBlur: barBlur,
      maxWidth: maxWidth,
      padding: padding,
      isDismissible: isDismissible,
      dismissDirection: dismissDirection,
      snackStyle: snackStyle,
      forwardAnimationCurve: forwardAnimationCurve,
      reverseAnimationCurve: reverseAnimationCurve,
      animationDuration: animationDuration,
      overlayBlur: overlayBlur,
      overlayColor: overlayColor,
    );

    final controller = SnackbarController(getSnackBar);

    if (instantInit) {
      controller.show();
    } else {
      Engine.instance.addPostFrameCallback((_) {
        controller.show();
      });
    }
    return controller;
  }

  SnackbarController showSnackbar(GetSnackBar snackbar) {
    final controller = SnackbarController(snackbar);
    controller.show();
    return controller;
  }

  SnackbarController snackbar(
    Widget content, {
    Duration? duration = const Duration(seconds: 3),
    bool instantInit = true,
    SnackPosition? snackPosition,
    double? maxWidth,
    EdgeInsets? margin,
    EdgeInsets? padding,
    double? borderRadius,
    List<BoxShadow>? boxShadows,
    OnHover? onHover,
    bool? isDismissible,
    DismissDirection? dismissDirection,
    SnackStyle? snackStyle,
    Curve? forwardAnimationCurve,
    Curve? reverseAnimationCurve,
    Duration? animationDuration,
    double? barBlur,
    double? overlayBlur,
    SnackbarStatusCallback? snackbarStatus,
    Color? overlayColor,
  }) {
    final getSnackBar = GetSnackBar(
      content,
      snackbarStatus: snackbarStatus,
      snackPosition: snackPosition ?? SnackPosition.top,
      borderRadius: borderRadius ?? 15,
      margin: margin ?? const EdgeInsets.all(10),
      duration: duration,
      barBlur: barBlur ?? 7.0,
      boxShadows: boxShadows,
      maxWidth: maxWidth,
      padding: padding ?? const EdgeInsets.all(16),
      onHover: onHover,
      isDismissible: isDismissible ?? true,
      dismissDirection: dismissDirection,
      snackStyle: snackStyle ?? SnackStyle.floating,
      forwardAnimationCurve: forwardAnimationCurve ?? Curves.easeOutCirc,
      reverseAnimationCurve: reverseAnimationCurve ?? Curves.easeOutCirc,
      animationDuration: animationDuration ?? const Duration(seconds: 1),
      overlayBlur: overlayBlur ?? 0.0,
      overlayColor: overlayColor ?? Colors.transparent,
    );

    final controller = SnackbarController(getSnackBar);

    if (instantInit) {
      controller.show();
    } else {
      //routing.isSnackbar = true;
      Engine.instance.addPostFrameCallback((_) {
        controller.show();
      });
    }
    return controller;
  }

  /// check if snackbar is open
  bool get isSnackbarOpen =>
      SnackbarController.isSnackbarBeingShown; //routing.isSnackbar;

  void closeAllSnackbars() {
    SnackbarController.cancelAllSnackbars();
  }

  Future<void> closeCurrentSnackbar() async {
    await SnackbarController.closeCurrentSnackbar();
  }
}
