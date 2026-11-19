/// Which alerts the Alerts page shows.
enum AlertFilter {
  all('All'),
  reports('Reports'),
  points('Points');

  const AlertFilter(this.label);

  final String label;
}

/// Whether the user's report status cards appear under [filter].
bool showsReportCards(AlertFilter filter) => filter != AlertFilter.points;

/// Whether an alert of [type] ('Points', 'Report Update', …) appears under
/// [filter].
bool alertMatches(AlertFilter filter, String type) => switch (filter) {
  AlertFilter.all => true,
  AlertFilter.reports => type == 'Report Update',
  AlertFilter.points => type == 'Points' || type == 'Level Up',
};
