import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

/// Golden comparator that tolerates a small share of different pixels.
///
/// Goldens are rendered on whatever platform runs the test. Font hinting and
/// anti-aliasing differ between Windows and the Linux CI image, which turned
/// every golden into a ~1 % pixel diff and a red run for unchanged UI. This
/// comparator still fails on real regressions: anything above [tolerance] of
/// differing pixels fails, and the error reports the measured percentage.
class TolerantGoldenFileComparator extends GoldenFileComparator {
  TolerantGoldenFileComparator(this.basedir, {this.tolerance = 0.02});

  /// Directory the relative golden paths resolve against.
  final Uri basedir;

  /// Allowed share of differing pixels (0.02 = 2 %).
  final double tolerance;

  /// Resolves a golden, accepting both `<basedir>/goldens/x.png` and
  /// `<basedir>/test/goldens/x.png` because the default basedir depends on how
  /// the test was started.
  File resolveFile(Uri golden) {
    final direct = File.fromUri(basedir.resolveUri(golden));
    if (direct.existsSync()) return direct;
    final underTest = File.fromUri(basedir.resolve('test/').resolveUri(golden));
    if (underTest.existsSync()) return underTest;
    return direct;
  }

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final file = resolveFile(golden);
    if (!file.existsSync()) {
      throw TestFailure(
        'Golden "$golden" not found (looked in ${file.path}). '
        'Run with --update-goldens to create it.',
      );
    }

    final expectedBytes = await file.readAsBytes();
    final actual = await _decode(imageBytes);
    final expected = await _decode(expectedBytes);

    if (actual.width != expected.width || actual.height != expected.height) {
      throw TestFailure(
        'Golden "$golden" is ${expected.width}x${expected.height} but the '
        'widget rendered ${actual.width}x${actual.height}.',
      );
    }

    final actualPixels = await _rgba(actual);
    final expectedPixels = await _rgba(expected);
    final total = actual.width * actual.height;

    var differing = 0;
    for (var i = 0; i < total; i++) {
      final offset = i * 4;
      var delta = 0;
      for (var channel = 0; channel < 3; channel++) {
        delta +=
            (actualPixels[offset + channel] - expectedPixels[offset + channel])
                .abs();
      }
      // Ignore low-bit noise; only count a visibly different pixel.
      if (delta > 24) differing++;
    }

    final ratio = differing / total;
    if (ratio > tolerance) {
      throw TestFailure(
        'Golden "$golden" differs by ${(ratio * 100).toStringAsFixed(2)}% '
        '(tolerance ${(tolerance * 100).toStringAsFixed(0)}%). '
        'Run with --update-goldens after reviewing the render.',
      );
    }
    if (ratio > 0.001) {
      // ignore: avoid_print
      print(
        'Golden $golden differs by ${(ratio * 100).toStringAsFixed(2)}% '
        '(within tolerance).',
      );
    }
    return true;
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) async {
    final file = resolveFile(golden);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(imageBytes, flush: true);
  }

  @override
  Uri getTestUri(Uri key, int? version) => key;

  Future<ui.Image> _decode(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  Future<Uint8List> _rgba(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return data!.buffer.asUint8List();
  }
}

/// Installs the tolerant comparator for the current test process.
void useTolerantGoldens({double tolerance = 0.02}) {
  TestWidgetsFlutterBinding.ensureInitialized();
  final previous = goldenFileComparator;
  final basedir = previous is LocalFileComparator
      ? previous.basedir
      : Uri.directory('${Directory.current.path}${Platform.pathSeparator}');
  goldenFileComparator = TolerantGoldenFileComparator(
    basedir,
    tolerance: tolerance,
  );
}
