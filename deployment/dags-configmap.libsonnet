local pmk = (import "pmk.libsonnet");

{
  local directory_list = pmk.importDirectory("../airflow/dags", std.thisFile),

  // List of the teams with sub directory dags support.
  local supported_teams = ["fleet"],

  // Collects supported sub directories.
  local team_data = [directory_list[name]
                     for name in std.objectFields(directory_list)
                     if std.isObject(directory_list[name]) &&
                        std.setMember(name, supported_teams)],

  // merge content of the sub directories.
  local team_files = std.foldl(function(a, b) std.mergePatch(a, b),
                               team_data, []),

  // Collects root level files.
  local root_files = {
    [name]: directory_list[name]
    for name in std.objectFields(directory_list)
    if std.isString(directory_list[name])},

  data: root_files + team_files,
}
