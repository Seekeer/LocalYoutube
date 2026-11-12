#include "window_fullscreen.h"

#include <shobjidl.h>

namespace {

// Tells the shell that the window is (or is no longer) a fullscreen window, so
// the taskbar stays below it even when Windows does not detect that on its own
// (for example while another window briefly takes the foreground).
void MarkTaskbarFullscreen(HWND window, bool fullscreen) {
  ITaskbarList2* taskbar = nullptr;
  if (FAILED(CoCreateInstance(CLSID_TaskbarList, nullptr, CLSCTX_INPROC_SERVER,
                              IID_PPV_ARGS(&taskbar)))) {
    return;
  }
  if (SUCCEEDED(taskbar->HrInit())) {
    taskbar->MarkFullscreenWindow(window, fullscreen ? TRUE : FALSE);
  }
  taskbar->Release();
}

}  // namespace

bool WindowFullscreen::Set(HWND window, bool fullscreen) {
  if (window == nullptr) {
    return false;
  }
  if (fullscreen == is_fullscreen_) {
    return true;
  }
  if (fullscreen) {
    if (!Enter(window)) {
      return false;
    }
  } else {
    Leave(window);
  }
  is_fullscreen_ = fullscreen;
  MarkTaskbarFullscreen(window, fullscreen);
  return true;
}

void WindowFullscreen::FitToMonitor(HWND window) {
  if (window == nullptr || !is_fullscreen_) {
    return;
  }
  CoverMonitor(window, SWP_NOZORDER | SWP_NOACTIVATE, /*force=*/false);
}

bool WindowFullscreen::CoverMonitor(HWND window, UINT flags, bool force) {
  HMONITOR monitor = MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST);
  MONITORINFO monitor_info{};
  monitor_info.cbSize = sizeof(monitor_info);
  if (monitor == nullptr || !GetMonitorInfo(monitor, &monitor_info)) {
    return false;
  }
  const RECT& bounds = monitor_info.rcMonitor;
  RECT current{};
  if (!force && GetWindowRect(window, &current) &&
      EqualRect(&current, &bounds)) {
    return true;
  }
  return SetWindowPos(window, HWND_TOP, bounds.left, bounds.top,
                      bounds.right - bounds.left, bounds.bottom - bounds.top,
                      flags | SWP_NOOWNERZORDER | SWP_FRAMECHANGED) != FALSE;
}

bool WindowFullscreen::Enter(HWND window) {
  // A maximized window is restored first, so the rectangle remembered below is
  // the one the window returns to, and it is maximized again on the way out.
  was_maximized_ = IsZoomed(window) != FALSE;
  if (was_maximized_) {
    SendMessage(window, WM_SYSCOMMAND, SC_RESTORE, 0);
  }
  style_ = GetWindowLongPtr(window, GWL_STYLE);
  ex_style_ = GetWindowLongPtr(window, GWL_EXSTYLE);
  GetWindowRect(window, &window_rect_);

  SetWindowLongPtr(window, GWL_STYLE, style_ & ~(WS_CAPTION | WS_THICKFRAME));
  SetWindowLongPtr(window, GWL_EXSTYLE,
                   ex_style_ & ~(WS_EX_DLGMODALFRAME | WS_EX_WINDOWEDGE |
                                 WS_EX_CLIENTEDGE | WS_EX_STATICEDGE));

  // Always moved, even onto the rectangle it already has: SWP_FRAMECHANGED is
  // what makes Windows apply the frameless style.
  if (!CoverMonitor(window, 0, /*force=*/true)) {
    SetWindowLongPtr(window, GWL_STYLE, style_);
    SetWindowLongPtr(window, GWL_EXSTYLE, ex_style_);
    SetWindowPos(window, nullptr, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_FRAMECHANGED);
    if (was_maximized_) {
      SendMessage(window, WM_SYSCOMMAND, SC_MAXIMIZE, 0);
    }
    return false;
  }
  return true;
}

void WindowFullscreen::Leave(HWND window) {
  SetWindowLongPtr(window, GWL_STYLE, style_);
  SetWindowLongPtr(window, GWL_EXSTYLE, ex_style_);
  SetWindowPos(window, nullptr, window_rect_.left, window_rect_.top,
               window_rect_.right - window_rect_.left,
               window_rect_.bottom - window_rect_.top,
               SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED);
  if (was_maximized_) {
    SendMessage(window, WM_SYSCOMMAND, SC_MAXIMIZE, 0);
  }
}
