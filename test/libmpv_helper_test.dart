import 'package:flutter_test/flutter_test.dart';
import 'package:exalere/services/libmpv_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('LibMpvHelper.ensureCriticalSectionsInitialized executes without throwing', () {
    expect(() => LibMpvHelper.ensureCriticalSectionsInitialized(), returnsNormally);
  });
}
