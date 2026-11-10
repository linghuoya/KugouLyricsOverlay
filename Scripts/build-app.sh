#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
PRODUCT="KugouLyricsOverlay"
APP="$ROOT/$PRODUCT.app"
CONTENTS="$APP/Contents"

cd "$ROOT"
swift build -c release --product "$PRODUCT"
mkdir -p "$CONTENTS/MacOS"
cp "$ROOT/.build/release/$PRODUCT" "$CONTENTS/MacOS/$PRODUCT"
cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"
plutil -lint "$CONTENTS/Info.plist"
codesign --force --sign - "$APP"
print "Built: $APP"
