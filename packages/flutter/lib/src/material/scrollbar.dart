// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'theme.dart';

/// A material design scrollbar.
///
/// A scrollbar indicates which portion of a [Scrollable] widget is actually
/// visible.
///
/// To add a scrollbar to a [ScrollView], simply wrap the scroll view widget in
/// a [Scrollbar] widget.
///
/// See also:
///
///  * [ListView], which display a linear, scrollable list of children.
///  * [GridView], which display a 2 dimensional, scrollable array of children.
class Scrollbar extends StatefulWidget {
  /// Creates a material design scrollbar that wraps the given [child].
  ///
  /// The [child] should be a source of [ScrollNotification] notifications,
  /// typically a [Scrollable] widget.
  Scrollbar({
    Key key,
    @required this.child,
  }) : super(key: key);

  /// The subtree to place inside the [Scrollbar].
  ///
  /// This should include a source of [ScrollNotification] notifications,
  /// typically a [Scrollable] widget.
  final Widget child;

  @override
  _ScrollbarState createState() => new _ScrollbarState();
}

class _ScrollbarState extends State<Scrollbar> with TickerProviderStateMixin {
  _ScrollbarController _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= new _ScrollbarController(this);
    _controller.color = Theme.of(context).highlightColor;
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification ||
        notification is OverscrollNotification)
      _controller.update(notification.metrics, notification.axisDirection);
    return false;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return new NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      // TODO(ianh): Maybe we should try to collapse out these repaint
      // boundaries when the scroll bars are invisible.
      child: new RepaintBoundary(
        child: new CustomPaint(
          foregroundPainter: new _ScrollbarPainter(_controller),
          child: new RepaintBoundary(
            child: config.child,
          ),
        ),
      ),
    );
  }
}

class _ScrollbarController extends ChangeNotifier {
  _ScrollbarController(TickerProvider vsync) {
    assert(vsync != null);
    _fadeController = new AnimationController(duration: _kThumbFadeDuration, vsync: vsync);
    _opacity = new CurvedAnimation(parent: _fadeController, curve: Curves.fastOutSlowIn)
      ..addListener(notifyListeners);
  }

  // animation of the main axis direction
  AnimationController _fadeController;
  Animation<double> _opacity;

  // fade-out timer
  Timer _fadeOut;

  Color get color => _color;
  Color _color;
  set color(Color value) {
    assert(value != null);
    if (color == value)
      return;
    _color = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _fadeOut?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  ScrollMetrics _lastMetrics;
  AxisDirection _lastAxisDirection;

  static const double _kMinThumbExtent = 18.0;
  static const double _kThumbGirth = 6.0;
  static const Duration _kThumbFadeDuration = const Duration(milliseconds: 300);
  static const Duration _kFadeOutTimeout = const Duration(milliseconds: 600);

  void update(ScrollMetrics metrics, AxisDirection axisDirection) {
    _lastMetrics = metrics;
    _lastAxisDirection = axisDirection;
    if (_fadeController.status == AnimationStatus.completed) {
      notifyListeners();
    } else if (_fadeController.status != AnimationStatus.forward) {
      _fadeController.forward();
    }
    _fadeOut?.cancel();
    _fadeOut = new Timer(_kFadeOutTimeout, startFadeOut);
  }

  void startFadeOut() {
    _fadeOut = null;
    _fadeController.reverse();
  }

  Paint get _paint => new Paint()..color = color.withOpacity(_opacity.value);

  void _paintVerticalThumb(Canvas canvas, Size size, double thumbOffset, double thumbExtent) {
    final Point thumbOrigin = new Point(size.width - _kThumbGirth, thumbOffset);
    final Size thumbSize = new Size(_kThumbGirth, thumbExtent);
    canvas.drawRect(thumbOrigin & thumbSize, _paint);
  }

  void _paintHorizontalThumb(Canvas canvas, Size size, double thumbOffset, double thumbExtent) {
    final Point thumbOrigin = new Point(thumbOffset, size.height - _kThumbGirth);
    final Size thumbSize = new Size(thumbExtent, _kThumbGirth);
    canvas.drawRect(thumbOrigin & thumbSize, _paint);
  }

  void _paintThumb(double before, double inside, double after, double viewport, Canvas canvas, Size size,
                   void painter(Canvas canvas, Size size, double thumbOffset, double thumbExtent)) {
    final double thumbExtent = math.max(math.min(viewport, _kMinThumbExtent), viewport * inside / (before + inside + after));
    final double thumbOffset = before * (viewport - thumbExtent) / (before + after);
    painter(canvas, size, thumbOffset, thumbExtent);
  }

  void paint(Canvas canvas, Size size) {
    if (_lastAxisDirection == null || _lastMetrics == null || _opacity.value == 0.0)
      return;
    switch (_lastAxisDirection) {
      case AxisDirection.down:
        _paintThumb(_lastMetrics.extentBefore, _lastMetrics.extentInside, _lastMetrics.extentAfter, size.height, canvas, size, _paintVerticalThumb);
        break;
      case AxisDirection.up:
        _paintThumb(_lastMetrics.extentAfter, _lastMetrics.extentInside, _lastMetrics.extentBefore, size.height, canvas, size, _paintVerticalThumb);
        break;
      case AxisDirection.right:
        _paintThumb(_lastMetrics.extentBefore, _lastMetrics.extentInside, _lastMetrics.extentAfter, size.width, canvas, size, _paintHorizontalThumb);
        break;
      case AxisDirection.left:
        _paintThumb(_lastMetrics.extentAfter, _lastMetrics.extentInside, _lastMetrics.extentBefore, size.width, canvas, size, _paintHorizontalThumb);
        break;
    }
  }
}

class _ScrollbarPainter extends CustomPainter {
  _ScrollbarPainter(this.controller) : super(repaint: controller);

  final _ScrollbarController controller;

  @override
  void paint(Canvas canvas, Size size) {
    controller.paint(canvas, size);
  }

  @override
  bool shouldRepaint(_ScrollbarPainter oldDelegate) {
    return oldDelegate.controller != controller;
  }
}
