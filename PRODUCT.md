# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users

- Primary: 4 technical-training students in the CHARAL 2026 pilot. Situation: learning from external courses, using CognitiveFlow to demonstrate comprehension through interactive labs. Job: manipulate an activity, submit a response with justification, react to Socratic follow-ups, finish with an unaided post-test.
- Secondary: 1 instructor. Job: view assigned students, review attempts and scores against own rubric, correct/comment AI scores, export anonymized results.

## Product Purpose

Complement external courses (Kaggle, Grafana, Ubuntu, Microsoft Learn, Astronomer, MIT, Hugging Face, LangChain, Evidently, DVC) with interactive experiences where students prove understanding. Success for the MVP: a complete demonstrable educational loop — curriculum view → lab → manipulation + justification → persisted attempts → structured evaluation → Socratic GenUI intervention → second attempt → unaided post-test → instructor review — running on a deployed HTTPS URL with demo data. Explicit non-goal: claiming causal efficacy from the n=4 pilot.

## Positioning

A Socratic tutor that selects the next intervention from curricular goal + student response + rubric + structured Jev evaluation, rendered through a closed GenUI component catalog (never arbitrary generated code), with every lab closing in an individual post-test without AI help. Neighboring course platforms provide content; CognitiveFlow provides the evidence-of-understanding loop with human-supervised scores.

## Operating Context

- CHARAL 2026 Track 2 — AI Systems to Stimulate Cognition. Target delivery 31 Oct 2026 (verify call timezone/closing time).
- Pilot scope: 4 students (s1–s4) + 1 instructor (i1). UI language Spanish, prepared for later i18n.
- Fixed pedagogical lab order: objective + prediction → interactive tool → justification → evaluation (shown only after responding) → Socratic intervention → unaided post-test → final reflection. One primary action per view/phase.
- Dev environment: Windows 11, PowerShell, Python via `uv`, Flutter Web. No WSL/Docker required. Terminal editor: vim (never nano).
- Run: backend `uv run uvicorn app.main:app --reload --port 8000`; frontend `flutter run -d web-server --web-port 8080 --dart-define=API_BASE_URL=http://localhost:8000`. `flutter run -d chrome` does not work on this machine.

## Capabilities and Constraints

Confirmed functionality (MVP minimal outcomes):
- Instructor login + view of own 4 students; student views curriculum, enters a topic, starts a lab.
- Interactive activity manipulation + answer with justification; backend persists attempts, events, hypothesis changes in SQLite.
- Jev evaluates specific dimensions via decoupled adapter; explicitly labelled mock evaluator fallback when Jev access is missing (provider failure → `status: pending`, `criteria: []`, never scores).
- Socratic agent selects and produces a GenUI intervention from authorized components only.
- Post-test individual mode blocks hints, LLM, and solutions and stores that context.
- Instructor can review attempts/scores, compare with own rubric, export anonymized results; `evaluation_results` is append-only, human review lives in `instructor_reviews`.
- Deployed HTTPS URL with demo seed data (8 modules, 5 users, 3 labs via `uv run python -m app.seed`).

Technical constraints:
- Existing stack answers architecture (no greenfield choice): Flutter Web (3.47.7, `genui 0.10.4` pinned) + FastAPI REST + SQLite (`Base.metadata.create_all`, no Alembic — model change requires delete db + reseed with API stopped) + Gemini (socratic tutor) + Jev adapter (`EVALUATOR_MODE=jev` real only for ML; data/monitoring use deterministic mock).
- Closed GenUI catalog: `backend/app/interventions.py::CATALOG` must match `frontend/lib/genui/catalog.dart::cognitiveFlowWidgets`. Internal `ui_spec` (`type, version, parameters…`) is not the A2UI wire (`v0.9 createSurface|updateComponents`); translation lives in `frontend/lib/genui/tutor_surface.dart`. No arbitrary Dart/HTML/JS/CSS from LLM in production.
- Demo auth only: login by `user_id`, opaque token in `auth_tokens`, no passwords (pilot only). Ownership via `session_for` (403 on чужой чужой → others' sessions).
- Backend tests: in-memory SQLite + autouse `_no_live_llm` mock; all `jev_*`/`socratic*` tests use mocked `httpx.post` or env settings; CI has no keys, nothing may depend on network. `backend/.env` holds real keys via `load_dotenv`.
- Flutter rules: all visible text selectable (`SelectionArea` global in `MaterialApp.router.builder`); builders use `BoundString` + `CatalogItemContext`; `Surface` via `controller.contextFor(id)`. CORS configurado en backend (`CORS_ORIGINS`, default `localhost:8080` + `127.0.0.1:8080`); la URL de deploy va por env.
- Smoke servers on ephemeral ports (8001+) via `Start-Job`; cleanup via `Remove-Job` + orphan `python.exe` lookup by port.
- Out of MVP scope: OAuth with course platforms, arbitrary student Python/SQL/shell execution on shared servers, training LLM/Jev from scratch, arbitrary Dart codegen in prod, advanced 3D/games/native mobile/social, enterprise multitenancy/billing/large-scale analytics, PostgreSQL migration (keep ORM layer ready).

Open decisions:
- Constraints adjustment requested by user (round 1, Q3 answered "Adjust constraints" without detail). Locked above is the repo-evidenced baseline; the requested delta is unrecorded — confirm what to change before editing this section.

## Brand Commitments

- Name: CognitiveFlow AI. Spanish product voice per plan and seed content.
- Existing visual authority `DESIGN.md` (spec v1.0, 15 Oct 2026) left untouched by this init; no new visual constraints volunteered in this interview.

## Evidence on Hand

- Plan: `COGNITIVEFLOW_PLAN.md` (master, updated 15 Oct 2026); agent rules `AGENTS.md`; design spec `DESIGN.md`; `README.md` run instructions.
- Status 15 Oct 2026: vertical-slice ML without AI + mock evaluation working; Gemini + Jev integration pending.
- Demo seed: 8 modules, 5 users, 3 labs. No fabricated testimonials, benchmarks, or deployment claims — pilot results only.
- Absences future work must not fabricate: no OAuth integrations, no real training-execution backend, no causal learning-efficacy claims.

## Product Principles

1. Active reasoning first: predict, manipulate, argue, retry — interface effort stays low, intellectual effort stays on the learning.
2. Never hand over the solution: orienting questions and hypotheses before direct explanation; direct help only after reasonable attempts, explicit request, or blockage signals.
3. Evidence over activity: evaluate observable justification quality, never clicks/time; progress bars count completed activities, mastery is separate and test-based.
4. Transparent and supervised AI: show evaluation criteria, label mock vs real evaluator, keep every AI score orienting and instructor-editable.
5. Unaided proof closes the loop: each lab ends in a post-test with no hints, no LLM, no immediate feedback.

## Accessibility & Inclusion

- Required standard: WCAG 2.2 AA (normal text 4.5:1, large 3:1, non-text 3:1 where applicable); color never the sole means of information; keyboard-only navigation with visible focus; responsive + text-zoom without hiding actions; selectable text; reduced-motion respect.
- Pilot validation includes confusion checks (incl. low-saturation/grayscale probes) with the 4 students; log individual results without significance claims.
