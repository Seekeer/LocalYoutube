class InstalledApp {
  const InstalledApp(this.applicationId, this.versionCode, this.versionName);

  final String applicationId;
  final int versionCode;
  final String versionName;

  String? get channel => switch (applicationId) {
        const String.fromEnvironment('LOCALTUBE_PREVIEW_APPLICATION_ID',
            defaultValue: 'org.localtube.app.debug') => 'preview',
        'org.localtube.app.stable' => 'stable',
        _ => null,
      };
}

class AvailableUpdate {
  const AvailableUpdate(this.versionCode, this.versionName, this.artifactId,
      this.size, this.sha256, this.downloadUrl);

  final int versionCode;
  final String versionName;
  final String artifactId;
  final int size;
  final String sha256;
  final String downloadUrl;

  factory AvailableUpdate.parse(
      Map<String, dynamic> json, InstalledApp installed) {
    final code = json['versionCode'];
    final hash = json['sha256'];
    final artifact = json['artifactId'];
    final name = json['versionName'];
    final size = json['size'];
    final url = json['downloadUrl'];
    if (json['channel'] != installed.channel ||
        json['applicationId'] != installed.applicationId ||
        code is! int ||
        code <= 0 ||
        code > 2100000000 ||
        name is! String ||
        name.trim().isEmpty ||
        size is! int ||
        size <= 0 ||
        hash is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash) ||
        artifact != '$code-$hash' ||
        url != '/app-updates/${installed.channel}/packages/$artifact') {
      throw const FormatException('Incompatible update metadata');
    }
    return AvailableUpdate(
        code, name, artifact as String, size, hash, url as String);
  }
}
