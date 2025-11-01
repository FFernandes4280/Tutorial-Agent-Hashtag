#!/usr/bin/env bash
set -euo pipefail

# scripts/deps-size.sh
# Lists installed Python packages and the disk size used by each (human-readable),
# sorted by descending size. It uses the interpreter provided as first argument
# or defaults to `python3`.

PYTHON=${1:-python3}

if ! command -v "$PYTHON" >/dev/null 2>&1; then
  echo "Python interpreter '$PYTHON' not found." >&2
  exit 2
fi

echo "Using python: $($PYTHON -V 2>&1)"

# Run a Python snippet that computes sizes for each installed distribution
# based on the files reported by importlib.metadata.distributions().
echo "Computing package sizes (this may take a moment)..."

"$PYTHON" - <<'PY'
import os
import json
from importlib import metadata

def size_of_path(p):
    try:
        if p.is_file():
            return p.stat().st_size
        total = 0
        for root, dirs, files in os.walk(p):
            for f in files:
                try:
                    total += os.path.getsize(os.path.join(root, f))
                except OSError:
                    pass
        return total
    except Exception:
        return 0

results = []
for dist in metadata.distributions():
    name = dist.metadata.get('Name') or dist.metadata.get('Summary') or getattr(dist, 'name', None) or str(dist)
    seen = set()
    total = 0
    files = list(dist.files or [])
    for f in files:
        try:
            p = dist.locate_file(f)
        except Exception:
            continue
        # avoid counting duplicate file paths
        sp = os.fspath(p)
        if sp in seen:
            continue
        seen.add(sp)
        if os.path.exists(sp):
            if os.path.isfile(sp):
                try:
                    total += os.path.getsize(sp)
                except OSError:
                    pass
            else:
                total += size_of_path(p)
    # Some small packages might not list files. As a fallback, try finding top-level
    # package directories using dist.read_text('top_level.txt') if available.
    if total == 0:
        try:
            tl = dist.read_text('top_level.txt')
            if tl:
                for line in tl.splitlines():
                    line=line.strip()
                    if not line: continue
                    # locate and sum
                    p = dist.locate_file(line)
                    if os.path.exists(p):
                        total += size_of_path(p)
        except Exception:
            pass

    results.append((name, total))

# Sort descending by size
results.sort(key=lambda x: x[1], reverse=True)

def human(n):
    for unit in ['B','KB','MB','GB','TB']:
        if n < 1024.0:
            return f"{n:3.1f}{unit}"
        n /= 1024.0
    return f"{n:.1f}PB"

print(f"{'SIZE':>10}  PACKAGE")
print('-'*50)
total_sum = 0
for name, sz in results:
    print(f"{human(sz):>10}  {name}")
    total_sum += sz

# Print a summary total at the end
print('\n' + '-'*50)
print(f"Total size: {human(total_sum)} across {len(results)} packages")

PY

echo "Done."
