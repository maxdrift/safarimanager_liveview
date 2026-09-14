#!/usr/bin/env node
/**
 * Capture responsive audit screenshots at fixed viewports.
 * Usage: node scripts/capture_responsive_screenshots.js --phase before|after
 *
 * Requires: npx playwright (installed on first run)
 * App must be running at http://localhost:4000
 */

const { chromium } = require("playwright");
const fs = require("fs");
const path = require("path");

const COMPETITION_ID = process.env.SM_COMPETITION_ID || "349b746e-4515-49f8-81ce-3380ad74370a";
const BASE = `http://localhost:4000`;
const OUT_DIR = path.join(__dirname, "..", "docs", "responsive-audit", "screenshots");

const phase = process.argv.includes("--phase")
  ? process.argv[process.argv.indexOf("--phase") + 1]
  : "before";

if (!["before", "after"].includes(phase)) {
  console.error("Usage: node scripts/capture_responsive_screenshots.js --phase before|after");
  process.exit(1);
}

const viewports = [
  { name: "375x812", width: 375, height: 812 },
  { name: "768x1024", width: 768, height: 1024 },
  { name: "1280x800", width: 1280, height: 800 },
];

const themes = ["night", "light"];

const views = [
  {
    id: "sidebar-open",
    url: `${BASE}/organize/${COMPETITION_ID}/results`,
    setup: async (page, vp) => {
      if (vp.width < 768) {
        await page.click('[data-el-sidebar-open]').catch(() => {});
        await page.waitForTimeout(300);
      }
    },
    viewports: ["375x812"],
    themes: ["night", "light"],
  },
  {
    id: "steps-header",
    url: `${BASE}/organize/${COMPETITION_ID}/participants`,
    viewports: ["768x1024"],
    themes: ["night"],
  },
  {
    id: "admin-grid",
    url: `${BASE}/admin/subjects`,
    viewports: ["375x812", "1280x800"],
    themes: ["night", "light"],
  },
  {
    id: "results",
    url: `${BASE}/organize/${COMPETITION_ID}/results`,
    viewports: ["375x812", "768x1024", "1280x800"],
    themes: ["night", "light"],
  },
  {
    id: "results-detail",
    url: `${BASE}/organize/${COMPETITION_ID}/results`,
    setup: async (page) => {
      const btn = page.locator('button:has-text("Show details")').first();
      if (await btn.count()) {
        await btn.click();
        await page.waitForTimeout(400);
      }
    },
    viewports: ["1280x800"],
    themes: ["night", "light"],
  },
  {
    id: "participants",
    url: `${BASE}/organize/${COMPETITION_ID}/participants`,
    viewports: ["375x812", "1280x800"],
    themes: ["night"],
  },
  {
    id: "teams",
    url: `${BASE}/organize/${COMPETITION_ID}/teams`,
    viewports: ["375x812", "1280x800"],
    themes: ["night"],
  },
  {
    id: "jurors",
    url: `${BASE}/organize/${COMPETITION_ID}/jurors`,
    viewports: ["375x812", "1280x800"],
    themes: ["night"],
  },
  {
    id: "validation-launcher",
    url: `${BASE}/organize/${COMPETITION_ID}/validation_launcher`,
    viewports: ["375x812", "768x1024", "1280x800"],
    themes: ["night"],
  },
  {
    id: "jury-lightbox",
    url: `${BASE}/organize/${COMPETITION_ID}/jury`,
    viewports: ["1280x800"],
    themes: ["night"],
  },
  {
    id: "validation-lightbox",
    url: `${BASE}/organize/${COMPETITION_ID}/validation`,
    viewports: ["1280x800"],
    themes: ["night"],
  },
];

async function setTheme(page, theme) {
  await page.evaluate((t) => {
    document.documentElement.setAttribute("data-theme", t);
    localStorage.setItem("theme", t);
  }, theme);
}

async function main() {
  fs.mkdirSync(OUT_DIR, { recursive: true });

  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext();
  const page = await context.newPage();

  for (const view of views) {
    for (const vpName of view.viewports) {
      const vp = viewports.find((v) => v.name === vpName);
      if (!vp) continue;

      for (const theme of view.themes || themes) {
        await page.setViewportSize({ width: vp.width, height: vp.height });
        await page.goto(view.url, { waitUntil: "networkidle", timeout: 30000 });
        await setTheme(page, theme);
        await page.waitForTimeout(500);

        if (view.setup) {
          await view.setup(page, vp);
        }

        const filename = `${view.id}--${vpName}--${theme}--${phase}.png`;
        const filepath = path.join(OUT_DIR, filename);
        await page.screenshot({ path: filepath, fullPage: false });
        console.log("saved", filename);
      }
    }
  }

  await browser.close();
  console.log(`Done (${phase})`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
