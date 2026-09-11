# AGENTS.md — SPENT Repository Instructions

## Authority and purpose

This file controls how coding agents work in this repository:
scope, inspection, planning, testing, Preview, Simulator, verification and completion behavior.

`SPENT_DESIGN_CONSTITUTION.md` controls what SPENT should look and feel like.

For workflow and verification, `AGENTS.md` wins.

## Core rule

Work proportionally to the task.

Do not turn a narrow request into:
- an audit
- a refactor
- a test campaign
- a Simulator investigation
- a design-system review
- a repository-wide search

Default workflow:

1. understand the request
2. inspect only the relevant implementation
3. make the requested change
4. perform the minimum relevant check
5. stop

Over-verification is a defect when it slows normal iterative work without adding meaningful confidence.

## Scope discipline

The user's requested scope is authoritative.

If the user says:
- only change this
- small fix
- just polish this
- do not redesign
- work only on this file/component/screen

treat that scope as strict.

Do not:
- refactor unrelated code
- clean up unrelated issues
- inspect unrelated features
- broaden the task
- redesign adjacent screens
- perform unsolicited audits
- continue looking for improvements after the requested task is complete

## Planning behavior

For straightforward small and medium tasks, implement directly.

Do not create:
- long implementation plans
- review checkpoints
- approval documents
- large verification plans

unless:
- the user explicitly asks for a plan
- the task is genuinely ambiguous
- the task is large/risky
- a real architecture/design-system decision requires approval

A local UI edit should not become a planning exercise.

## Design document usage

`SPENT_DESIGN_CONSTITUTION.md` is the canonical visual reference.

For NEW or SUBSTANTIAL visual work:
- read only the relevant sections of the constitution
- inspect relevant Theme tokens
- inspect the target component

For SMALL follow-up visual changes:
- do not reread the full constitution
- use the existing implementation and the summary below
- open the constitution only if there is genuine uncertainty

### SPENT visual summary

- minimal in structure, expressive in color
- modern, young, clean, graphic, warm, intentional
- native in interaction
- city-led in personality
- avoid unnecessary cards and containers
- no generic AI-fintech aesthetic
- no glow
- no glassmorphism overload
- no luminous gradient blobs
- no colored shadow effects
- no glossy finance objects
- no random sparkles/confetti
- reuse existing Theme tokens when practical
- functional screens stay calmer
- onboarding/city/recap/archive may be more graphic and expressive
- preserve business logic during visual work unless explicitly requested
- copy stays descriptive and non-judgmental

These are working constraints, not a mandatory QA checklist.

## Small tasks

Examples:
- spacing/padding
- color
- typography/copy
- corner radius
- one field treatment
- one small component
- one local illustration tweak
- one local animation tweak
- one alignment issue
- one small interaction fix

For small tasks:

- inspect only the target file/component and directly adjacent code if necessary
- make the change directly
- do not run the full test suite
- do not inspect unrelated screens
- do not perform repository-wide audits
- do not create screenshots by default
- do not open Simulator by default
- do not repeatedly build/relaunch
- do not perform broad RTL/accessibility/design audits unless the change directly affects them

Verification:
- one quick targeted sanity check only if necessary
- no full app launch unless the requested behavior genuinely requires runtime integration

Then stop.

## Medium tasks

Examples:
- several related UI components
- a contained interaction/state change
- one screen redesign
- one illustration system
- one local feature

For medium tasks:

- inspect only the relevant feature files
- implement the requested change
- use targeted verification only
- one compile/build check when appropriate
- one final visual check only when the result cannot be judged from code/Preview alone

Do not:
- run unrelated test suites
- inspect unrelated systems
- repeatedly relaunch Simulator
- capture many screenshots
- create long QA reports

## Large / risky tasks

Broader verification is appropriate only for:

- persistence / SwiftData
- migrations
- transaction ingest
- Wallet / App Intents
- backup / restore
- security-sensitive work
- major architecture changes
- release audits
- large cross-feature refactors
- tasks where the user explicitly requests comprehensive testing

Only these should normally trigger broader tests or repository-wide inspection.

## Visual verification — Preview first

For isolated SwiftUI visual components, use this order:

1. SwiftUI Preview
2. minimal targeted compile/build check
3. Simulator only if the requested behavior genuinely depends on full app runtime state

### Tiny visual change

Usually:
- no Simulator
- no screenshots
- no Preview unless it actually helps

### Meaningful illustration / composition change

Examples:
- onboarding city illustration
- recap artwork
- archive city artwork
- complex SwiftUI visual scene

Default:
- implement
- ONE final SwiftUI Preview check when practical
- stop

Only use Simulator if Preview cannot exercise the behavior being changed.

## Hard rule: no Simulator-state investigation for isolated visual work

For an isolated visual component, do NOT:

- run `simctl get_app_container`
- inspect Simulator app containers
- read or modify Simulator `defaults`
- inspect App Group preferences
- search for onboarding-completion flags just to make a screen appear
- reset app state
- delete/reinstall the app
- manipulate persisted data to reach the screen
- repeatedly launch the app to force navigation to the target

If a screen is gated by onboarding, persistence, navigation, or app state:
verify the isolated component with Preview instead.

Do not turn:
“I need to see this SwiftUI view”

into:
“I need to investigate the entire runtime state of the app.”

If Simulator is genuinely necessary:
- launch it once near the end
- check only the requested behavior
- do not manipulate unrelated app state
- stop

## Interaction verification

For a local interaction change such as:
- text-field focus
- swipe
- button behavior
- local navigation

perform one targeted runtime check only when needed.

Do not run unrelated tests.

## Accessibility / RTL / Reduce Motion

These remain product requirements.

They are NOT a mandatory full audit for every task.

Check them when:
- the changed code affects them
- the user explicitly asks
- the task introduces a substantial new component where they are relevant

Do not run a full RTL/LTR/VoiceOver/Dynamic Type review for a tiny unrelated visual tweak.

## Do not repeat verification

Once a relevant check passes, do not repeat it unless later edits could invalidate it.

Do not repeatedly:
- rerun the same test
- rebuild unchanged targets
- relaunch the same screen
- regenerate screenshots
- reread the same files
- reread the full design constitution
- recheck unrelated behavior

One successful relevant check is enough.

## Completion behavior

For small and medium tasks:
- summarize what changed in 1–3 short bullets
- mention only the relevant check actually performed
- stop

Do not:
- produce a long implementation report
- list theoretical risks unrelated to the task
- continue searching after completion
- run extra checks “just to be safe”

## Default principle

Normal visual iteration is NOT release QA.

Small UI work should stay small.

Medium visual work should get one meaningful final check.

Deep verification is reserved for genuinely risky work.

For isolated visual components:
Preview first.
Simulator only when truly required.
