#!/bin/sh
# Git hooks installer — symlinks hooks from toolkit/githooks/ to .git/hooks/
# Run from anywhere: sh toolkit/githooks/install.sh

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
# toolkit/githooks/ is two levels below the repo root (was one, pre-monorepo).
GIT_DIR="$(cd "$HOOKS_DIR/../.." && pwd)/.git/hooks"

echo "Installing Git hooks from $HOOKS_DIR to $GIT_DIR..."

for hook in "$HOOKS_DIR"/*; do
    name=$(basename "$hook")
    if [ "$name" = "install.sh" ]; then continue; fi
    cp "$hook" "$GIT_DIR/$name"
    chmod +x "$GIT_DIR/$name"
    echo "  ✅ $name"
done

echo "Done! Hooks will run on git checkout/merge."
