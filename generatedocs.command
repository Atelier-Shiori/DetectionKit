cd "$(dirname "$0")"
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
jazzy \
  --objc \
  --clean \
  --author "Atelier Shiori" \
  --author_url https://ateliershiori.moe \
  --github_url https://github.com/Atelier-Shiori/DetectionKit \
  --github-file-prefix hhttps://github.com/Atelier-Shiori/DetectionKit/tree/v1.0 \
  --module-version 1.0 \
  --xcodebuild-arguments --objc,DetectionKit/DetectionKit.h,--,-x,objective-c,-isysroot,$(xcrun --show-sdk-path),-I,$(pwd) \
  --module DetectionKit \
  --root-url http://atelier-shiori.github.io/DetectionKit/ \
  --output docs/