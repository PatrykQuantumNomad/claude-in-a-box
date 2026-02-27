---
phase: quick
plan: 003
type: execute
wave: 1
depends_on: []
files_modified:
  - .planning/milestones/v1.1-MILESTONE-AUDIT.md
  - .planning/milestones/v1.1-ROADMAP.md
  - .planning/milestones/v1.1-REQUIREMENTS.md
  - .planning/milestones/v1.1-RESEARCH-SUMMARY.md
  - .planning/phases/ (directories 01-13 removed)
  - .planning/research/ (directory removed)
  - .planning/REQUIREMENTS.md (removed)
  - .planning/v1.1-MILESTONE-AUDIT.md (removed)
autonomous: true
must_haves:
  truths:
    - "All v1.1 milestone artifacts are in milestones/ alongside v1.0 artifacts"
    - "No stale phase directories remain in .planning/phases/ for completed milestones"
    - "No stale research directory remains at .planning/research/"
    - "Active project files (STATE.md, PROJECT.md, ROADMAP.md, MILESTONES.md, config.json) are untouched"
  artifacts:
    - path: ".planning/milestones/v1.1-MILESTONE-AUDIT.md"
      provides: "v1.1 milestone audit (moved from .planning/ root)"
    - path: ".planning/milestones/v1.1-ROADMAP.md"
      provides: "v1.1 roadmap snapshot for archive"
    - path: ".planning/milestones/v1.1-REQUIREMENTS.md"
      provides: "v1.1 requirements archive"
  key_links: []
---

<objective>
Clean up .planning/ directory after v1.1 milestone completion. Archive all completed milestone
artifacts (phase directories, research, requirements) into milestones/ and remove stale files
from the working directory.

Purpose: Keep .planning/ lean for future milestone work. Currently 1.2MB with 992K in 13
completed phase directories that are no longer needed for active development.

Output: Clean .planning/ with only active project files remaining. All historical data preserved
in milestones/.
</objective>

<context>
@.planning/STATE.md
@.planning/ROADMAP.md
@.planning/MILESTONES.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Archive v1.1 milestone artifacts into milestones/</name>
  <files>
    .planning/milestones/v1.1-MILESTONE-AUDIT.md
    .planning/milestones/v1.1-ROADMAP.md
    .planning/milestones/v1.1-REQUIREMENTS.md
    .planning/milestones/v1.1-RESEARCH-SUMMARY.md
  </files>
  <action>
    Archive v1.1 milestone data alongside the existing v1.0 archives in .planning/milestones/:

    1. Move .planning/v1.1-MILESTONE-AUDIT.md to .planning/milestones/v1.1-MILESTONE-AUDIT.md
       (matches v1.0-MILESTONE-AUDIT.md already in milestones/)

    2. Create .planning/milestones/v1.1-ROADMAP.md: Extract the v1.1 section from ROADMAP.md
       (phases 10-13 details) into a standalone archive file. Add header "# Roadmap Archive: v1.1
       Landing Page" with "Archived: 2026-02-26" and "Status: SHIPPED". Include the phase list
       with plan counts from the current ROADMAP.md v1.1 section.

    3. Create .planning/milestones/v1.1-REQUIREMENTS.md: Copy .planning/REQUIREMENTS.md, update
       header to "# Requirements Archive: v1.1 Landing Page" with "Archived: 2026-02-26" and
       "Status: SHIPPED". Add note "For current requirements, see .planning/REQUIREMENTS.md"
       (matching v1.0 pattern). Then delete .planning/REQUIREMENTS.md.

    4. Create .planning/milestones/v1.1-RESEARCH-SUMMARY.md: Copy .planning/research/SUMMARY.md,
       add archive header "# Research Archive: v1.1 Landing Page" with date. This preserves the
       research summary without keeping all 5 individual research files (128K). The full research
       details are also captured in phase-level RESEARCH.md files within phase directories
       (archived in Task 2).

    Do NOT modify: STATE.md, PROJECT.md, ROADMAP.md, MILESTONES.md, config.json, agent-history.json.
    These are active project files.
  </action>
  <verify>
    ls -la .planning/milestones/ should show 6 files: v1.0-MILESTONE-AUDIT.md, v1.0-REQUIREMENTS.md,
    v1.0-ROADMAP.md, v1.1-MILESTONE-AUDIT.md, v1.1-REQUIREMENTS.md, v1.1-ROADMAP.md,
    v1.1-RESEARCH-SUMMARY.md.
    Verify .planning/v1.1-MILESTONE-AUDIT.md no longer exists at root.
    Verify .planning/REQUIREMENTS.md no longer exists.
  </verify>
  <done>
    All v1.1 milestone artifacts archived in milestones/ with consistent naming convention
    matching v1.0 archives. Original files removed from .planning/ root.
  </done>
</task>

<task type="auto">
  <name>Task 2: Remove completed phase directories and stale research</name>
  <files>
    .planning/phases/ (13 directories removed)
    .planning/research/ (directory removed)
  </files>
  <action>
    Remove all completed phase directories and the global research directory. This is safe because:

    - All phase work is COMPLETE (v1.0 shipped 2026-02-25, v1.1 shipped 2026-02-26)
    - Phase SUMMARYs capture what was built, decisions made, and files modified
    - Key decisions are recorded in STATE.md and PROJECT.md
    - Milestone audits in milestones/ provide high-level completion records
    - ROADMAP.md retains the phase list and plan structure
    - Git history preserves all files if ever needed

    Steps:
    1. Remove all 13 phase directories: rm -rf .planning/phases/01-container-foundation through
       .planning/phases/13-fix-stagger-animation

    2. Remove .planning/research/ directory (128K of v1.1 research files -- SUMMARY.md already
       archived in Task 1, and phase-level RESEARCH.md files contained the same information
       contextualized per-phase)

    3. Verify .planning/phases/ is now empty (directory itself can remain for future phases)

    Do NOT remove .planning/phases/ directory itself -- future milestones will create new phase
    directories here.
  </action>
  <verify>
    ls .planning/phases/ should show no subdirectories.
    ls .planning/research/ should fail (directory removed).
    du -sh .planning/ should show significant reduction from 1.2MB (target under 200K).
  </verify>
  <done>
    All 13 completed phase directories (992K) and research directory (128K) removed.
    .planning/ contains only active project files: STATE.md, PROJECT.md, ROADMAP.md,
    MILESTONES.md, config.json, agent-history.json, milestones/, quick/.
  </done>
</task>

<task type="auto">
  <name>Task 3: Update STATE.md quick tasks table and verify final state</name>
  <files>.planning/STATE.md</files>
  <action>
    1. Add entry to the "Quick Tasks Completed" table in STATE.md:
       | 003 | Clean up planning artifacts -- archive milestone data, remove completed phases | {today's date} | {commit hash} | [003-clean-up-planning-artifacts](./quick/003-clean-up-planning-artifacts/) |
       (Use the actual commit hash from the git commit in this plan)

    2. Verify final .planning/ directory structure is clean:
       .planning/
         STATE.md
         PROJECT.md
         ROADMAP.md
         MILESTONES.md
         config.json
         agent-history.json
         milestones/
           v1.0-MILESTONE-AUDIT.md
           v1.0-REQUIREMENTS.md
           v1.0-ROADMAP.md
           v1.1-MILESTONE-AUDIT.md
           v1.1-REQUIREMENTS.md
           v1.1-ROADMAP.md
           v1.1-RESEARCH-SUMMARY.md
         quick/
           001-update-continue-here-md/
           002-update-state-md-for-ci-fix/
           003-clean-up-planning-artifacts/
         phases/   (empty, ready for next milestone)
  </action>
  <verify>
    ls -la .planning/ should show only the expected files/directories listed above.
    grep "003" .planning/STATE.md should show the new quick task entry.
    du -sh .planning/ should be under 200K.
  </verify>
  <done>
    STATE.md updated with quick task 003 entry. .planning/ directory is clean and under 200K,
    containing only active project files and archived milestones.
  </done>
</task>

</tasks>

<verification>
Final state checklist:
- .planning/ total size under 200K (down from 1.2MB)
- milestones/ has 7 archive files (3 for v1.0, 4 for v1.1)
- phases/ directory is empty
- research/ directory does not exist
- REQUIREMENTS.md does not exist at .planning/ root
- v1.1-MILESTONE-AUDIT.md does not exist at .planning/ root
- STATE.md, PROJECT.md, ROADMAP.md, MILESTONES.md are unchanged (except STATE.md quick task table)
- config.json and agent-history.json are unchanged
- All changes committed to git
</verification>

<success_criteria>
.planning/ directory reduced from 1.2MB to under 200K. All historical data preserved in
milestones/ or git history. Active project files untouched. Ready for next milestone planning.
</success_criteria>

<output>
After completion, update this file or create a summary note in the quick task directory.
</output>
