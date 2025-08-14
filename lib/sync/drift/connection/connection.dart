// Platform-conditional export for opening the drift database connection.
// Web -> WebDatabase (IndexedDB). Others -> drift_flutter helper.

export 'connection_web.dart' if (dart.library.io) 'connection_native.dart';
