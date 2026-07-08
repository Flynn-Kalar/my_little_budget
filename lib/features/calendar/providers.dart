import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';

final calendarEventsProvider = StreamProvider.autoDispose<List<CalendarEvent>>(
  (ref) => ref.watch(calendarEventsDaoProvider).watchEvents(),
);

void refreshCalendarEvents(WidgetRef ref) {
  ref.invalidate(calendarEventsProvider);
}
