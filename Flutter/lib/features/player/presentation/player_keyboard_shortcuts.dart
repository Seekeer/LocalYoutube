import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// What a key pressed on the player asks for.
enum PlayerKeyAction { togglePlayback, toggleFullscreen, exitFullscreen }

/// Reads one key event as a player action, or null when the key is not the player's.
///
/// - Ctrl+F switches fullscreen. It types nothing and no field of the player's screen uses it, so
///   it works wherever the focus is on that screen, a text field included.
/// - Space plays or pauses only while the player itself holds the focus ([ownsFocus]). A focused
///   button, slider, checkbox or text field keeps its own Space - activation or typing - so one
///   press never does two things.
/// - Escape leaves fullscreen when there is a fullscreen to leave ([canExitFullscreen]).
///
/// Ctrl+F is matched on the physical key as well, so it is the same key with any keyboard layout
/// (on a Russian layout that key types "а").
PlayerKeyAction? resolvePlayerKeyAction({
  required KeyEvent event,
  required Set<LogicalKeyboardKey> pressedModifiers,
  required bool ownsFocus,
  required bool isTextInputFocused,
  required bool canExitFullscreen,
}) {
  if (event is KeyUpEvent) {
    return null;
  }
  final bool control = _anyPressed(pressedModifiers, _controlKeys);
  final bool otherModifier = _anyPressed(pressedModifiers, _altKeys) ||
      _anyPressed(pressedModifiers, _metaKeys) ||
      _anyPressed(pressedModifiers, _shiftKeys);

  final bool isF = event.logicalKey == LogicalKeyboardKey.keyF ||
      event.physicalKey == PhysicalKeyboardKey.keyF;
  if (isF && control && !otherModifier) {
    return PlayerKeyAction.toggleFullscreen;
  }
  if (event.logicalKey == LogicalKeyboardKey.space &&
      ownsFocus &&
      !control &&
      !otherModifier) {
    return PlayerKeyAction.togglePlayback;
  }
  if (event.logicalKey == LogicalKeyboardKey.escape &&
      canExitFullscreen &&
      !isTextInputFocused) {
    return PlayerKeyAction.exitFullscreen;
  }
  return null;
}

final Set<LogicalKeyboardKey> _controlKeys = <LogicalKeyboardKey>{
  LogicalKeyboardKey.control,
  LogicalKeyboardKey.controlLeft,
  LogicalKeyboardKey.controlRight,
};
final Set<LogicalKeyboardKey> _altKeys = <LogicalKeyboardKey>{
  LogicalKeyboardKey.alt,
  LogicalKeyboardKey.altLeft,
  LogicalKeyboardKey.altRight,
};
final Set<LogicalKeyboardKey> _metaKeys = <LogicalKeyboardKey>{
  LogicalKeyboardKey.meta,
  LogicalKeyboardKey.metaLeft,
  LogicalKeyboardKey.metaRight,
};
final Set<LogicalKeyboardKey> _shiftKeys = <LogicalKeyboardKey>{
  LogicalKeyboardKey.shift,
  LogicalKeyboardKey.shiftLeft,
  LogicalKeyboardKey.shiftRight,
};

bool _anyPressed(Set<LogicalKeyboardKey> pressed, Set<LogicalKeyboardKey> keys) {
  return pressed.any(keys.contains);
}

/// The player's keyboard, for everything under [child].
///
/// [focusNode] is the player's own focus: it is what holds the focus while nothing more specific
/// on the screen does, and the only place Space plays or pauses from. When a text field gives its
/// focus up and nothing on the screen holds the focus any more, the player takes it back, so Space
/// works again without a click. A callback left null turns its key off (for example while playback
/// has failed), and the key is then left to the rest of the app.
///
/// A held key repeats, but its action happens once per press: the repeats are swallowed.
class PlayerKeyboardShortcuts extends StatefulWidget {
  const PlayerKeyboardShortcuts({
    super.key,
    required this.focusNode,
    required this.child,
    this.onTogglePlayback,
    this.onToggleFullscreen,
    this.onExitFullscreen,
  });

  final FocusNode focusNode;
  final Widget child;
  final VoidCallback? onTogglePlayback;
  final VoidCallback? onToggleFullscreen;
  final VoidCallback? onExitFullscreen;

  @override
  State<PlayerKeyboardShortcuts> createState() =>
      _PlayerKeyboardShortcutsState();
}

class _PlayerKeyboardShortcutsState extends State<PlayerKeyboardShortcuts> {
  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_reclaimFocusWhenNothingHoldsIt);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_reclaimFocusWhenNothingHoldsIt);
    super.dispose();
  }

  /// A text field that lets its focus go hands it to the screen's scope rather than to anything on
  /// the screen. The scope itself is not on the player, so the player's keys would stop working
  /// until something was clicked; taking the focus back keeps them working. Another screen or a
  /// dialog on top owns a different scope, so this never pulls the focus out from under it.
  void _reclaimFocusWhenNothingHoldsIt() {
    if (!mounted) {
      return;
    }
    final FocusNode? primaryFocus = FocusManager.instance.primaryFocus;
    final FocusScopeNode? scope = widget.focusNode.enclosingScope;
    if (primaryFocus != null && scope != null && identical(primaryFocus, scope)) {
      widget.focusNode.requestFocus();
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final PlayerKeyAction? action = resolvePlayerKeyAction(
      event: event,
      pressedModifiers: HardwareKeyboard.instance.logicalKeysPressed,
      ownsFocus: widget.focusNode.hasPrimaryFocus,
      isTextInputFocused: _isTextInputFocused(),
      canExitFullscreen: widget.onExitFullscreen != null,
    );
    final VoidCallback? callback = switch (action) {
      PlayerKeyAction.togglePlayback => widget.onTogglePlayback,
      PlayerKeyAction.toggleFullscreen => widget.onToggleFullscreen,
      PlayerKeyAction.exitFullscreen => widget.onExitFullscreen,
      null => null,
    };
    if (callback == null) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent) {
      callback();
    }
    return KeyEventResult.handled;
  }

  static bool _isTextInputFocused() {
    final BuildContext? focused = FocusManager.instance.primaryFocus?.context;
    if (focused == null) {
      return false;
    }
    return focused.widget is EditableText ||
        focused.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: widget.child,
    );
  }
}
