#include "flutter_window.h"

#include <optional>
#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"
#include "theme_win10.h"
#include "theme_win11.h"

namespace {
// RTL version structure for ntdll check
typedef struct _RTL_OSVERSIONINFOW {
  ULONG dwOSVersionInfoSize;
  ULONG dwMajorVersion;
  ULONG dwMinorVersion;
  ULONG dwBuildNumber;
  ULONG dwPlatformId;
  WCHAR szCSDVersion[128];
} RTL_OSVERSIONINFOW, *PRTL_OSVERSIONINFOW;

typedef void (WINAPI *RtlGetVersionPtr)(PRTL_OSVERSIONINFOW);

bool IsWindows11OrGreater() {
  HMODULE hMod = GetModuleHandleA("ntdll.dll");
  if (hMod) {
    RtlGetVersionPtr pRtlGetVersion = (RtlGetVersionPtr)GetProcAddress(hMod, "RtlGetVersion");
    if (pRtlGetVersion) {
      RTL_OSVERSIONINFOW osvi = { 0 };
      osvi.dwOSVersionInfoSize = sizeof(osvi);
      pRtlGetVersion(&osvi);
      return osvi.dwMajorVersion > 10 || (osvi.dwMajorVersion == 10 && osvi.dwBuildNumber >= 22000);
    }
  }
  return false;
}
} // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());

  auto messenger = flutter_controller_->engine()->messenger();
  theme_channel_ = std::make_unique<flutter::MethodChannel<>>(
      messenger, "ja_route/theme",
      &flutter::StandardMethodCodec::GetInstance());

  theme_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<>& call,
             std::unique_ptr<flutter::MethodResult<>> result) {
        if (call.method_name() == "updateTheme") {
          const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
          bool is_dark = true;
          if (arguments) {
            auto is_dark_it = arguments->find(flutter::EncodableValue("isDark"));
            if (is_dark_it != arguments->end() && !is_dark_it->second.IsNull()) {
              if (std::holds_alternative<bool>(is_dark_it->second)) {
                is_dark = std::get<bool>(is_dark_it->second);
              }
            }
          }

          HWND hwnd = GetHandle();
          if (hwnd) {
            if (IsWindows11OrGreater()) {
              ApplyThemeWin11(hwnd, is_dark, false);
            } else {
              ApplyThemeWin10(hwnd, is_dark);
            }
          }
          result->Success();
        } else {
          result->NotImplemented();
        }
      });

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // Show the window only after Flutter renders its first frame (avoids blank
  // flash). On some Windows 10 setups the vsync signal is suppressed for
  // hidden windows, so the callback never fires and the app freezes. We arm a
  // 300 ms fallback WM_TIMER so the window is guaranteed to appear.
  HWND hwnd = GetHandle();
  ::SetTimer(hwnd, kShowFallbackTimerId, 300, nullptr);

  flutter_controller_->engine()->SetNextFrameCallback([this]() {
    if (!window_shown_) {
      window_shown_ = true;
      HWND hwnd = GetHandle();
      ::KillTimer(hwnd, kShowFallbackTimerId);
      this->Show();
    }
  });

  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  HWND hwnd = GetHandle();
  if (hwnd != nullptr) {
    ::RemovePropW(hwnd, L"JA_FILE_FOLDER_MODIFY_INSTANCE");
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_TIMER:
      if (wparam == kShowFallbackTimerId) {
        ::KillTimer(hwnd, kShowFallbackTimerId);
        if (!window_shown_) {
          window_shown_ = true;
          this->Show();
          // Force a redraw so the Flutter layer paints immediately
          if (flutter_controller_) {
            flutter_controller_->ForceRedraw();
          }
        }
        return 0;
      }
      break;
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
