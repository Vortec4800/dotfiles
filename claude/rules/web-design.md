---
paths:
  - "**/*.{tsx,jsx,vue,svelte,astro}"
  - "**/*.{html,css,scss,sass,less}"
---

# Web UI from a design prototype — platform rules

**Scope: web/frontend work where an approved design artifact exists.** Follow this whenever the task is "make the app match the design."

### The loop (non-negotiable)

**Render the design → transcribe exact values → screenshot yours beside it → fix → repeat.** Never report a screen as done until you have looked at both images. If a screenshot shows a framework error overlay, the screen is broken, not done.

### 1. Get the design rendering before writing any code

Do this first, as its own step. If you cannot get it rendering, **say so and stop** — a design pass done blind will be rejected, and guessing wastes far more time than asking.

For a Claude Design `.dc.html` file:

1. `DesignSync get_file` for **both** the `.dc.html` and `support.js` (the runtime — easy to miss).
2. `support.js` needs `window.React`; it pulls React 18 UMD + `@babel/standalone` from unpkg. Vendor those locally, rewrite the URLs, and blank the `*_SRI` constants.
3. Serve the folder over HTTP (`python3 -m http.server`) — `file://` will not work.
4. Drive it by walking React fibers to the class-component instance (look for a `stateNode.logic` whose `state` holds the screen key), then `setState` to reach any screen. Read the prototype's own `<script>` block to learn the state keys and their exact values.

### 2. The rendered DOM is the spec — not the source file

Dump each screen's resolved `outerHTML` to disk. Inline styles come back as literal `px`/`rgb()`, which is what you transcribe.

- **Never navigate the design's source by byte offset.** Offsets go stale the moment anything shifts, and you will silently restyle from the wrong screen. This is the single most expensive mistake available here.
- Read the prototype's own JS for **exact label strings** and helper logic (rule text, badge thresholds, colour maps). Do not invent copy.
- Build a **token census** across all dumps (every colour, font-size, radius, padding, border) *before* writing CSS. It exposes the real design system in one pass.

### 3. Transcribe, don't interpret

"Adapt it to our design system" means **write it maintainably** — it does not license visual reinterpretation. The values are the values.

- **Watch the px/rem trap.** Prototypes are usually authored in `px`. Reimplementing in `rem` against a 16px root silently inflates the whole UI 15–30% and reads as "everything is too big." Match the design's unit.
- Copy exact hexes. A "close enough" palette is the most common cause of "the colors are wrong."

### 4. Foundation before screens, single owner

Land tokens and shared primitives (buttons, inputs, chips, table, pills, header bar) **first, by one actor**, then build screens on top. Screens built in parallel against an unfinished foundation each re-derive their own values and drift apart.

### 5. Delegating screens to subagents

- Give each agent **artifacts, not prose**: its screen's DOM dump, the prototype's logic file, and the screenshot command. Paraphrasing the design is how drift starts.
- Give each agent a **disjoint file set**; put shared components under one owner and sequence dependents after it.
- Require each agent to run the screenshot loop itself and iterate before reporting.
- Prefer a scriptable headless browser (Playwright/Puppeteer via a small CLI script) over a shared interactive browser, so agents can verify concurrently without colliding.

### 6. Verify the whole surface

Sweep **every** route at the end — screenshot each and assert it actually rendered. Detect real failures rather than proxies: in Next.js dev, `nextjs-portal` is always present in the DOM, so its existence means nothing; check its shadow content or the visible error text instead.

### 7. When the design and the written spec disagree

Treat it as a **decision, not a bug to quietly fix** — especially if it touches business rules, calculation, or persisted data.

1. Gather evidence (e.g. query the DB for the real distribution the rule produces).
2. Present both readings with the consequence of each and a recommendation.
3. Once decided, **amend the spec document** in the same change so code and spec stop contradicting each other, and update any tests that encoded the old rule.

Never silently change calculation-engine semantics to make a screen look right.

### Definition of done

Every screen screenshot-compared against the design · every route renders · typecheck, lint, and the full test suite pass · deliberate divergences from the design listed explicitly in the summary rather than left for the reviewer to find.
