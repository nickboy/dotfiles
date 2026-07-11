---
name: hackernews-summary
description: |
  Use when user mentions "hackernews", "hacker news", "HN summary",
  "HN", "科技新聞", or asks to summarize today's tech news.
version: 1.0.0
tools: Bash, WebFetch
user-invocable: true
---

# Hacker News Daily Summary (Traditional Chinese)

Fetch the top 30 Hacker News stories (the full front page) and present
a summary in Traditional Chinese (繁體中文).

## Workflow

### Step 1: Fetch Top Story IDs

Use WebFetch to get top story IDs:

```text
URL: https://hacker-news.firebaseio.com/v0/topstories.json
```

Take the first 30 IDs from the returned JSON array.

### Step 2: Fetch Story Details

For each of the 30 story IDs, fetch details using WebFetch:

```text
URL: https://hacker-news.firebaseio.com/v0/item/{id}.json
```

Each story returns: `title`, `url`, `score`, `by`, `descendants`
(comment count).

Fetch all 30 stories in parallel (multiple WebFetch calls in one
response) for speed.

### Step 3: Summarize in Traditional Chinese

For each story, produce:

- **Title**: Translate the title into Traditional Chinese
- **Score and comments**: Format as `(X 分 · Y 則留言)`
- **Description**: A brief 1-2 sentence explanation of why this story
  is notable or what it covers, written in Traditional Chinese
- **Link**: The original URL

### Step 4: Format and Display

Output the summary in this format:

```markdown
## Hacker News 每日摘要 — YYYY-MM-DD

1. **[繁體中文標題]** (352 分 · 128 則留言)
   簡短說明這篇文章的重點與值得關注的原因。
   https://example.com/article

2. **[繁體中文標題]** (200 分 · 45 則留言)
   簡短說明。
   https://example.com/another
```

## Important Notes

- Always use today's date in the header
- All text (titles, descriptions) must be in Traditional Chinese
- Keep descriptions concise: 1-2 sentences max
- If a story has no URL (e.g. Ask HN), link to the HN discussion:
  `https://news.ycombinator.com/item?id={id}`
- Sort stories by their original ranking (position in the top stories
  list), not by score
