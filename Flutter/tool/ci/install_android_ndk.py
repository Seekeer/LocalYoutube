"""Install Flutter's NDK before Gradle, retrying with fresh SDK download state."""

import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


def flutter_ndk_version(flutter_root: Path) -> str:
    extension = flutter_root / (
        "packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt"
    )
    match = re.search(
        r'\bval\s+ndkVersion\s*(?::\s*String)?\s*=\s*"(\d+\.\d+\.\d+)"',
        extension.read_text(encoding="utf-8"),
    )
    if not match:
        raise RuntimeError(f"Cannot resolve Flutter's NDK version from {extension}")
    return match.group(1)


def valid_ndk(directory: Path, version: str) -> bool:
    properties = directory / "source.properties"
    if not properties.is_file():
        return False
    return (
        re.search(
            rf"(?m)^Pkg\.Revision\s*=\s*{re.escape(version)}\s*$",
            properties.read_text(encoding="utf-8"),
        )
        is not None
        and (directory / "build/cmake/android.toolchain.cmake").is_file()
        and (directory / "toolchains/llvm/prebuilt/linux-x86_64/bin/clang").is_file()
    )


def install_ndk(sdk_root: Path, sdkmanager: str, version: str) -> None:
    sdk_root = sdk_root.resolve(strict=True)
    destination = sdk_root / "ndk" / version
    # Never replace an NDK reached through a symlink outside this SDK.
    if destination.resolve().parent != sdk_root / "ndk":
        raise RuntimeError(f"NDK destination is outside the SDK's ndk directory: {destination}")
    if valid_ndk(destination, version):
        print(f"Android NDK {version} is already installed.", flush=True)
        return
    licenses = sdk_root / "licenses"
    if not licenses.is_dir():
        raise RuntimeError("Accept Android SDK licenses before installing the NDK.")

    for attempt in range(1, 4):
        print(f"Installing Android NDK {version} (attempt {attempt}/3)", flush=True)
        # Isolate both SDK .temp downloads and Android's user cache. A corrupt
        # archive from a previous run must not be reused by sdkmanager.
        with tempfile.TemporaryDirectory(prefix=".localtube-ndk-", dir=sdk_root) as temporary:
            staging = Path(temporary)
            shutil.copytree(licenses, staging / "licenses")
            user_home = staging / "android-user"
            user_home.mkdir()
            environment = dict(os.environ, ANDROID_USER_HOME=str(user_home))
            try:
                subprocess.run(
                    [sdkmanager, f"--sdk_root={staging}", "--install", f"ndk;{version}"],
                    env=environment,
                    stdin=subprocess.DEVNULL,
                    check=True,
                    timeout=900,
                )
                installed = staging / "ndk" / version
                if not valid_ndk(installed, version):
                    raise RuntimeError("sdkmanager returned an incomplete NDK installation")
            except (subprocess.CalledProcessError, subprocess.TimeoutExpired, RuntimeError) as error:
                print(f"NDK installation attempt {attempt} failed: {error}", flush=True)
                if attempt == 3:
                    raise RuntimeError(f"Cannot install Android NDK {version} after 3 attempts") from error
                continue

            destination.parent.mkdir(exist_ok=True)
            if destination.exists():
                destination.rename(staging / "previous-incomplete-ndk")
            installed.rename(destination)
            print(f"Android NDK {version} is ready at {destination}", flush=True)
            return


def main() -> None:
    flutter_root = os.environ.get("FLUTTER_ROOT")
    if not flutter_root:
        flutter = shutil.which("flutter")
        if not flutter:
            raise RuntimeError("Flutter is not available; run Flutter setup first.")
        flutter_root = str(Path(flutter).resolve().parent.parent)
    sdk_root = os.environ.get("ANDROID_SDK_ROOT") or os.environ.get("ANDROID_HOME")
    sdkmanager = shutil.which("sdkmanager")
    if not sdk_root or not sdkmanager:
        raise RuntimeError("Android SDK is not available; run Android SDK setup first.")
    install_ndk(Path(sdk_root), sdkmanager, flutter_ndk_version(Path(flutter_root)))


if __name__ == "__main__":
    main()
