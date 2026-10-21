import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Account data depends on this value so a new session cannot inherit caches.
final accountSessionProvider = StateProvider<int>((ref) => 0);
