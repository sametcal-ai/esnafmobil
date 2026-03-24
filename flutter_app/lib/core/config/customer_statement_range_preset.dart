enum CustomerStatementRangePreset {
  weekly,
  monthly,
  yearly,
  allTime,
}

CustomerStatementRangePreset customerStatementRangePresetFromString(String? value) {
  switch ((value ?? '').trim().toLowerCase()) {
    case 'weekly':
      return CustomerStatementRangePreset.weekly;
    case 'monthly':
      return CustomerStatementRangePreset.monthly;
    case 'yearly':
      return CustomerStatementRangePreset.yearly;
    case 'all_time':
      return CustomerStatementRangePreset.allTime;
    default:
      return CustomerStatementRangePreset.weekly;
  }
}

String customerStatementRangePresetToString(CustomerStatementRangePreset value) {
  switch (value) {
    case CustomerStatementRangePreset.weekly:
      return 'weekly';
    case CustomerStatementRangePreset.monthly:
      return 'monthly';
    case CustomerStatementRangePreset.yearly:
      return 'yearly';
    case CustomerStatementRangePreset.allTime:
      return 'all_time';
  }
}
