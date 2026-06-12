# Makefile
.PHONY: help build run preview validate-contract validate-all diff-contracts \
	macos-test resize-smoke-test package-app qt-venv qt-install qt-run \
	qt-run-example qt-validate qt-test qt-resize-smoke-test clean

.DEFAULT_GOAL := help

MACOS_PRODUCT_DIR := products/lightpet_macos
QT_PRODUCT_DIR := products/lightpet_qt

help: ## 显示帮助信息
	@echo "LightPet workspace commands"
	@echo ""
	@echo "Available commands:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## 构建当前产品
	$(MAKE) -C $(MACOS_PRODUCT_DIR) build

run: ## 运行当前桌面产品
	$(MAKE) -C $(MACOS_PRODUCT_DIR) run

preview: ## 启动当前产品的 Web 预览服务
	$(MAKE) -C $(MACOS_PRODUCT_DIR) preview

validate-contract: ## 校验 macOS 动画契约和生成运行时数据一致
	$(MAKE) -C $(MACOS_PRODUCT_DIR) validate-contract

validate-all: validate-contract macos-test qt-validate qt-test diff-contracts ## 校验 macOS、Qt 和两份契约 JSON 一致性

diff-contracts: ## 对比 macOS 和 Qt 产品的动画契约 JSON
	diff -u $(MACOS_PRODUCT_DIR)/docs/pet-animation-contract.json $(QT_PRODUCT_DIR)/docs/pet-animation-contract.json
	@echo "Animation contract JSON files match."

macos-test: ## 运行 macOS 产品本地测试
	$(MAKE) -C $(MACOS_PRODUCT_DIR) test

resize-smoke-test: ## 运行桌面尺寸冒烟测试
	$(MAKE) -C $(MACOS_PRODUCT_DIR) resize-smoke-test

package-app: ## 打包当前产品的本地 .app
	$(MAKE) -C $(MACOS_PRODUCT_DIR) package-app

qt-venv: ## 创建 Qt 产品 Python 3.12 uv 环境
	$(MAKE) -C $(QT_PRODUCT_DIR) venv

qt-install: ## 安装 Qt 产品运行依赖
	$(MAKE) -C $(QT_PRODUCT_DIR) install

qt-run: ## 运行 Qt 产品，默认读取 Codex 宠物目录
	$(MAKE) -C $(QT_PRODUCT_DIR) run

qt-run-example: ## 使用示例宠物运行 Qt 产品
	$(MAKE) -C $(QT_PRODUCT_DIR) run-example

qt-validate: ## 校验 Qt 动画契约和示例包
	$(MAKE) -C $(QT_PRODUCT_DIR) validate-contract

qt-test: ## 运行 Qt 产品本地测试
	$(MAKE) -C $(QT_PRODUCT_DIR) test

qt-resize-smoke-test: ## 运行 Qt 尺寸冒烟测试
	$(MAKE) -C $(QT_PRODUCT_DIR) resize-smoke-test

clean: ## 清理工作区和当前产品临时产物
	$(MAKE) -C $(MACOS_PRODUCT_DIR) clean
	$(MAKE) -C $(QT_PRODUCT_DIR) clean
	@rm -rf .build dist output .playwright-cli
	@find . -type f -name '.DS_Store' -delete
