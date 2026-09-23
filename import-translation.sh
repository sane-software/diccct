#!/usr/bin/env bash
# Import a dict.cc export into SaneDictCcDictionary's data directory, so SaneDictCcDictionary picks it up on
# next launch. This mirrors the app's own import: validate the dict.cc header,
# then copy the file under its canonical name (<sorted-codes>.txt, e.g.
# de-en.txt). Use it to automate adding translation files.
#
# Usage: scripts/import-translation.sh /path/to/dictcc-export.txt
set -euo pipefail

SRC="${1:-}"
test -n "${SRC}" # fail loud: a source file argument is required
test -f "${SRC}" # fail loud: the source file must exist

# The language pair is named in a header line, e.g. "# DE-EN vocabulary database".
HEADER_LINE="$(grep -m1 -E '^#[[:space:]]*[A-Za-z]{2,3}-[A-Za-z]{2,3}[[:space:]]+vocabulary database' "${SRC}" || true)"
test -n "${HEADER_LINE}" # fail loud: not a dict.cc vocabulary file

CODE0="$(echo "${HEADER_LINE}" | sed -E 's/^#[[:space:]]*([A-Za-z]{2,3})-([A-Za-z]{2,3}).*/\1/' | tr '[:lower:]' '[:upper:]')"
CODE1="$(echo "${HEADER_LINE}" | sed -E 's/^#[[:space:]]*([A-Za-z]{2,3})-([A-Za-z]{2,3}).*/\2/' | tr '[:lower:]' '[:upper:]')"
CANONICAL="$(printf '%s\n%s\n' "${CODE0}" "${CODE1}" | sort | paste -sd- - | tr '[:upper:]' '[:lower:]')"

DEST_DIR="${HOME}/Library/Application Support/SaneDictCcDictionary"
mkdir -p "${DEST_DIR}"
cp "${SRC}" "${DEST_DIR}/${CANONICAL}.txt"
echo "Imported ${CODE0}-${CODE1} -> ${DEST_DIR}/${CANONICAL}.txt"
