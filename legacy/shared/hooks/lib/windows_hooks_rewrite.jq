.hooks |= with_entries(
  .value |= map(
    .command = (
      "powershell -NoProfile -ExecutionPolicy Bypass -File \""
      + $shim
      + "\" "
      + (.command | split("/") | last)
    )
  )
)
