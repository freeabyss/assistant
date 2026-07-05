#!/bin/bash

# Qingniao 构建并启动脚本
# 用法: ./build_and_run.sh [clean|build|run|all]

set -e  # 遇到错误立即退出

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="Qingniao"
SCHEME_NAME="Qingniao"
DERIVED_DATA_PATH="${PROJECT_DIR}/DerivedData"
APP_PATH="${DERIVED_DATA_PATH}/Build/Products/Debug/Qingniao.app"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 清理构建目录
clean_build() {
    log_info "清理构建目录..."
    if [ -d "${DERIVED_DATA_PATH}" ]; then
        rm -rf "${DERIVED_DATA_PATH}"
        log_success "已清理 DerivedData 目录"
    else
        log_info "DerivedData 目录不存在，跳过清理"
    fi
}

# 编译项目
build_project() {
    log_info "开始编译 ${PROJECT_NAME}..."

    # 检查 Xcode 是否安装
    if ! command -v xcodebuild &> /dev/null; then
        log_error "未找到 xcodebuild，请确保已安装 Xcode"
        exit 1
    fi

    # 检查 Xcode 许可证状态
    if ! xcodebuild -license check &> /dev/null; then
        log_warn "Xcode 许可证可能未接受，尝试编译..."
    fi

    # 使用 xcodebuild 编译
    xcodebuild \
        -project "${PROJECT_DIR}/${PROJECT_NAME}.xcodeproj" \
        -scheme "${SCHEME_NAME}" \
        -configuration Debug \
        -derivedDataPath "${DERIVED_DATA_PATH}" \
        -quiet \
        2>&1 | while IFS= read -r line; do
            # 过滤并高亮重要信息
            if [[ "$line" == *"error:"* ]]; then
                echo -e "${RED}$line${NC}"
            elif [[ "$line" == *"warning:"* ]]; then
                echo -e "${YELLOW}$line${NC}"
            elif [[ "$line" == *"BUILD SUCCEEDED"* ]]; then
                echo -e "${GREEN}$line${NC}"
            elif [[ "$line" == *"BUILD FAILED"* ]]; then
                echo -e "${RED}$line${NC}"
            else
                echo "$line"
            fi
        done

    # 检查编译结果
    if [ $? -eq 0 ]; then
        log_success "编译成功完成"
        return 0
    else
        log_error "编译失败"
        return 1
    fi
}

# 启动应用
run_app() {
    log_info "启动 ${PROJECT_NAME}..."

    # 检查 .app 文件是否存在
    if [ ! -d "${APP_PATH}" ]; then
        log_error "未找到编译后的应用: ${APP_PATH}"
        log_info "请先运行编译: $0 build"
        exit 1
    fi

    # 使用 open 命令启动应用
    open "${APP_PATH}"

    # 等待应用启动
    sleep 2

    # 检查应用是否正在运行
    if pgrep -x "${PROJECT_NAME}" > /dev/null; then
        log_success "${PROJECT_NAME} 已启动"
    else
        log_warn "${PROJECT_NAME} 可能未正确启动，请检查控制台日志"
    fi
}

# 显示帮助信息
show_help() {
    echo "Qingniao 构建并启动脚本"
    echo ""
    echo "用法: $0 [命令]"
    echo ""
    echo "命令:"
    echo "  clean    清理构建目录"
    echo "  build    编译项目"
    echo "  run      启动应用（需要先编译）"
    echo "  all      清理、编译并启动（默认）"
    echo "  help     显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0          # 清理、编译并启动"
    echo "  $0 build    # 仅编译"
    echo "  $0 run      # 仅启动"
    echo "  $0 clean    # 仅清理"
}

# 主函数
main() {
    cd "${PROJECT_DIR}"

    case "${1:-all}" in
        clean)
            clean_build
            ;;
        build)
            build_project
            ;;
        run)
            run_app
            ;;
        all)
            clean_build
            if build_project; then
                run_app
            else
                log_error "编译失败，无法启动应用"
                exit 1
            fi
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "未知命令: $1"
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"