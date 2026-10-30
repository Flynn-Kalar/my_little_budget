import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/date.dart';
import '../../features/settings/statement_period.dart';

class StatementPeriodSettings extends ConsumerWidget {
  const StatementPeriodSettings({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(statementPeriodProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: settings.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, s) => const Text('집계 시작일 설정을 불러오지 못했습니다.'),
          data: (value) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '내역 월별 집계 시작일',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                key: ValueKey('statement-day-${value.day}'),
                initialValue: value.day,
                decoration: const InputDecoration(labelText: '시작일'),
                items: [
                  for (var day = 1; day <= 31; day++)
                    DropdownMenuItem(value: day, child: Text('매월 $day일')),
                  const DropdownMenuItem(value: 0, child: Text('월 마지막 날')),
                ],
                onChanged: (day) async {
                  if (day != null) {
                    await _save(
                      context,
                      ref,
                      StatementPeriod(day: day, adjustment: value.adjustment),
                    );
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('statement-adjustment-${value.adjustment}'),
                initialValue: value.adjustment,
                decoration: const InputDecoration(labelText: '주말·공휴일 처리'),
                items: const [
                  DropdownMenuItem(value: 'same', child: Text('지정일 그대로')),
                  DropdownMenuItem(value: 'previous', child: Text('이전 영업일')),
                  DropdownMenuItem(value: 'next', child: Text('다음 영업일')),
                ],
                onChanged: (adjustment) async {
                  if (adjustment != null) {
                    await _save(
                      context,
                      ref,
                      StatementPeriod(day: value.day, adjustment: adjustment),
                    );
                  }
                },
              ),
              const SizedBox(height: 12),
              const Text(
                '해당 월 시작일부터 다음 월 시작일 전날까지 집계합니다. 없는 날짜는 월말을 사용합니다. 영업일은 토·일요일과 대한민국 공휴일을 제외합니다.',
              ),
              const SizedBox(height: 8),
              Text(
                '이번 달: ${value.range(currentMonthKey()).start} ~ ${value.range(currentMonthKey()).end}',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    StatementPeriod value,
  ) async {
    try {
      await ref.read(statementPeriodProvider.notifier).save(value);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('설정을 저장하지 못했습니다. 다시 시도하세요.')),
        );
      }
    }
  }
}
