import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Update channel of a CI-built Windows bundle: `windows-stable` or
/// `windows-preview`.
const String windowsUpdateChannel = String.fromEnvironment(
    'LOCALTUBE_WINDOWS_UPDATE_CHANNEL',
    defaultValue: 'windows-stable');

/// On Windows "application documents" is the user's shared Documents folder.
/// Preview keeps its database, thumbnails and downloads in a subfolder so it
/// can run beside Stable without sharing or migrating Stable's data. Stable
/// keeps the original locations.
const String windowsDocumentsSubdirectory =
    windowsUpdateChannel == 'windows-preview' ? 'LocalTube Preview' : '';

/// Relative prefix (with a trailing `/`) for paths under application documents.
String get documentsSubdirectoryPrefix =>
    Platform.isWindows && windowsDocumentsSubdirectory.isNotEmpty
        ? '$windowsDocumentsSubdirectory/'
        : '';

Future<Directory> applicationDocumentsDirectory() async {
  final Directory documents = await getApplicationDocumentsDirectory();
  if (!Platform.isWindows || windowsDocumentsSubdirectory.isEmpty) {
    return documents;
  }
  final Directory directory = Directory(
      '${documents.path}${Platform.pathSeparator}$windowsDocumentsSubdirectory');
  await directory.create(recursive: true);
  return directory;
}
