import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const maxInvestmentPrice = 999999999999;
const _storageKey = 'investment.manual_prices.v1';

final investmentManualPricesProvider =
    AsyncNotifierProvider<InvestmentManualPrices, Map<String, int>>(
      InvestmentManualPrices.new,
    );

/// Manual valuation prices are local display preferences, not cash transactions.
class InvestmentManualPrices extends AsyncNotifier<Map<String, int>> {
  @override
  Future<Map<String, int>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final entry in decoded.entries)
          if (entry.value is int &&
              (entry.value as int) > 0 &&
              (entry.value as int) <= maxInvestmentPrice)
            entry.key: entry.value as int,
      };
    } on FormatException {
      return {};
    } on TypeError {
      return {};
    }
  }

  Future<void> setPrice(String ticker, int? price) async {
    if (price != null && (price <= 0 || price > maxInvestmentPrice)) {
      throw ArgumentError('현재가는 1원 이상 $maxInvestmentPrice원 이하로 입력하세요.');
    }
    final next = {...await future};
    if (price == null) {
      next.remove(ticker);
    } else {
      next[ticker] = price;
    }
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_storageKey, jsonEncode(next))) {
      throw StateError('현재가를 저장하지 못했습니다. 다시 시도하세요.');
    }
    state = AsyncData(next);
  }
}
