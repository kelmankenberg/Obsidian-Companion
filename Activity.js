function changedCount(current, baseline) {
  if (baseline === null) return 0
  var changed = 0
  var paths = Object.keys(current)
  for (var i = 0; i < paths.length; i++) {
    var path = paths[i]
    if (!Object.prototype.hasOwnProperty.call(baseline, path)
        || current[path] !== baseline[path]) changed++
  }
  return changed
}
