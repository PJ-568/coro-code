#!/usr/bin/env bash
# 发布软件包至 crates.io | Publish to crates.io

# 设置定量 | Quantities
## 当前脚本所在目录 | Current Script Directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
## 仓库目录 | Repository Directory
REPO_DIR="$(dirname "$SCRIPT_DIR")"
## 当前语言 | Current Language
CURRENT_LANG=0 ### 0: en-US, 1: zh-Hans-CN

# 语言检测 | Language Detection
if [ $(echo ${LANG/_/-} | grep -Ei "\\b(zh|cn)\\b") ]; then CURRENT_LANG=1;  fi

# 本地化 | Localization
recho() {
  if [ "$CURRENT_LANG" == "1" ]; then
    ## zh-Hans-CN
    echo -e "$1"
  else
    ## en-US
    echo -e "$2"
  fi
}

# 颜色定义 | Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 显示帮助信息 | Show help message
show_help() {
  recho \
    "用法: $0 [选项] [API_TOKEN]
选项:
  -h, --help         显示此帮助信息
  -n, --dry-run      只进行预检，不实际发布
  -y, --yes          自动确认发布，无需交互
  -r, --registry     指定要发布的注册表（例如：crates-io）
参数:
  API_TOKEN          crates.io 的 API 令牌（可选，也可以通过 CARGO_REGISTRY_TOKEN 环境变量设置）
示例:
  $0                       # 使用已保存的令牌或环境变量
  $0 -n                    # 预检模式
  $0 -y                    # 自动确认发布
  $0 -r crates-io          # 指定注册表
  $0 YOUR_API_TOKEN        # 使用指定的 API 令牌
  CARGO_REGISTRY_TOKEN=YOUR_API_TOKEN $0  # 通过环境变量设置令牌" \
    "Usage: $0 [options] [API_TOKEN]
Options:
  -h, --help         Show this help message
  -n, --dry-run      Dry run mode, only performs checks without publishing
  -y, --yes          Automatically confirm publication without interaction
  -r, --registry     Specify the registry to publish to (e.g., crates-io)
Arguments:
  API_TOKEN          API token for crates.io (optional, can also be set via CARGO_REGISTRY_TOKEN environment variable)
Examples:
  $0                       # Use saved token or environment variable
  $0 -n                    # Dry run mode
  $0 -y                    # Automatically confirm publication
  $0 -r crates-io          # Specify registry
  $0 YOUR_API_TOKEN        # Use specified API token
  CARGO_REGISTRY_TOKEN=YOUR_API_TOKEN $0  # Set token via environment variable"
}

# 默认参数 | Default arguments
DRY_RUN=false
AUTO_CONFIRM=false
REGISTRY=""

# 解析命令行参数 | Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      show_help
      exit 0
      ;;
    -n|--dry-run)
      DRY_RUN=true
      shift
      ;;
    -y|--yes)
      AUTO_CONFIRM=true
      shift
      ;;
    -r|--registry)
      REGISTRY="$2"
      shift 2
      ;;
    -*)
      recho \
        "${RED}错误: 未知选项 $1${NC}" \
        "${RED}Error: Unknown option $1${NC}"
      show_help
      exit 1
      ;;
    *)
      API_TOKEN="$1"
      shift
      ;;
  esac
done

# 构建 cargo publish 命令的参数 | Build cargo publish command arguments
CARGO_PUBLISH_ARGS=""
if [ -n "$REGISTRY" ]; then
  CARGO_PUBLISH_ARGS="--registry $REGISTRY"
fi

# 检查是否已安装 cargo | Check if cargo is installed
if ! command -v cargo &> /dev/null; then
  recho \
    "${RED}错误: 未找到 cargo 命令，请先安装 Rust 工具链${NC}" \
    "${RED}Error: cargo command not found, please install Rust toolchain first${NC}"
  exit 1
fi

# 检查 jq 是否已安装 | Check if jq is installed
if ! command -v jq &> /dev/null; then
  recho \
    "${RED}错误: 未找到 jq 命令，请先安装 jq${NC}" \
    "${RED}Error: jq command not found, please install jq first${NC}"
  exit 1
fi

# 获取 API 令牌 | Get API token
# 如果提供了 API 令牌，则登录 | Login if API token is provided
if [ -n "$API_TOKEN" ]; then
  recho \
    "${YELLOW}正在使用提供的 API 令牌登录...${NC}" \
    "${YELLOW}Logging in with provided API token...${NC}"
  cargo login "$API_TOKEN"
  if [ $? -ne 0 ]; then
    recho \
      "${RED}错误: 登录失败${NC}" \
      "${RED}Error: Login failed${NC}"
    exit 1
  fi
else
  # 检查环境变量 | Check environment variable
  if [ -z "$CARGO_REGISTRY_TOKEN" ]; then
    recho \
      "${YELLOW}警告: 未提供 API 令牌，且未设置 CARGO_REGISTRY_TOKEN 环境变量。发布可能会失败。${NC}" \
      "${YELLOW}Warning: No API token provided, and CARGO_REGISTRY_TOKEN environment variable is not set. Publication may fail.${NC}"
  else
    recho \
      "${YELLOW}未提供 API 令牌，将使用 CARGO_REGISTRY_TOKEN 环境变量${NC}" \
      "${YELLOW}No API token provided, will use CARGO_REGISTRY_TOKEN environment variable${NC}"
  fi
fi

# 进入仓库目录 | Change to repository directory
cd "$REPO_DIR" || {
  recho \
    "${RED}错误: 无法进入仓库目录 $REPO_DIR${NC}" \
    "${RED}Error: Cannot enter repository directory $REPO_DIR${NC}"
  exit 1
}

# 检查项目结构 | Check project structure
recho \
  "${YELLOW}检查项目结构...${NC}" \
  "${YELLOW}Checking project structure...${NC}"

if [ ! -f "Cargo.toml" ]; then
  recho \
    "${RED}错误: 未找到根 Cargo.toml 文件${NC}" \
    "${RED}Error: Root Cargo.toml file not found${NC}"
  exit 1
fi

# 检查工作区成员 | Check workspace members
recho \
  "${YELLOW}检查工作区成员...${NC}" \
  "${YELLOW}Checking workspace members...${NC}"

# 获取工作区成员列表及其依赖关系 | Get workspace members list and their dependencies
metadata=$(cargo metadata --no-deps --format-version 1)
if [ $? -ne 0 ]; then
  recho \
    "${RED}错误: 获取工作区元数据失败${NC}" \
    "${RED}Error: Failed to get workspace metadata${NC}"
  exit 1
fi

# Extract package names from workspace_members
members=$(echo "$metadata" | jq -r '.workspace_members[]' | sed 's/.*#\([^@]*\)@.*/\1/')
if [ -z "$members" ]; then
  recho \
    "${RED}错误: 未找到工作区成员${NC}" \
    "${RED}Error: No workspace members found${NC}"
  exit 1
fi

# 显示要发布的包 | Show packages to be published
recho \
  "${YELLOW}要发布的包:${NC}" \
  "${YELLOW}Packages to be published:${NC}"
echo "$members"

# 确认发布 | Confirm publication
if [ "$DRY_RUN" = false ]; then
  if [ "$AUTO_CONFIRM" = false ]; then
    recho \
      "${YELLOW}是否继续发布？(y/N)${NC}" \
      "${YELLOW}Continue with publication? (y/N)${NC}"
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      recho \
        "${YELLOW}已取消发布${NC}" \
        "${YELLOW}Publication cancelled${NC}"
      exit 0
    fi
  else
    recho \
      "${YELLOW}自动确认发布，无需交互。${NC}" \
      "${YELLOW}Automatically confirming publication without interaction.${NC}"
  fi
else
  recho \
    "${YELLOW}进入预检模式，将只进行检查，不实际发布。${NC}" \
    "${YELLOW}Entering dry run mode, will only perform checks without publishing.${NC}"
fi

# 确定发布顺序 | Determine publish order
recho \
  "${YELLOW}正在确定发布顺序...${NC}" \
  "${YELLOW}Determining publish order...${NC}"

# 创建一个数组来存储包及其依赖关系 | Create an array to store packages and their dependencies
declare -A dependencies

# 解析依赖关系 | Parse dependencies
while IFS= read -r member; do
  # 获取直接依赖 | Get direct dependencies
  deps=$(echo "$metadata" | jq -r --arg name "$member" '.packages[] | select(.name == $name) | .dependencies[] | select(.name | startswith("coro-")) | .name')

  # 将依赖关系存储在数组中
  dependencies["$member"]="$deps"
done <<< "$members"

# 使用 Kahn 算法进行拓扑排序 | Use Kahn's algorithm for topological sorting
# 初始化入度数组 | Initialize the in-degree array
declare -A in_degree
for member in $members; do
  in_degree["$member"]=0
done

# 计算每个节点的入度 | Calculate the in-degree of each node
for member in $members; do
  deps=${dependencies["$member"]}
  for dep in $deps; do
    if [[ -n "${in_degree[$dep]}" ]]; then
      in_degree["$dep"]=$((${in_degree["$dep"]} + 1))
    fi
  done
done

# 初始化队列 | Initialize the queue
queue=()
for member in $members; do
  if [[ ${in_degree["$member"]} -eq 0 ]]; then
    queue+=("$member")
  fi
done

# 拓扑排序结果 | Topological sort result
publish_order=()

# Kahn 算法主循环 | Kahn's algorithm main loop
while [[ ${#queue[@]} -gt 0 ]]; do
  # 取出队列中的第一个元素 | Remove the first element from the queue
  current=${queue[0]}
  queue=("${queue[@]:1}")

  # 添加到发布顺序中 | Add to the publish order
  publish_order+=("$current")

  # 更新其依赖项的入度 | Update the in-degree of its dependencies
  deps=${dependencies["$current"]}
  for dep in $deps; do
    if [[ -n "${in_degree[$dep]}" ]]; then
      in_degree["$dep"]=$((${in_degree["$dep"]} - 1))
      if [[ ${in_degree["$dep"]} -eq 0 ]]; then
        queue+=("$dep")
      fi
    fi
  done
done

# 检查是否存在循环依赖 | Check for circular dependencies
if [[ ${#publish_order[@]} -ne $(echo "$members" | wc -w) ]]; then
  recho \
    "${RED}错误: 无法确定发布顺序，请检查包之间的依赖关系是否存在循环。${NC}" \
    "${RED}Error: Could not determine publish order, please check for circular dependencies between packages.${NC}"
  exit 1
fi

# 反转顺序以获得正确的发布顺序 | Reverse the order to get the correct publish order
publish_order_reversed=()
for ((i=${#publish_order[@]}-1; i>=0; i--)); do
  publish_order_reversed+=("${publish_order[i]}")
done

# 显示发布顺序 | Show publish order
recho \
  "${YELLOW}发布顺序:${NC}" \
  "${YELLOW}Publish order:${NC}"
printf '%s\n' "${publish_order_reversed[@]}"

# 发布包 | Publish packages
recho \
  "${YELLOW}开始${DRY_RUN:+预检}发布包……${NC}" \
  "${YELLOW}Starting${DRY_RUN:+ dry run} package publication...${NC}"

# 遍历发布顺序并发布每个包 | Iterate through the publish order and publish each package
for package in "${publish_order_reversed[@]}"; do
  # 查找包的目录 | Find package directory
  package_dir=$(echo "$metadata" | jq -r --arg name "$package" '.packages[] | select(.name == $name) | .manifest_path' | xargs dirname)

  if [ -d "$package_dir" ] && [ -f "$package_dir/Cargo.toml" ]; then
    recho \
      "${YELLOW}正在${DRY_RUN:+预检}发布 $package 包……${NC}" \
      "${YELLOW}${DRY_RUN:+Dry run: }Publishing $package package...${NC}"

    cd "$package_dir" || exit 1

    if [ "$DRY_RUN" = true ]; then
      # 预检模式 | Dry run mode
      cargo publish --dry-run $CARGO_PUBLISH_ARGS
      if [ $? -eq 0 ]; then
        recho \
          "${GREEN}$package 包预检成功${NC}" \
          "${GREEN}$package package dry run successful${NC}"
      else
        recho \
          "${RED}错误: $package 包预检失败${NC}" \
          "${RED}Error: $package package dry run failed${NC}"
        exit 1
      fi
    else
      # 实际发布模式 | Actual publish mode
      cargo publish $CARGO_PUBLISH_ARGS
      if [ $? -eq 0 ]; then
        recho \
          "${GREEN}$package 包发布成功${NC}" \
          "${GREEN}$package package published successfully${NC}"
      else
        recho \
          "${RED}错误: $package 包发布失败${NC}" \
          "${RED}Error: $package package publication failed${NC}"
        exit 1
      fi

      # 如果不是最后一个包，则等待几秒钟 | Wait a few seconds if it's not the last package
      if [ "$package" != "${publish_order_reversed[-1]}" ]; then
        recho \
          "${YELLOW}等待 10 秒钟以确保 $package 包在 crates.io 上可用...${NC}" \
          "${YELLOW}Waiting 10 seconds to ensure $package package is available on crates.io...${NC}"
        sleep 10
      fi
    fi

    cd "$REPO_DIR" || exit 1
  else
    recho \
      "${YELLOW}警告: 找不到 $package 包的目录或 Cargo.toml 文件，已跳过。${NC}" \
      "${YELLOW}Warning: Could not find directory or Cargo.toml file for $package package, skipped.${NC}"
  fi
done

if [ "$DRY_RUN" = true ]; then
  recho \
    "${GREEN}所有包都已成功通过预检！${NC}" \
    "${GREEN}All packages have passed dry run successfully!${NC}"
else
  recho \
    "${GREEN}所有包都已成功发布！${NC}" \
    "${GREEN}All packages have been published successfully!${NC}"
fi
