#!/usr/bin/env zsh
set -e
# 项目目录
PROJECT_HOME=${0:a:h}


OLD_BUILD_DIR="$PROJECT_HOME/.build"
BUILD_DIR="$PROJECT_HOME/build"
if [ "$OLD_BUILD_DIR" ] && [ "$OLD_BUILD_DIR" != "/" ] && [ -d "$OLD_BUILD_DIR" ]; then
    /bin/rm -rf "$OLD_BUILD_DIR"
fi
if [ "$BUILD_DIR" ] && [ "$BUILD_DIR" != "/" ] && [ -d "$BUILD_DIR" ]; then
    /bin/rm -rf "$BUILD_DIR"
fi
mkdir -p "$OLD_BUILD_DIR" || :
cp -rf "$PROJECT_HOME"/* "$OLD_BUILD_DIR"
mv "$OLD_BUILD_DIR" "$BUILD_DIR"
cd "$BUILD_DIR"
for data in **/*.adoc; do
    SRC_PATH="$BUILD_DIR/$data"
    SRC_DIRECTORY="$(dirname "${SRC_PATH}")"
    SRC_FILE_NAME="$(basename "${SRC_PATH}")"
    DIST_FILE_NAME=${SRC_FILE_NAME//.adoc/.html}
    mkdir -p "$SRC_DIRECTORY" || : 2>/dev/null
    #    echo $SRC_DIRECTORY
    asciidoctor -a nofooter --safe-mode unsafe -r asciidoctor-kroki --out-file "$SRC_DIRECTORY/$DIST_FILE_NAME" "$SRC_DIRECTORY/$SRC_FILE_NAME"
    sed -i 's/.adoc">/.html">/g' "$SRC_DIRECTORY/$DIST_FILE_NAME"
done
/bin/rm -f "$BUILD_DIR"/zz-MENU.html
asciidoctor --safe-mode unsafe -r asciidoctor-kroki --no-header-footer \
    --out-file "$BUILD_DIR"/zz-MENU.html "$BUILD_DIR"/zz-MENU.adoc
sed -i 's/.adoc">/.html">/g' "$BUILD_DIR"/zz-MENU.html
sed -i 's/<a href="/<a target="dist" href="/g' "$BUILD_DIR"/zz-MENU.html
sed -i 's|src="./build/|src="./|g' "$BUILD_DIR"/index.html
sed -i 's|href="./build/|href="./|g' "$BUILD_DIR"/index.html
echo "build finish ！ dist dir : $BUILD_DIR"/ .
