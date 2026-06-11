# Makefile
.PHONY: help build run preview validate-contract resize-smoke-test package-app \
	pyside6-venv pyside6-install pyside6-run pyside6-run-example pyside6-validate pyside6-test pyside6-resize-smoke-test clean

.DEFAULT_GOAL := help

PRODUCT_DIR := products/lightpet_runtime
PYSIDE6_PRODUCT_DIR := products/lightpet_pyside6

help: ## 显示帮助信息
	@echo "LightPet workspace commands"
	@echo ""
	@echo "Available commands:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## 构建当前产品
	$(MAKE) -C $(PRODUCT_DIR) build

run: ## 运行当前桌面产品
	$(MAKE) -C $(PRODUCT_DIR) run

preview: ## 启动当前产品的 Web 预览服务
	$(MAKE) -C $(PRODUCT_DIR) preview

validate-contract: ## 校验动画契约和 Swift 运行时一致
	$(MAKE) -C $(PRODUCT_DIR) validate-contract

resize-smoke-test: ## 运行桌面尺寸冒烟测试
	$(MAKE) -C $(PRODUCT_DIR) resize-smoke-test

package-app: ## 打包当前产品的本地 .app
	$(MAKE) -C $(PRODUCT_DIR) package-app

pyside6-venv: ## 创建 PySide6 产品 Python 3.12 uv 环境
	$(MAKE) -C $(PYSIDE6_PRODUCT_DIR) venv

pyside6-install: ## 安装 PySide6 产品运行依赖
	$(MAKE) -C $(PYSIDE6_PRODUCT_DIR) install

pyside6-run: ## 运行 PySide6 产品，默认读取 Codex 宠物目录
	$(MAKE) -C $(PYSIDE6_PRODUCT_DIR) run

pyside6-run-example: ## 使用示例宠物运行 PySide6 产品
	$(MAKE) -C $(PYSIDE6_PRODUCT_DIR) run-example

pyside6-validate: ## 校验 PySide6 动画契约和示例包
	$(MAKE) -C $(PYSIDE6_PRODUCT_DIR) validate-contract

pyside6-test: ## 运行 PySide6 产品本地测试
	$(MAKE) -C $(PYSIDE6_PRODUCT_DIR) test

pyside6-resize-smoke-test: ## 运行 PySide6 尺寸冒烟测试
	$(MAKE) -C $(PYSIDE6_PRODUCT_DIR) resize-smoke-test

clean: ## 清理工作区和当前产品临时产物
	$(MAKE) -C $(PRODUCT_DIR) clean
	$(MAKE) -C $(PYSIDE6_PRODUCT_DIR) clean
	@rm -rf .build dist output .playwright-cli
	@find . -type f -name '.DS_Store' -delete
