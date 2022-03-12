#! /bin/sh

xcodebuild docbuild -scheme FluidInterfaceKit -derivedDataPath .build -destination 'generic/platform=iOS'

ARCHIVE_PATH=".build/Build/Products/Debug-iphoneos/FluidInterfaceKit.doccarchive"

$(xcrun --find docc) process-archive \
transform-for-static-hosting $ARCHIVE_PATH \
--output-path Docs \
--hosting-base-path "muukii.github.com/FluidInterfaceKit"
