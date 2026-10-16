from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import install_android_ndk as installer


VERSION = "28.2.13676358"


def write_ndk(directory: Path, version: str = VERSION) -> None:
    directory.mkdir(parents=True)
    (directory / "source.properties").write_text(f"Pkg.Revision = {version}\n")
    for name in (
        "build/cmake/android.toolchain.cmake",
        "toolchains/llvm/prebuilt/linux-x86_64/bin/clang",
    ):
        target = directory / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.touch()


class InstallAndroidNdkTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.sdk = Path(self.temporary.name).resolve()
        (self.sdk / "licenses").mkdir()
        (self.sdk / "licenses/android-sdk-license").write_text("accepted")

    def staging_from(self, command):
        return Path(command[1].removeprefix("--sdk_root="))

    def test_resolves_version_from_flutter_sdk(self):
        source = self.sdk / "packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt"
        source.parent.mkdir(parents=True)
        source.write_text(f'val ndkVersion: String = "{VERSION}"')
        self.assertEqual(installer.flutter_ndk_version(self.sdk), VERSION)
        source.write_text('val ndkVersion = unknownVersion')
        with self.assertRaisesRegex(RuntimeError, "Cannot resolve"):
            installer.flutter_ndk_version(self.sdk)

    @patch.object(installer.subprocess, "run")
    def test_complete_install_is_reused(self, run):
        write_ndk(self.sdk / "ndk" / VERSION)
        installer.install_ndk(self.sdk, "sdkmanager", VERSION)
        run.assert_not_called()

    @patch.object(installer.subprocess, "run")
    def test_corrupt_archive_retries_with_fresh_state_and_preserves_other_ndks(self, run):
        destination = self.sdk / "ndk" / VERSION
        destination.mkdir(parents=True)
        (destination / "source.properties").write_text(f"Pkg.Revision = {VERSION}\n")
        other = self.sdk / "ndk/27.0.0"
        write_ndk(other, "27.0.0")
        attempts = []

        def download(command, **kwargs):
            staging = self.staging_from(command)
            attempts.append(staging)
            self.assertEqual(command[-1], f"ndk;{VERSION}")
            self.assertEqual(kwargs["timeout"], 900)
            self.assertEqual(Path(kwargs["env"]["ANDROID_USER_HOME"]), staging / "android-user")
            self.assertEqual((staging / "licenses/android-sdk-license").read_text(), "accepted")
            if len(attempts) == 1:
                (staging / ".temp").mkdir()
                (staging / ".temp/bad.zip").write_text("corrupt archive")
                raise subprocess.CalledProcessError(1, command)
            self.assertFalse(attempts[0].exists())
            self.assertFalse((staging / ".temp/bad.zip").exists())
            write_ndk(staging / "ndk" / VERSION)

        run.side_effect = download
        installer.install_ndk(self.sdk, "sdkmanager", VERSION)
        self.assertEqual(run.call_count, 2)
        self.assertNotEqual(attempts[0], attempts[1])
        self.assertTrue(installer.valid_ndk(destination, VERSION))
        self.assertTrue(installer.valid_ndk(other, "27.0.0"))
        self.assertFalse(list(self.sdk.glob(".localtube-ndk-*")))

    @patch.object(installer.subprocess, "run")
    def test_timeout_stops_after_three_attempts(self, run):
        run.side_effect = subprocess.TimeoutExpired("sdkmanager", 900)
        with self.assertRaisesRegex(RuntimeError, "after 3 attempts"):
            installer.install_ndk(self.sdk, "sdkmanager", VERSION)
        self.assertEqual(run.call_count, 3)
        self.assertFalse((self.sdk / "ndk" / VERSION).exists())
        self.assertFalse(list(self.sdk.glob(".localtube-ndk-*")))

    @patch.object(installer.subprocess, "run")
    def test_success_exit_with_incomplete_ndk_is_rejected(self, run):
        with self.assertRaisesRegex(RuntimeError, "after 3 attempts"):
            installer.install_ndk(self.sdk, "sdkmanager", VERSION)
        self.assertEqual(run.call_count, 3)
        self.assertFalse((self.sdk / "ndk" / VERSION).exists())

    def test_wrong_revision_is_rejected(self):
        write_ndk(self.sdk / "ndk" / VERSION, "27.0.0")
        self.assertFalse(installer.valid_ndk(self.sdk / "ndk" / VERSION, VERSION))


if __name__ == "__main__":
    unittest.main()
