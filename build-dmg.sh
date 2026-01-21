#!/bin/bash

# =============================================================================
# DB-Claude DMG 打包脚本
# =============================================================================
# 用法:
#   ./build-dmg.sh              # 默认打包（不签名）
#   ./build-dmg.sh --sign       # 打包并签名（需要开发者证书）
#   ./build-dmg.sh --notarize   # 打包、签名并公证（需要 App Store Connect API Key）
#
# 输出:
#   dist/DB-Claude-<version>.dmg
# =============================================================================

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
APP_NAME="DB-Claude"
SCHEME="DB-Claude"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
XCODE_PROJECT="$PROJECT_DIR/DB-Claude/DB-Claude.xcodeproj"
BUILD_DIR="$PROJECT_DIR/build"
DIST_DIR="$PROJECT_DIR/dist"
DMG_STAGING_DIR="$BUILD_DIR/dmg-staging"

# 解析命令行参数
SIGN_APP=false
NOTARIZE_APP=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --sign) SIGN_APP=true ;;
        --notarize) SIGN_APP=true; NOTARIZE_APP=true ;;
        -h|--help)
            echo "用法: $0 [选项]"
            echo ""
            echo "选项:"
            echo "  --sign       对 App 进行代码签名"
            echo "  --notarize   签名并提交 Apple 公证"
            echo "  -h, --help   显示帮助信息"
            exit 0
            ;;
        *) echo -e "${RED}未知参数: $1${NC}"; exit 1 ;;
    esac
    shift
done

# 打印带颜色的消息
print_step() {
    echo -e "${BLUE}==>${NC} ${GREEN}$1${NC}"
}

print_warning() {
    echo -e "${YELLOW}警告:${NC} $1"
}

print_error() {
    echo -e "${RED}错误:${NC} $1"
}

# 获取版本号
get_version() {
    local info_plist="$PROJECT_DIR/DB-Claude/DB-Claude/Info.plist"
    if [ -f "$info_plist" ]; then
        /usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$info_plist" 2>/dev/null || echo "1.0.0"
    else
        # 尝试从 xcodebuild 获取
        xcodebuild -project "$XCODE_PROJECT" -scheme "$SCHEME" -showBuildSettings 2>/dev/null | \
            grep "MARKETING_VERSION" | head -1 | awk '{print $3}' || echo "1.0.0"
    fi
}

# 清理之前的构建
clean_build() {
    print_step "清理之前的构建..."
    rm -rf "$BUILD_DIR"
    rm -rf "$DMG_STAGING_DIR"
    mkdir -p "$BUILD_DIR"
    mkdir -p "$DIST_DIR"
    mkdir -p "$DMG_STAGING_DIR"
}

# 构建 Release 版本
build_app() {
    print_step "构建 Release 版本..."
    
    xcodebuild -project "$XCODE_PROJECT" \
        -scheme "$SCHEME" \
        -configuration Release \
        -derivedDataPath "$BUILD_DIR/DerivedData" \
        -destination "generic/platform=macOS" \
        ONLY_ACTIVE_ARCH=NO \
        clean build
    
    # 查找构建产物
    APP_PATH=$(find "$BUILD_DIR/DerivedData" -name "$APP_NAME.app" -type d | head -1)
    
    if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
        print_error "未找到构建产物 $APP_NAME.app"
        exit 1
    fi
    
    print_step "构建完成: $APP_PATH"
}

# 代码签名
sign_app() {
    if [ "$SIGN_APP" = true ]; then
        print_step "对 App 进行代码签名..."
        
        # 查找可用的开发者证书
        IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | awk -F'"' '{print $2}')
        
        if [ -z "$IDENTITY" ]; then
            print_warning "未找到 Developer ID Application 证书，跳过签名"
            SIGN_APP=false
            return
        fi
        
        print_step "使用证书: $IDENTITY"
        
        # 签名 App
        codesign --force --deep --sign "$IDENTITY" \
            --options runtime \
            --entitlements "$PROJECT_DIR/DB-Claude/DB-Claude/DB-Claude.entitlements" \
            "$APP_PATH"
        
        # 验证签名
        codesign --verify --deep --strict "$APP_PATH"
        print_step "签名验证通过"
    fi
}

# 创建 DMG
create_dmg() {
    VERSION=$(get_version)
    DMG_NAME="$APP_NAME-$VERSION.dmg"
    DMG_PATH="$DIST_DIR/$DMG_NAME"
    
    print_step "创建 DMG: $DMG_NAME"
    
    # 准备 DMG 内容
    cp -R "$APP_PATH" "$DMG_STAGING_DIR/"
    
    # 创建 Applications 链接
    ln -s /Applications "$DMG_STAGING_DIR/Applications"
    
    # 创建临时 DMG（可读写）
    TEMP_DMG="$BUILD_DIR/temp.dmg"
    rm -f "$TEMP_DMG"
    
    hdiutil create -srcfolder "$DMG_STAGING_DIR" \
        -volname "$APP_NAME" \
        -fs HFS+ \
        -fsargs "-c c=64,a=16,e=16" \
        -format UDRW \
        "$TEMP_DMG"
    
    # 挂载临时 DMG
    MOUNT_DIR="/Volumes/$APP_NAME"
    
    # 确保挂载点不存在（防止冲突）
    if [ -d "$MOUNT_DIR" ]; then
        print_warning "发现已存在的挂载点，尝试卸载..."
        hdiutil detach "$MOUNT_DIR" -force 2>/dev/null || true
        sleep 1
    fi
    
    # 挂载 DMG，获取设备节点用于后续卸载
    ATTACH_OUTPUT=$(hdiutil attach -readwrite -noverify "$TEMP_DMG")
    DEVICE_NODE=$(echo "$ATTACH_OUTPUT" | grep '/dev/disk' | head -1 | awk '{print $1}')
    
    # 等待挂载完成
    sleep 2
    
    if [ ! -d "$MOUNT_DIR" ]; then
        print_error "DMG 挂载失败"
        exit 1
    fi
    
    print_step "DMG 已挂载到: $MOUNT_DIR (设备: $DEVICE_NODE)"
    
    # 设置 DMG 窗口样式（使用 AppleScript，超时不影响功能）
    # 注意：AppleScript 可能超时，这是正常的
    (
        osascript <<EOF
tell application "Finder"
    tell disk "$APP_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 100, 920, 440}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 80
        set position of item "$APP_NAME.app" of container window to {130, 150}
        set position of item "Applications" of container window to {390, 150}
        close
    end tell
end tell
EOF
    ) 2>/dev/null || print_warning "无法设置 DMG 窗口样式（这不影响功能）"
    
    sync
    sleep 1
    
    # 确保 Finder 释放 DMG
    osascript -e 'tell application "Finder" to close every window' 2>/dev/null || true
    sleep 1
    
    # 卸载 DMG（使用设备节点更可靠）
    print_step "卸载 DMG..."
    if [ -n "$DEVICE_NODE" ]; then
        hdiutil detach "$DEVICE_NODE" -force 2>/dev/null || hdiutil detach "$MOUNT_DIR" -force 2>/dev/null || true
    else
        hdiutil detach "$MOUNT_DIR" -force 2>/dev/null || true
    fi
    
    # 等待卸载完成
    sleep 2
    
    # 确认已卸载
    if [ -d "$MOUNT_DIR" ]; then
        print_warning "挂载点仍存在，强制卸载..."
        diskutil unmount force "$MOUNT_DIR" 2>/dev/null || true
        sleep 2
    fi
    
    # 转换为压缩的只读 DMG
    rm -f "$DMG_PATH"
    hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH"
    
    # 清理
    rm -f "$TEMP_DMG"
    
    print_step "DMG 创建完成: $DMG_PATH"
    
    # 显示文件大小
    DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)
    echo -e "${GREEN}文件大小: $DMG_SIZE${NC}"
}

# Apple 公证
notarize_dmg() {
    if [ "$NOTARIZE_APP" = true ]; then
        print_step "提交 Apple 公证..."
        
        # 需要配置以下环境变量:
        # APPLE_ID - Apple ID 邮箱
        # APPLE_APP_PASSWORD - App 专用密码
        # APPLE_TEAM_ID - 开发者团队 ID
        
        if [ -z "$APPLE_ID" ] || [ -z "$APPLE_APP_PASSWORD" ] || [ -z "$APPLE_TEAM_ID" ]; then
            print_warning "未设置公证所需的环境变量，跳过公证"
            echo "需要设置: APPLE_ID, APPLE_APP_PASSWORD, APPLE_TEAM_ID"
            return
        fi
        
        xcrun notarytool submit "$DMG_PATH" \
            --apple-id "$APPLE_ID" \
            --password "$APPLE_APP_PASSWORD" \
            --team-id "$APPLE_TEAM_ID" \
            --wait
        
        # 装订公证票据
        xcrun stapler staple "$DMG_PATH"
        
        print_step "公证完成"
    fi
}

# 主流程
main() {
    echo ""
    echo "================================================"
    echo "  $APP_NAME DMG 打包工具"
    echo "================================================"
    echo ""
    
    clean_build
    build_app
    sign_app
    create_dmg
    notarize_dmg
    
    echo ""
    echo "================================================"
    echo -e "  ${GREEN}✓ 打包完成！${NC}"
    echo "  输出文件: $DMG_PATH"
    echo "================================================"
    echo ""
    
    # 在 Finder 中显示
    open -R "$DMG_PATH"
}

main "$@"
