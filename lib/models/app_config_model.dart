class AppConfigEntry {
  final String key;
  final String value;

  const AppConfigEntry({required this.key, required this.value});

  factory AppConfigEntry.fromSqlite(Map<String, dynamic> row) => AppConfigEntry(
        key: row['key'] as String,
        value: row['value'] as String,
      );
}
