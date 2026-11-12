#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/encodable_value.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>

#include <memory>

#include "win32_window.h"
#include "window_fullscreen.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // The window's own message handling; MessageHandler adds fullscreen upkeep.
  LRESULT HandleMessage(HWND window, UINT const message, WPARAM const wparam,
                        LPARAM const lparam) noexcept;

  // Answers the Dart side's requests about the window itself: entering and
  // leaving fullscreen for the player.
  void HandleWindowMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      window_channel_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      app_control_channel_;
  WindowFullscreen fullscreen_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
