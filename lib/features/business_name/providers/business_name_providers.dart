import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/business_name_service.dart';

final businessNameServiceProvider = Provider<BusinessNameService>(
  (ref) => BusinessNameService(),
);
