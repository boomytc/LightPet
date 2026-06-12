# Makefile
.PHONY: help build run preview validate-contract generate-contract test resize-smoke-test package-app clean

# 默认目标
.DEFAULT_GOAL := help

SWIFT_PRODUCT := LightPetDesktop
PORT ?= 18091
BUILD_ARTIFACTS := .build dist
VALIDATION_ARTIFACTS := output .playwright-cli

help: ## 显示帮助信息
	@echo "LightPet runtime commands"
	@echo ""
	@echo "Available commands:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## 构建桌面运行时
	swift build --product $(SWIFT_PRODUCT)

run: ## 运行桌面运行时
	swift run $(SWIFT_PRODUCT) --scale 1

preview: ## 启动 Web 预览服务
	python3 -m http.server $(PORT) --directory .

validate-contract: ## 校验动画契约和生成的 Swift 运行时数据一致
	python3 scripts/validate_animation_contract.py

generate-contract: ## 从动画契约重新生成 Swift 运行时数据
	python3 scripts/validate_animation_contract.py --update

test: ## 运行 macOS 产品本地测试
	swift package clean
	swift test

resize-smoke-test: ## 运行桌面尺寸冒烟测试
	swift run $(SWIFT_PRODUCT) --show-dock --resize-smoke-test

package-app: ## 打包本地 .app
	scripts/package_app.sh

clean: ## 清理构建、打包和验证产物
	@echo "Cleaning project artifacts..."
	@rm -rf $(BUILD_ARTIFACTS) $(VALIDATION_ARTIFACTS)
	@find . -type f -name '.DS_Store' -delete
	@echo "Cleaning completed!"
