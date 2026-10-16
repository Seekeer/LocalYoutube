# STEP 17: Android Performance and Battery Checklist

## 1. Preconditions
- Device: physical Android device (not emulator), battery >= 70%.
- Build: `flutter build apk --release` and install release APK.
- Network: stable Wi-Fi for online scenarios.
- App package: `org.localtube.flutter`.

## 2. Scenarios
1. Playback in background:
- Start video playback.
- Lock screen for 30 minutes.
- Unlock screen and verify playback/session state.

2. Background download:
- Queue 1-2 medium files.
- Put app to background for 30 minutes.
- Return to app and verify progress/state consistency.

3. Combined load:
- Start playback and active download.
- Switch app to background and lock screen for 20 minutes.
- Return and verify player controls + downloads screen state.

## 3. Measurement Commands
1. Reset battery stats before each scenario:
```powershell
adb shell dumpsys batterystats --reset
adb shell dumpsys battery unplug
```

2. Collect data after scenario:
```powershell
adb shell dumpsys batterystats > batterystats_after.txt
adb shell dumpsys meminfo org.localtube.flutter > meminfo_after.txt
adb shell dumpsys cpuinfo > cpuinfo_after.txt
adb shell dumpsys activity services org.localtube.flutter > services_after.txt
adb logcat -d > logcat_after.txt
```

3. Restore normal battery service:
```powershell
adb shell dumpsys battery reset
```

## 4. Pass Criteria
- No crashes/ANR in `logcat_after.txt`.
- Playback continues with screen locked (Android media session alive).
- Download tasks resume/continue after backgrounding without stuck state.
- Foreground notifications are present while active and disappear when finished.
- No runaway resource usage in `meminfo_after.txt` / `cpuinfo_after.txt` versus baseline runs.

## 5. Report Template
- Device model / Android version:
- Build hash / date:
- Scenario:
- Duration:
- Result: pass/fail
- Notes:
  - battery delta:
  - memory snapshot:
  - CPU observations:
  - logs:
