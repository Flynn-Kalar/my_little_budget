import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database.dart';
import '../../../data/providers.dart';

final allCategoriesProvider = FutureProvider.autoDispose<List<Category>>(
  (ref) => ref.watch(categoriesDaoProvider).getAllCategories(),
);

final settingsTagsProvider = FutureProvider.autoDispose<List<Tag>>(
  (ref) => ref.watch(tagsDaoProvider).getTags(),
);

void refreshCategories(WidgetRef ref) {
  ref.invalidate(allCategoriesProvider);
}

void refreshTags(WidgetRef ref) {
  ref.invalidate(settingsTagsProvider);
}
