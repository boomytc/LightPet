# Makefile
.PHONY: help venv install run run-example validate-contract test resize-smoke-test clean

.DEFAULT_GOAL := help

PYTHON := .venv/bin/python
PYTHONPATH := src
EXAMPLE_PET := examples/pets/lulu/pet.json
UV_CACHE_DIR := .uv-cache

help: ## 显示帮助信息
	@echo "LightPet Qt commands"
	@echo ""
	@echo "Available commands:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-22s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

venv: ## 创建 Python 3.12 uv 虚拟环境
	UV_CACHE_DIR=$(UV_CACHE_DIR) uv venv --python 3.12

install: ## 安装产品和运行依赖
	UV_CACHE_DIR=$(UV_CACHE_DIR) uv pip install -e .

run: ## 运行 Qt 桌宠，默认读取 Codex 宠物目录
	PYTHONPATH=$(PYTHONPATH) $(PYTHON) -m lightpet_qt --scale 1

run-example: ## 使用内置 lulu 示例运行 Qt 桌宠
	PYTHONPATH=$(PYTHONPATH) $(PYTHON) -m lightpet_qt --pet $(EXAMPLE_PET) --scale 1

validate-contract: ## 校验动画契约、Qt 运行时和示例包
	PYTHONPATH=$(PYTHONPATH) $(PYTHON) scripts/validate_animation_contract.py

test: ## 运行产品本地测试
	QT_QPA_PLATFORM=offscreen PYTHONPATH=$(PYTHONPATH) $(PYTHON) -m unittest discover -s tests

resize-smoke-test: ## 启动窗口尺寸冒烟测试
	PYTHONPATH=$(PYTHONPATH) $(PYTHON) -m lightpet_qt --pet $(EXAMPLE_PET) --show-dock --resize-smoke-test

clean: ## 清理产品临时产物
	@rm -rf output dist .pytest_cache .mypy_cache .ruff_cache .uv-cache src/*.egg-info
	@find . -type d -name '__pycache__' -prune -exec rm -rf {} +
	@find . -type f -name '.DS_Store' -delete
