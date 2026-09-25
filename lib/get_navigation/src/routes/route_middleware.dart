import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';

import '../../../refreshed.dart';

/// Middleware to handle page lifecycle events in a prioritized manner.
///
/// Functions are called in this order:
/// `redirect -> onPageCalled -> onBindingsStart -> onPageBuildStart -> onPageBuilt -> onPageDispose`
abstract class GetMiddleware {
  /// Creates a middleware with a given priority.
  const GetMiddleware({this.priority = 0});

  /// Defines the execution order of middlewares. Lower values run first.
  final int priority;

  /// Called when searching for a route. Can return a new [RouteSettings] to redirect.
  RouteSettings? redirect(String? route) => null;

  /// Called when the router delegate changes the current route.
  FutureOr<RouteDecoder?> redirectDelegate(RouteDecoder route) => route;

  /// Called when a page is accessed. Can modify the [GetPage].
  GetPage? onPageCalled(GetPage? page) => page;

  /// Called before [BindingsInterface] initialization. Can modify bindings.
  List<R>? onBindingsStart<R>(List<R>? bindings) => bindings;

  /// Called before the page builder executes.
  GetPageBuilder? onPageBuildStart(GetPageBuilder? page) => page;

  /// Called after the page builder executes.
  Widget onPageBuilt(Widget page) => page;

  /// Called when the page is disposed.
  void onPageDispose() {}
}

/// Manages and executes [GetMiddleware] in a prioritized order.
class MiddlewareRunner {
  /// Creates a [MiddlewareRunner] and sorts middlewares by priority.
  MiddlewareRunner(List<GetMiddleware>? middlewares)
      : _middlewares = middlewares != null
            ? (List.of(middlewares)
              ..sort((a, b) => a.priority.compareTo(b.priority)))
            : const [];

  final List<GetMiddleware> _middlewares;

  /// Runs the `onPageCalled` hook in sequence.
  GetPage? runOnPageCalled(GetPage? page) {
    for (final middleware in _middlewares) {
      page = middleware.onPageCalled(page);
    }
    return page;
  }

  /// Runs the `redirect` hook in sequence.
  ///
  /// Returns the first non-null redirect result from any middleware,
  /// or null if no middleware redirects.
  RouteSettings? runRedirect(String? route) {
    // Use firstWhereOrNull with pattern matching to find the first middleware that redirects
    final redirectingMiddleware = _middlewares
        .firstWhereOrNull((middleware) => middleware.redirect(route) != null);

    // Return the redirect result from the middleware or null if none found
    return redirectingMiddleware?.redirect(route);
  }

  /// Runs the `onBindingsStart` hook in sequence.
  List<R>? runOnBindingsStart<R>(List<R>? bindings) {
    for (final middleware in _middlewares) {
      bindings = middleware.onBindingsStart(bindings);
    }
    return bindings;
  }

  /// Runs the `onPageBuildStart` hook in sequence.
  GetPageBuilder? runOnPageBuildStart(GetPageBuilder? page) {
    for (final middleware in _middlewares) {
      page = middleware.onPageBuildStart(page);
    }
    return page;
  }

  /// Runs the `onPageBuilt` hook in sequence.
  Widget runOnPageBuilt(Widget page) {
    for (final middleware in _middlewares) {
      page = middleware.onPageBuilt(page);
    }
    return page;
  }

  /// Runs the `onPageDispose` hook in sequence.
  void runOnPageDispose() {
    for (final middleware in _middlewares) {
      middleware.onPageDispose();
    }
  }
}

/// Handles page redirection in a GetX navigation context.
class PageRedirect {
  /// 中间件重定向的最大轮数（兜底：正常情况下第一轮就稳定了）
  static const int maxRedirectPasses = 8;

  GetPage? route;
  GetPage? unknownRoute;
  RouteSettings? settings;
  bool isUnknown;

  /// Creates an instance of [PageRedirect].
  PageRedirect(
      {this.route, this.unknownRoute, this.isUnknown = false, this.settings});

  /// Returns a [GetPageRoute] for the given route.
  GetPageRoute<T> getPageToRoute<T>(
      GetPage rou, GetPage? unk, BuildContext context) {
    // Check for redirections until we reach a stable state
    // 轮数必须有上限：一旦出现"目标没变却一直判定要重查"的情况，这个 `while` 会在
    // UI 线程上原地打转，整个应用直接卡死（不再是"跳转失败"这种可见问题）
    int passes = 0;
    while (needRecheck(context)) {
      // Break if we lose essential state
      if (settings == null || route == null) break;
      if (++passes >= maxRedirectPasses) break;
    }

    // Determine the final route to use (unknown or regular)
    final r = (isUnknown ? unk : rou)!;

    // Create and return the page route with all properties from the route
    return GetPageRoute<T>(
      page: r.page,
      parameter: r.parameters,
      alignment: r.alignment,
      title: r.title,
      maintainState: r.maintainState,
      routeName: r.name,
      settings: r,
      curve: r.curve,
      showCupertinoParallax: r.showCupertinoParallax,
      gestureWidth: r.gestureWidth,
      opaque: r.opaque,
      customTransition: r.customTransition,
      bindings: r.bindings,
      binding: r.binding,
      binds: r.binds,
      // Use default transition duration if not specified
      transitionDuration: r.transitionDuration ?? Get.defaultTransitionDuration,
      reverseTransitionDuration:
          r.reverseTransitionDuration ?? Get.defaultTransitionDuration,
      transition: r.transition,
      popGesture: r.popGesture,
      fullscreenDialog: r.fullscreenDialog,
      middlewares: r.middlewares,
    );
  }

  /// Determines if redirection is needed based on route middlewares.
  ///
  /// This method:
  /// 1. Ensures settings are initialized
  /// 2. Matches the current route
  /// 3. Processes middlewares if present
  /// 4. Returns whether redirection is needed
  bool needRecheck(BuildContext context) {
    // Ensure settings is initialized
    settings ??= route;

    // Get the matched route for the current settings
    final match = context.delegate.matchRoute(settings!.name!);

    // Handle case when no route is found
    if (match.route == null) {
      isUnknown = true;
      return false;
    }

    // If no middlewares, no need to recheck
    if (match.route!.middlewares.isEmpty) {
      return false;
    }

    // Process middlewares
    final matchedRoute = match.route!;
    final runner = MiddlewareRunner(matchedRoute.middlewares);
    route = runner.runOnPageCalled(matchedRoute);
    addPageParameter(route!);
    final String? redirectFrom = settings?.name;
    settings = runner.runRedirect(settings!.name) ?? settings;

    // Return true if settings changed (redirection happened)
    //
    // 判据必须是"中间件把目标改到别处"，不能拿页面对象比较：`GetPage` 的相等性只看
    // `key`，而带查询串跳转（`toNamed(..., parameters: ...)`）的页面 key 是"路径 +
    // 查询串"，与这里重新匹配出来的 key（只有路径）必然不同 —— 用对象比较会永远返回
    // true，`getPageToRoute` 的 `while` 就成了死循环（整个界面卡死）
    return settings?.name != redirectFrom;
  }

  /// Adds parameters from [route] to [Get.parameters].
  ///
  /// Uses pattern matching to handle the nullable parameters map.
  void addPageParameter(GetPage route) => switch (route.parameters) {
        // When parameters exist, add them to the global parameters
        Map<String, String> params => Get.parameters.addAll(params),
        // When parameters are null, do nothing
        null => {},
      };
}
