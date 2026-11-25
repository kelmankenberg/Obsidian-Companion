function primary(tab, title, taskText, path) {
  if (tab === "tasks") return taskText || title || path
  return title || taskText || path
}
