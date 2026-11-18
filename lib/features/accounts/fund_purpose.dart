const fundPurposeLabels = {
  'living': '생활비',
  'emergency': '비상금',
  'annual': '연간 지출 준비금',
};

String normalizeFundPurpose(String? value) =>
    fundPurposeLabels.containsKey(value) ? value! : 'living';
