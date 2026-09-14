# Responsive layout audit

Before/after screenshots for the responsive layout pass. Pairs use identical routes, viewport, theme, and UI state (e.g. expanded results row, open mobile sidebar).

Screenshots live in `screenshots/` (gitignored). Regenerate locally with the script below.

## Viewports

| Name | Size | Typical device |
|------|------|----------------|
| `375x812` | 375×812 | Phone |
| `768x1024` | 768×1024 | Tablet |
| `1280x800` | 1280×800 | 13–15" laptop / Tauri window |

## Themes

- `night` — default dark theme
- `light` — key surfaces (sidebar, admin grid, results)

## File naming

```
{view}--{viewport}--{theme}--{before|after}.png
```

## Views captured

| View | Route / state | Known issue (before) |
|------|---------------|----------------------|
| `sidebar-open` | Results + mobile menu open | No backdrop, weak drawer |
| `steps-header` | Participants @ 768px | Steps nav hidden below lg |
| `admin-grid` | `/admin/subjects` | Grid table horizontal overflow |
| `results` | Results ranking table | Cramped header, table overflow |
| `results-detail` | Results with row expanded | Nested table + status badges |
| `participants` | Participants dual-pane | Fixed columns crush content |
| `teams` | Teams dual-pane | Same |
| `jurors` | Jurors dual-pane | Same |
| `validation-launcher` | Validation summary tables | Wide tables without scroll |
| `jury-lightbox` | `/jury` | Toolbar clips on narrow width |
| `validation-lightbox` | `/validation` | Toolbar + flag bar clip |

## Re-capture

```bash
# App running at http://localhost:4000
cd scripts && npm install playwright   # first time only
node capture_responsive_screenshots.js --phase before
# … apply layout fixes …
node capture_responsive_screenshots.js --phase after
```

Optional: `SM_COMPETITION_ID=your-uuid node capture_responsive_screenshots.js --phase after`
