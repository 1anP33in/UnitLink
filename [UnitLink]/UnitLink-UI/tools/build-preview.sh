#!/usr/bin/env bash
# Rebuilds preview.html with html/style.css and html/js/*.js inlined,
# so it opens anywhere (double-click, browser pane) without a server.
cd "$(dirname "$0")/.."
awk '
  /<link rel="stylesheet" href="html\/style.css">/ { print "<style>"; while ((getline l < "html/style.css") > 0) print l; print "</style>"; next }
  match($0, /<script src="(html\/js\/[a-z]+\.js)"><\/script>/) {
    f = substr($0, RSTART + 13, RLENGTH - 13 - 11)
    print "<script>"; while ((getline l < f) > 0) print l; close(f); print "</script>"; next
  }
  { print }
' tools/preview.template.html > preview.html
echo "preview.html rebuilt"
