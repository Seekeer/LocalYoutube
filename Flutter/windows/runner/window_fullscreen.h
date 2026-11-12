#ifndef RUNNER_WINDOW_FULLSCREEN_H_
#define RUNNER_WINDOW_FULLSCREEN_H_

#include <windows.h>

// Switches a top-level window between its ordinary frame and borderless
// fullscreen on the monitor the window is on.
//
// Fullscreen covers the whole monitor, title bar, frame and taskbar included.
// The ordinary state (style, position, size and whether the window was
// maximized) is remembered on the way in, so leaving fullscreen puts the
// window back exactly where it was.
class WindowFullscreen {
 public:
  WindowFullscreen() = default;

  WindowFullscreen(const WindowFullscreen&) = delete;
  WindowFullscreen& operator=(const WindowFullscreen&) = delete;

  bool IsFullscreen() const { return is_fullscreen_; }

  // Enters or leaves fullscreen. Asking for the state the window is already
  // in does nothing. Returns false when the window could not be changed.
  bool Set(HWND window, bool fullscreen);

  // Covers the monitor the window is on again, if it is in fullscreen. Call it
  // after Windows has moved or resized the window on its own: a DPI change
  // applies a suggested rectangle that no longer matches the monitor, and a
  // display change can resize the monitor itself.
  void FitToMonitor(HWND window);

 private:
  // Places the window over the whole monitor it is on. Without |force| a
  // window that already covers it is left alone.
  static bool CoverMonitor(HWND window, UINT flags, bool force);

  bool Enter(HWND window);
  void Leave(HWND window);

  bool is_fullscreen_ = false;
  bool was_maximized_ = false;
  LONG_PTR style_ = 0;
  LONG_PTR ex_style_ = 0;
  RECT window_rect_{};
};

#endif  // RUNNER_WINDOW_FULLSCREEN_H_
