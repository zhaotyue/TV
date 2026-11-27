#!/usr/bin/env bash
set -euo pipefail

groovy="buildSrc/src/main/groovy/com/fongmi/gradle/AbiApkPackaging.groovy"
if [ -f "$groovy" ]; then
  sed -i 's/.*mpvArchive.*/\/\/ disabled mpvArchive/g' "$groovy"
fi

keystore_path="$PWD/ci-release.jks"
keytool -genkeypair -v \
  -keystore "$keystore_path" \
  -alias tvrelease \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -storepass 123456 \
  -keypass 123456 \
  -dname "CN=TV, OU=CI, O=TV, L=City, ST=State, C=CN"

sdk_path="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"
printf "sdk.dir=%s\nstoreFile=%s\nkeyAlias=tvrelease\nstorePassword=123456\n" \
  "$sdk_path" "$keystore_path" > local.properties

python3 - <<'PY'
import os
import re

gradle_path = "app/build.gradle"
with open(gradle_path, "r", encoding="utf-8", errors="ignore") as f:
    content = f.read()

if "androidx.media3:media3-exoplayer" not in content:
    dep_block = """
dependencies {
    def m3 = "1.5.1"
    implementation "androidx.media3:media3-exoplayer:${m3}"
    implementation "androidx.media3:media3-ui:${m3}"
    implementation "androidx.media3:media3-session:${m3}"
    implementation "androidx.media3:media3-datasource:${m3}"
    implementation "androidx.media3:media3-datasource-okhttp:${m3}"
    implementation "androidx.media3:media3-extractor:${m3}"
    implementation "androidx.media3:media3-common:${m3}"
}
"""
    with open(gradle_path, "w", encoding="utf-8") as f:
        f.write(content + dep_block)

ids = {
    "exo_duration", "exo_position", "exo_progress", "exo_play", "exo_pause",
    "exo_ffwd", "exo_rew", "exo_prev", "exo_next", "exo_subtitle",
    "exo_settings", "exo_fullscreen", "exo_buffering", "exo_artwork",
    "exo_shutter", "exo_content_frame", "exo_error_message"
}
pattern = re.compile(r"\bexo_[a-zA-Z0-9_]+\b")
for root, _, files in os.walk("."):
    norm = root.replace("\\", "/")
    if "/build/" in norm or "/.git/" in norm:
        continue
    for fn in files:
        if fn.endswith((".xml", ".java", ".kt")):
            fp = os.path.join(root, fn)
            try:
                with open(fp, "r", encoding="utf-8", errors="ignore") as f:
                    ids.update(pattern.findall(f.read()))
            except OSError:
                pass

lines = ['<?xml version="1.0" encoding="utf-8"?>', "<resources>"]
for name in sorted(ids):
    lines.append(f'    <item type="id" name="{name}" />')
lines.append("</resources>")
xml_text = "\n".join(lines) + "\n"

for target_dir in ["app/src/main/res/values", "catvod/src/main/res/values"]:
    if os.path.isdir(os.path.dirname(target_dir)):
        os.makedirs(target_dir, exist_ok=True)
        with open(os.path.join(target_dir, "ci_fix_ids.xml"), "w", encoding="utf-8") as f:
            f.write(xml_text)
PY
