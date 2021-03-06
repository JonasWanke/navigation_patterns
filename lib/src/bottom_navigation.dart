import 'package:flutter/material.dart';

typedef TabNavigatorBuilder = Widget Function(
  BuildContext context,
  int tabIndex,
  GlobalKey<NavigatorState> navigatorKey,
);
typedef ScaffoldBuilder = Widget Function(
  BuildContext context,
  Widget body,
  int selectedTabIndex,
  TabSelectionCallback onTabSelected,
);
typedef TabSelectionCallback = void Function(int tabIndex);

class BottomNavigationPattern extends StatefulWidget {
  const BottomNavigationPattern({
    Key? key,
    required this.tabCount,
    required this.navigatorBuilder,
    required this.scaffoldBuilder,
  })   : assert(tabCount > 0),
        super(key: key);

  final int tabCount;
  final TabNavigatorBuilder navigatorBuilder;
  final ScaffoldBuilder scaffoldBuilder;

  @override
  BottomNavigationPatternState createState() => BottomNavigationPatternState();
}

class BottomNavigationPatternState extends State<BottomNavigationPattern>
    with TickerProviderStateMixin {
  late final List<AnimationController> _faders;

  var _selectedTabIndex = 0;

  late final List<GlobalKey<NavigatorState>> _navigatorKeys;
  List<GlobalKey<NavigatorState>> get navigatorKeys => _navigatorKeys;
  NavigatorState get currentNavigator =>
      navigatorKeys[_selectedTabIndex].currentState!;

  void selectTab(int index, {bool popIfAlreadySelected = false}) {
    assert(0 <= index && index < widget.tabCount);

    final pop = popIfAlreadySelected && _selectedTabIndex == index;
    setState(() {
      _selectedTabIndex = index;
      if (pop) {
        currentNavigator.popUntil((route) => route.isFirst);
      }
    });
  }

  @override
  void initState() {
    super.initState();

    _faders = List.generate(
      widget.tabCount,
      (_) =>
          AnimationController(vsync: this, duration: kThemeAnimationDuration),
    );
    _faders[_selectedTabIndex].value = 1;

    _navigatorKeys = List.generate(
      widget.tabCount,
      (_) => GlobalKey<NavigatorState>(),
    );
  }

  @override
  void dispose() {
    for (final fader in _faders) {
      fader.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = Stack(
      fit: StackFit.expand,
      children: <Widget>[
        for (var i = 0; i < widget.tabCount; i++)
          _TabContent(
            tabIndex: i,
            navigatorBuilder: widget.navigatorBuilder,
            navigatorKey: navigatorKeys[i],
            fader: _faders[i],
            isActive: i == _selectedTabIndex,
          ),
      ],
    );

    return WillPopScope(
      onWillPop: _onWillPop,
      child: widget.scaffoldBuilder(
        context,
        body,
        _selectedTabIndex,
        (index) => selectTab(index, popIfAlreadySelected: true),
      ),
    );
  }

  /// When the user tries to pop, we first try to pop with the inner navigator.
  /// If that's not possible (we are at a top-level location), we go to the
  /// first tab. Only if we were already there, we pop (aka close the app).
  Future<bool> _onWillPop() async {
    if (currentNavigator.canPop()) {
      currentNavigator.pop();
      return false;
    } else if (_selectedTabIndex != 0) {
      selectTab(0);
      return false;
    } else {
      return true;
    }
  }
}

class _TabContent extends StatefulWidget {
  const _TabContent({
    Key? key,
    required this.tabIndex,
    required this.navigatorKey,
    required this.navigatorBuilder,
    required this.fader,
    required this.isActive,
  })   : assert(tabIndex >= 0),
        super(key: key);

  final int tabIndex;
  final GlobalKey<NavigatorState> navigatorKey;
  final TabNavigatorBuilder navigatorBuilder;
  final AnimationController fader;
  final bool isActive;

  @override
  _TabContentState createState() => _TabContentState();
}

class _TabContentState extends State<_TabContent> {
  Widget? _child;

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      widget.fader.reverse();
      final child = _child ?? SizedBox();
      if (widget.fader.isAnimating) {
        return IgnorePointer(child: child);
      }
      return Offstage(child: child);
    }

    // Lazy-init the child.
    _child ??= FadeTransition(
      opacity: widget.fader.drive(CurveTween(curve: Curves.fastOutSlowIn)),
      child: widget.navigatorBuilder(
        context,
        widget.tabIndex,
        widget.navigatorKey,
      ),
    );

    widget.fader.forward();
    return _child!;
  }
}
