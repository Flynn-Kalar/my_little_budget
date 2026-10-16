import 'dart:convert';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/providers.dart';
import '../../../features/notes/providers.dart';
import '../../../features/notes/reminder_store.dart';

class MobileReminderHistory extends ConsumerWidget {
  const MobileReminderHistory({super.key, required this.noteId});
  final int noteId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton.icon(
      icon: const Icon(Icons.history),
      label: const Text('이전 회차'),
      onPressed: () async {
        final db = ref.read(appDatabaseProvider);
        final rows = await db
            .customSelect(
              '''SELECT * FROM reminder_occurrences
        WHERE note_id=? AND (scheduled_at<=? OR status<>'pending')
        ORDER BY scheduled_at DESC LIMIT 60''',
              variables: [
                Variable(noteId),
                Variable(DateTime.now().millisecondsSinceEpoch),
              ],
            )
            .get();
        if (!context.mounted) return;
        await showModalBottomSheet<void>(
          context: context,
          useSafeArea: true,
          isScrollControlled: true,
          builder: (sheet) => SizedBox(
            height: MediaQuery.sizeOf(sheet).height * .65,
            child: rows.isEmpty
                ? const Center(child: Text('이전 회차가 없습니다.'))
                : ListView(
                    children: [
                      const ListTile(
                        title: Text('이전 회차'),
                        subtitle: Text('완료 취소해도 지난 알림은 다시 울리지 않습니다.'),
                      ),
                      for (final row in rows)
                        ExpansionTile(
                          title: Text(row.read<String>('occurrence_key')),
                          subtitle: Text(switch (row.read<String>('status')) {
                            'completed' => '완료',
                            'skipped' => '건너뜀',
                            _ => '미완료',
                          }),
                          children: [
                            for (final item
                                in (jsonDecode(
                                          row.read<String>('checklist_json'),
                                        )
                                        as List)
                                    .cast<Map>())
                              ListTile(
                                dense: true,
                                title: Text('${item['text']}'),
                                leading: Icon(
                                  item['checked'] == true
                                      ? Icons.check_box
                                      : Icons.check_box_outline_blank,
                                ),
                              ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                for (final action in {
                                  'completed': '완료',
                                  'pending': '완료 취소',
                                  'skipped': '건너뛰기',
                                }.entries)
                                  if (action.key != row.read<String>('status'))
                                    TextButton(
                                      child: Text(action.value),
                                      onPressed: () async {
                                        await ReminderStore(
                                          db,
                                        ).setOccurrenceStatus(
                                          row.read<int>('id'),
                                          action.key,
                                        );
                                        await rebuildNoteNotifications(ref);
                                        if (sheet.mounted) Navigator.pop(sheet);
                                      },
                                    ),
                              ],
                            ),
                          ],
                        ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
