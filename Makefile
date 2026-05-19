# Makefile
.PHONY: help clean

# 默认目标
.DEFAULT_GOAL := help

BUILD_ARTIFACTS := .build dist
VALIDATION_ARTIFACTS := output .playwright-cli

help: ## 显示帮助信息
	@echo "Manage commands"
	@echo ""
	@echo "Available commands:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

clean: ## 清理构建、打包和验证产物
	@echo "Cleaning project artifacts..."
	@rm -rf $(BUILD_ARTIFACTS) $(VALIDATION_ARTIFACTS)
	@find . -type f -name '.DS_Store' -delete
	@echo "Cleaning completed!"
