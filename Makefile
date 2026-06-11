# Makefile
.PHONY: help build run preview validate-contract resize-smoke-test package-app clean

.DEFAULT_GOAL := help

PRODUCT_DIR := products/lightpet_runtime

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

clean: ## 清理工作区和当前产品临时产物
	$(MAKE) -C $(PRODUCT_DIR) clean
	@rm -rf .build dist output .playwright-cli
	@find . -type f -name '.DS_Store' -delete
