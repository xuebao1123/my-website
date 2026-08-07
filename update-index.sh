#!/bin/bash

# ---------- 配置路径 ----------
BLOG_DIR="haige/blog"
INDEX_FILE="haige/src/pages/index.md"
PLACEHOLDER="<!--RECENT_BLOG-->"   # 在 index.md 中放置这个标记

# ---------- 辅助函数 ----------
# 从 Markdown 文件中提取标题（优先 front matter 的 title，否则取第一个 # 标题）
extract_title() {
    local file="$1"
    # 尝试从 front matter 中提取 title（格式：--- 之间的 title: xxx）
    local title=$(sed -n '/^---$/,/^---$/p' "$file" | grep -m1 '^title:' | sed 's/^title:\s*//')
    if [ -n "$title" ]; then
        echo "$title"
        return
    fi
    # 否则取第一个 # 开头的行
    title=$(grep -m1 '^# ' "$file" | sed 's/^# //')
    if [ -n "$title" ]; then
        echo "$title"
        return
    fi
    # 若都没有，则用文件名
    echo "$(basename "$file" .md)"
}

# 提取文章内容的前 N 个纯文本字符（去除 Markdown 标记）
extract_excerpt() {
    local file="$1"
    local max_len=60
    # 先去除 front matter（如果有）
    local content=$(sed -n '/^---$/,/^---$/d' "$file")   # 删除 front matter 区域
    # 去除 Markdown 标记（简单处理）
    content=$(echo "$content" | sed -E \
        -e 's/!\[[^]]*\]\([^)]*\)//g' \           # 移除图片
        -e 's/\[([^]]+)\]\([^)]+\)/\1/g' \        # 链接只留文字
        -e 's/[#*_~`>]//g' \                      # 移除标题符、粗体、斜体等
        -e 's/\n/ /g' \                           # 换行转空格
        -e 's/ +/ /g')                            # 合并多个空格
    # 去除首尾空白并截取前 max_len 个字符
    content=$(echo "$content" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [ ${#content} -gt $max_len ]; then
        echo "${content:0:$max_len}…"
    else
        echo "$content"
    fi
}

# ---------- 主逻辑 ----------
# 1. 进入博客目录
cd "$BLOG_DIR" || { echo "博客目录不存在！"; exit 1; }

# 2. 按修改时间降序排列所有 .md 文件，取前 5 个
files=$(ls -t *.md 2>/dev/null | head -5)
if [ -z "$files" ]; then
    echo "没有找到博客文章。"
    summary="\n\n## 📝 近期博客\n\n暂无博客。\n"
else
    summary="\n\n## 📝 近期博客\n\n"
    for file in $files; do
        # 提取标题
        title=$(extract_title "$file")
        # 提取摘要（前60字）
        excerpt=$(extract_excerpt "$file")
        # 获取修改日期（YYYY-MM-DD）
        date_str=$(date -r "$file" +"%Y-%m-%d" 2>/dev/null || stat -c %y "$file" 2>/dev/null | cut -d' ' -f1)
        # 生成 Markdown 列表项（注意：博客链接路径是 /blog/文件名）
        base_name=$(basename "$file" .md)
        summary+="- **[${title}](/blog/${base_name})**  \n"
        summary+="  📅 ${date_str}  \n"
        summary+="  ${excerpt}  \n\n"
    done
fi

# 3. 回到根目录
cd - > /dev/null || exit

# 4. 检查首页是否存在占位符，替换或追加
if grep -q "$PLACEHOLDER" "$INDEX_FILE"; then
    # 使用 sed 替换占位符为摘要内容（注意转义）
    # 因为摘要包含换行和特殊字符，我们用 awk 或 sed 替换整个行比较麻烦，这里采用简单方式：
    # 将文件按占位符分割，然后在占位符位置插入摘要
    # 用 awk 更可靠
    awk -v ph="$PLACEHOLDER" -v summary="$summary" '
        {
            if ($0 ~ ph) {
                print summary
            } else {
                print
            }
        }
    ' "$INDEX_FILE" > "$INDEX_FILE.tmp" && mv "$INDEX_FILE.tmp" "$INDEX_FILE"
else
    # 没有占位符，追加到末尾
    echo -e "$summary" >> "$INDEX_FILE"
fi

echo "✅ 首页已更新，添加了最近5篇博客摘要。"