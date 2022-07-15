#!/usr/bin/env zsh
set -e
# 项目目录
PROJECT_HOME=${0:a:h}
# 编译目录
BUILD_DIR="$PROJECT_HOME/build"
# 尾部模板位置
FOOTER_TEMPLATE_PATH="$BUILD_DIR/docinfo-footer.html"
SRC_FOOTER_TEMPLATE_PATH="$PROJECT_HOME/docinfo-footer.html"

generate_info() {
# shellcheck disable=SC2155
    export GIT_COMMIT_ID=$(git rev-parse HEAD || :)
# shellcheck disable=SC2155
    export GIT_COMMIT_SHORT_ID=$(git rev-parse --short HEAD || :)
# shellcheck disable=SC2155
    export DATE=$(date)
    envsubst <"$SRC_FOOTER_TEMPLATE_PATH" >"$FOOTER_TEMPLATE_PATH"
}

setup_build() {
    OLD_BUILD_DIR="$PROJECT_HOME/.build"
    if [ "$OLD_BUILD_DIR" ] && [ "$OLD_BUILD_DIR" != "/" ] && [ -d "$OLD_BUILD_DIR" ]; then
        /bin/rm -rf "$OLD_BUILD_DIR"
    fi
    if [ "$BUILD_DIR" ] && [ "$BUILD_DIR" != "/" ] && [ -d "$BUILD_DIR" ]; then
        /bin/rm -rf "$BUILD_DIR"
    fi
    mkdir -p "$OLD_BUILD_DIR" || :
    cp -rf "$PROJECT_HOME"/* "$OLD_BUILD_DIR"
    mv "$OLD_BUILD_DIR" "$BUILD_DIR"
}

build_doc() {
    if [ ! "$1" ]; then
        return 1
    fi
    SRC_PATH=$1
    if [ ! "$2" ]; then
        SRC_DIRECTORY="$(dirname "${SRC_PATH}")"
        SRC_FILE_NAME="$(basename "${SRC_PATH}")"
        DIST_FILE_NAME=${SRC_FILE_NAME//.adoc/.html}
        DIST_PATH="$SRC_DIRECTORY/$DIST_FILE_NAME"
    else
        DIST_PATH=$2
    fi
    DIST_DIRECTORY="$(dirname "${DIST_PATH}")"
    # 创建导出目录
    mkdir -p "$DIST_DIRECTORY" || : 2>/dev/null
    # 编译文件
    asciidoctor \
        --attribute "nofooter" \
        --attribute "toc=right" \
        --attribute "docinfo=shared-footer" \
        --attribute "docinfodir=$BUILD_DIR" \
        --safe-mode unsafe -r asciidoctor-kroki \
        --out-file "$DIST_PATH" "$SRC_PATH"
    # 更新配置
    sed -i 's/.adoc">/.html">/g' "$DIST_PATH"
}

build_article() {
    cd "$BUILD_DIR"
    for data in **/*.adoc; do
        build_doc "$BUILD_DIR/$data"
    done

}

build_menu() {
    /bin/rm -f "$BUILD_DIR"/zz-MENU.html
    asciidoctor --safe-mode unsafe \
            --attribute "docinfo=menu" \
        -r asciidoctor-kroki --no-header-footer  \
        --out-file "$BUILD_DIR"/zz-MENU.html "$BUILD_DIR"/zz-MENU.adoc
    sed -i 's/.adoc">/.html">/g' "$BUILD_DIR"/zz-MENU.html
    sed -i 's/<a href="/<a target="dist" href="/g' "$BUILD_DIR"/zz-MENU.html
}

build_index() {
    sed -i 's|src="./build/|src="./|g' "$BUILD_DIR"/index.html
    sed -i 's|href="./build/|href="./|g' "$BUILD_DIR"/index.html
}

case $1 in
menu)
    build_menu
    ;;
main)
    generate_info
    build_doc "$BUILD_DIR/MAIN.adoc"
    ;;
*)
    setup_build
    generate_info
    build_article
    build_menu
    build_index
    ;;
esac

echo "编译完成 导出目录为: $BUILD_DIR"/ .
