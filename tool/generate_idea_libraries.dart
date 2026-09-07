// Generates .idea/libraries/Dart_Packages.xml and Flutter_Plugins.xml
// Run: dart run tool/generate_idea_libraries.dart

import 'dart:convert';
import 'dart:io';

void main() {
  final projectDir = Directory.current;
  final ideaLibDir = Directory('${projectDir.path}/.idea/libraries');
  ideaLibDir.createSync(recursive: true);

  final packageConfigFile = File('${projectDir.path}/.dart_tool/package_config.json');
  if (!packageConfigFile.existsSync()) {
    stderr.writeln('Missing .dart_tool/package_config.json — run flutter pub get first.');
    exit(1);
  }

  final packageConfig = jsonDecode(packageConfigFile.readAsStringSync()) as Map<String, dynamic>;
  final packages = packageConfig['packages'] as List<dynamic>;

  final entries = StringBuffer();
  for (final pkg in packages) {
    final map = pkg as Map<String, dynamic>;
    final name = map['name'] as String;
    final rootUri = map['rootUri'] as String;
    final packageUri = map['packageUri'] as String? ?? 'lib/';
    entries.writeln('          <entry key="$name">');
    entries.writeln('            <value>');
    entries.writeln('              <PackageConfigEntryConfig>');
    entries.writeln('                <option name="name" value="$name" />');
    entries.writeln('                <option name="packageUri" value="$packageUri" />');
    entries.writeln('                <option name="rootUri" value="$rootUri" />');
    entries.writeln('              </PackageConfigEntryConfig>');
    entries.writeln('            </value>');
    entries.writeln('          </entry>');
  }

  File('${ideaLibDir.path}/Dart_Packages.xml').writeAsStringSync('''<?xml version="1.0" encoding="UTF-8"?>
<component name="libraryTable">
  <library name="Dart Packages" type="DartPackagesLibraryType">
    <properties>
      <option name="packageNameToConfigMap">
        <map>
$entries        </map>
      </option>
    </properties>
    <CLASSES />
    <JAVADOC />
    <SOURCES />
  </library>
</component>
''');

  final pluginsFile = File('${projectDir.path}/.flutter-plugins-dependencies');
  final pluginPaths = <String>{};
  if (pluginsFile.existsSync()) {
    final pluginsJson = jsonDecode(pluginsFile.readAsStringSync()) as Map<String, dynamic>;
    final plugins = pluginsJson['plugins'] as Map<String, dynamic>? ?? {};
    for (final platform in plugins.values) {
      for (final plugin in platform as List<dynamic>) {
        final path = (plugin as Map<String, dynamic>)['path'] as String?;
        if (path != null && path.isNotEmpty) {
          pluginPaths.add(path);
        }
      }
    }
  }

  final pluginOptionsAbs = pluginPaths.map((path) {
    final dir = path.endsWith('/') ? path : '$path/';
    return '        <option value="file://$dir" />';
  }).join('\n');

  File('${ideaLibDir.path}/Flutter_Plugins.xml').writeAsStringSync('''<?xml version="1.0" encoding="UTF-8"?>
<component name="libraryTable">
  <library name="Flutter Plugins" type="FlutterPluginsLibraryType">
    <properties>
      <option name="pluginList">
        <list>
$pluginOptionsAbs
        </list>
      </option>
    </properties>
    <CLASSES />
    <JAVADOC />
    <SOURCES />
  </library>
</component>
''');

  stdout.writeln('Generated .idea/libraries/Dart_Packages.xml and Flutter_Plugins.xml');
}
