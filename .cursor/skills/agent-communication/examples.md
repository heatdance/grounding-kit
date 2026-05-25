# Communication examples

Each block: user message → bad agent reply → good agent reply.

---

## 1. Ack with table and roadmap

**User:** We'll add the harness later; for now this is context only.

**Bad:** Here's a summary of your vision… | Goal | Implication | … When you're ready, we can add skeleton, topics, or README…

**Good:** Understood — harness and topics come later. The repo is empty, which fits context-only for now. Say when you want the first artifact.

---

## 2. Ack bloated vs tight

**User:** The workspace is for agentic prep; people clone it and use agent mode.

**Bad:** Great question! You're building a downloadable agent workspace that enables… [5 paragraphs, bullet roadmap]

**Good:** Got it — clone-and-go agent prep with agent-first workflow and built-in guidance so users don't author their own harness docs first.

---

## 3. Deictic reference without antecedent

**User:** The API test failed again after the deploy.

**Bad:** As noted above, the failure is likely environment-related. Check that configuration.

**Good:** The API test likely failed because staging still points at the old base URL after the deploy. Confirm the env var in the pipeline config.

---

## 4. Self-contained subject naming

**User:** Why does the checkout E2E flake?

**Bad:** It times out on the third step when the selector doesn't match.

**Good:** The checkout E2E flakes when the payment iframe loads slowly and the third-step selector times out. Try increasing the iframe wait or scoping the locator to the iframe.

---

## 5. Path spam vs human label

**User:** Where is the retry configured?

**Bad:** Retries are in `tests/e2e/config/playwright.config.ts` lines 42–48 under `projects[0].retries`.

**Good:** Retries are in the Playwright config under the default project's `retries` field. I can point to the exact path if you're editing it.

---

## 6. Paths when user overrides

**User:** Use paths — where is the retry configured?

**Good:** `tests/e2e/playwright.config.ts` — see `projects[0].retries` (around line 42).

---

## 7. Bullets for causal explanation vs prose

**User:** Why did auth break after the refactor?

**Bad:**
- Session middleware moved
- Token format changed
- Cookie domain mismatch
- Therefore auth broke

**Good:** Auth broke because session middleware now issues JWTs while the login flow still expects cookie sessions. Align the login handler with the new middleware or restore cookie-based sessions for web clients.

---

## 8. Bullets OK for homogeneous steps

**User:** How do I run smoke tests locally?

**Good:** From the repo root: install deps, set `BASE_URL`, run the smoke project. Steps: `npm ci` → copy `.env.example` to `.env` → `npx playwright test --project=smoke`.

---

## 9. Work status bloated vs tight

**User:** Fix the typo in the README.

**Bad:** I'll help you fix that! I've analyzed the repository structure… [long narrative]

**Good:** Fixed the typo in README (Contributing section). No other files changed. Open README to confirm the heading reads correctly.

---

## 10. Deep tier with lead summary

**User:** Explain in detail how response tiers work in this workspace.

**Good (opening):** Four tiers control chat length: Ack for context-only, Answer for questions, Work for implementation, Deep for formal or teaching replies — all defined in `communication.mdc`.

Then structured sections are OK for the rest of the reply.

---

## 11. Answer tier — lead with verdict

**User:** Should we block merge on flaky E2E?

**Bad:** Flaky tests are a common problem in CI. There are many approaches teams take…

**Good:** Yes for release branches — flaky E2E should block merge or you'll ship false greens. For feature branches, quarantine or retry-with-cap is acceptable if tracked. Want a short policy draft?

---

## 12. Terse override

**User:** Terse — what failed in the last CI run?

**Good:** E2E job: `checkout.spec.ts` login step, timeout 30s, staging URL.

---

## 13. Human-facing README (file on disk)

**Bad (opening):** "Hooks inject l0 excerpt + log digest; agents resolve anchors via INDEX."

**Good (opening):** "Use this when you want agentic work without building rules and folder layout from scratch."
