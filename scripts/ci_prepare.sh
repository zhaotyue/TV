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
