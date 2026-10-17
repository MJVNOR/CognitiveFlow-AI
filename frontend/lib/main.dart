// Entry point: solo bootstrap (la fuente vive en app/app.dart).
import 'app/app.dart';

export 'app/app.dart';
export 'config/routing/router.dart';
export 'ui/core/shell.dart';

Future<void> main() => bootstrap();
