import 'dart:convert';
import 'dart:io';

void main() {
  final build = Directory('build/web');
  final bootstrap = File('${build.path}/flutter_bootstrap.js');
  final worker = File('web/pwa_service_worker.js');
  final files = build
      .listSync(recursive: true)
      .whereType<File>()
      .map((file) =>
          file.path.substring(build.path.length + 1).replaceAll('\\', '/'))
      .where((path) =>
          !path.split('/').any((part) => part.startsWith('.')) &&
          !path.endsWith('.symbols') &&
          !path.endsWith('service_worker.js'))
      .toList()
    ..sort();
  const requiredFiles = [
    'index.html',
    'flutter_bootstrap.js',
    'main.dart.js',
    'print_setup.js',
    'canvaskit/canvaskit.wasm',
    'assets/assets/data/cards.json',
  ];
  if (!requiredFiles.every(files.contains)) {
    throw StateError(
        'Run flutter build web --release before preparing the offline cache.');
  }

  final script = bootstrap.readAsStringSync();
  const marker = '/* kingdom-release */';
  if (!script.contains(marker)) {
    throw StateError('Missing release marker in Flutter bootstrap.');
  }
  final release =
      jsonEncode({'id': DateTime.now().microsecondsSinceEpoch, 'files': files});
  File('${build.path}/pwa_service_worker.js').writeAsStringSync(worker
      .readAsStringSync()
      .replaceFirst('const release = null;', 'const release = $release;'));
  bootstrap
      .writeAsStringSync(script.replaceFirst('$marker false', '$marker true'));
  stdout.writeln('Prepared ${files.length} assets for offline web use.');
}
