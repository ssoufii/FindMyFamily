# CLAUDE.md — FindMyFamily

Working agreement for AI-assisted work in this repository. Keep this file short. It is read on
every session, so anything that does not change behaviour belongs in `docs/` instead.

## What this is

An AR walking guide that leads a visitor to a specific grave in winter, when snow has buried the
marker. Camera view, arrows on the ground, distance counting down, a beacon at the destination.

**Stack: native iOS. Swift, ARKit, RealityKit, and the ARCore SDK for iOS for the Geospatial
API.** No Unity. No React Native. Decided 2026-07-29; see `docs/DECISIONS.md`.

**iOS only, deliberately and temporarily.** The MVP is an experiment whose job is to answer one
question: can consumer phone hardware place an AR waypoint accurately enough for someone to walk
to it and trust it. Android is deferred until that question is answered, not abandoned. Revisit
the moment M6 concludes. Do not treat iOS-only as permanent, and do not build anything that
would be painful to port.

Current milestone: **M0 — Foundations.** The repository is nearly empty.

Before starting work, state which milestone and which acceptance criterion the work serves. If
you cannot name one, stop and ask.

## Hard rules — the ones that silently break the product

Each of these has produced a real class of bug in AR navigation. They are not style preferences.

1. **Geodetic coordinates are `Double`. Never `Float`.** Single-precision latitude resolves to
   roughly a meter, the same order as the error we are trying to measure. `CLLocationDegrees` is
   already a `Double`; keep it that way.

2. **ARKit works in `Float`. Convert at the boundary, never round-trip.** `simd_float3` and
   RealityKit transforms are single-precision. Do every geodetic and bearing calculation in
   `Double`, convert to `Float` only at the moment of handing a position to ARKit, and never
   convert back and recompute from the `Float`.

3. **The AR world frame is East-Up-South, and North is negative Z.** Use
   `ARConfiguration.WorldAlignment.gravityAndHeading`. In that frame `(1,0,0)` points east,
   `(0,1,0)` points up, and `(0,0,-1)` points **north**. ARKit is right-handed. The ARCore iOS
   Geospatial API uses the same convention — its anchor-creation parameter is literally named
   `eastUpSouthQAnchor`.

   Write the frame in a comment at every conversion site. A dropped sign on Z produces a trail
   that points south instead of north while looking entirely plausible on screen. This is the
   single most likely cause of "it led me to the wrong grave."

4. **All bearings and headings are true north.** Use `CLHeading.trueHeading`, never
   `magneticHeading`, and log both. A negative `trueHeading` or a negative `headingAccuracy`
   means the reading is invalid — treat it as unavailable, never as a bearing of zero. Southern
   Ontario declination is roughly 10° west; an uncorrected 10° error is an 8.7 m lateral miss at
   50 m.

5. **Units and frames live in identifier names.** `let distance: Double` is unacceptable.
   `let distanceMeters: Double` is the minimum bar. Every angle is named or documented as degrees
   or radians, and as true or magnetic.

6. **Never use GNSS altitude for placement.** Vertical error is 5–15 m. Ground height comes from
   ARKit plane detection, a raycast against a detected plane, or an ARCore terrain anchor. If
   plane detection fails on featureless snow, fall back to an assumed device height rather than
   rendering nothing.

7. **Every position carries its uncertainty.** `CLLocation.horizontalAccuracy` is a radius in
   meters, and a negative value means the position is invalid. Never store or display a
   coordinate without its accuracy. A position without its uncertainty is not data.

8. **Log which positioning tier is live, every session.** Geospatial with VPS resolved, Geospatial
   without VPS, or fused sensor fallback are three very different accuracy regimes. The HUD shows
   the platform's own reported numbers, never a figure we invented.

9. **No magic numbers for thresholds.** Arrival radius, accuracy cutoffs, waypoint spacing, and
   calibration thresholds live in one named config type so they can be tuned from field data.

10. **Never swallow a sensor error or a tracking-state change.** `ARCamera.TrackingState`
    transitions, Geospatial accuracy changes, and Core Location failures all get logged and
    surfaced to the user.

## Architecture boundary

`NavigationCore` is a local Swift package containing all the math and state: geodesy, trail
geometry, accuracy tiering, and the navigation state machine.

It must not import **ARKit, RealityKit, UIKit, SwiftUI, or CoreLocation.** Define plain value
types (`GeoCoordinate`, `PositionFix`, `Heading`) inside the package and convert at the app
boundary. Excluding CoreLocation is deliberate: it keeps `swift test` runnable on a Linux CI
runner with no Apple SDK and no simulator.

If a task seems to need `CLLocationCoordinate2D` or `simd_float3` inside `NavigationCore`, the
conversion belongs in the app target instead. Do not relax the boundary to make a task easier;
raise it.

## Testing

- `GeoMath`, `TrailGenerator`, `AccuracyEvaluator`, and the navigation state machine require unit
  tests. They are pure functions and state transitions.
- **Expected values must be derived independently of the implementation** — by hand or from a
  separate trusted tool — with the derivation noted in a comment. A test whose expected value came
  from running the code proves only that the code agrees with itself.
- Geodesy tests cover hemisphere crossings, the antimeridian, near-polar latitudes, zero
  distance, and identical points.
- Include at least one test that would fail if North and South were swapped. Rule 3 needs a
  regression test, not just a comment.
- Never adjust an expected value to make a failing test pass without first establishing which side
  is wrong. Say which one you concluded is wrong and why.
- **ARKit does not run in the Simulator.** Anything touching the AR session is device-only.
  Treat device runs as verification, not iteration.
- Warnings are errors. Do not silence a warning to get a build green.

## Scope

The MVP is: coordinates in, AR trail out, user arrives. Nothing else.

Not in the MVP: accounts, cloud sync, memorial records (names, dates, photos), cemetery maps,
third-party grave databases, sharing, multi-grave routing, voice guidance, journaling or virtual
flowers, path-aware routing around other graves, watch or car companions, monetization.

If a request would build one of those, say so and ask for an explicit scope change rather than
quietly widening the MVP. Deferring is the default answer.

## User-facing strings and visuals

Every string in this app is read by someone standing in a cemetery in the cold, possibly crying.

- Calm, plain, quiet. No exclamation points.
- No gamification: no confetti, streaks, badges, achievements, or nudges to visit.
- State uncertainty rather than hiding it. If position is good to ±6 m, draw a 6 m circle; do not
  draw a pinpoint the data cannot justify.
- Failures explain themselves in plain language, including the number:
  "AR paused — GPS accuracy is currently ±22 m. Using compass mode."
- Never render the trail in white, pale grey, or pale blue. Sunlit snow will erase it. Saturated
  amber or deep orange with a dark outline.
- Touch targets at least 44×44 pt, and prefer larger — the user is wearing gloves. Primary actions
  in the lower third of the screen for one-handed reach.
- Support Dynamic Type and honour Reduce Motion. WCAG 2.2 AA for all 2D UI.

## Secrets and sensitive data

**This repository is public.** A committed key is scraped by bots within minutes.

- Never commit an API key, certificate, provisioning profile, or `.p12`. The Google Cloud key for
  the Geospatial API goes in an untracked local config file; CI reads from repository secrets.
- Never write a real coordinate from a family plot into the repository. Committed fixtures use
  synthetic or offset coordinates; written field results use cemetery-level precision, not
  plot-level.
- Camera imagery leaves the device when the Geospatial API is in use. The disclosure and decline
  path are product requirements, not paperwork. Do not add a code path that sends imagery before
  consent is recorded.
- If you notice a secret or a real plot coordinate in a diff, stop and say so before committing.

## Git

- One concern per commit. Small and reviewable.
- Conventional prefixes: `feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `chore:`.
- Subject lines under 72 characters, imperative mood.
- Never commit `DerivedData/`, `.xcuserdata`, `xcuserdatad`, `Pods/`, or build output.
- Do not commit and push in the same step without being asked to push.

## Working style

- Plan before building. For anything touching more than one file, give a short plan — files
  touched, order of work, how it will be verified — and confirm before writing code.
- Be honest about uncertainty. This project runs on consumer GNSS and mobile AR tracking, both
  noisy. Never state an accuracy figure that has not been measured on a device and recorded in
  `docs/FIELD_TESTS.md`. If you do not know whether something works in the field, say so and
  propose the experiment.
- Ask before deciding anything with user-visible consequences: wording, tone, what happens on
  failure. Assume freely on reversible internal choices such as file layout or helper naming, and
  note the assumption.
- When product instinct and engineering instinct conflict, surface the conflict. State the
  tradeoff, recommend one path, say what is being given up.
- Record significant technical decisions as short ADRs in `docs/DECISIONS.md`: decision,
  alternatives, reason, date.

## Commands

```bash
# Domain tests — fast, headless, no simulator, no Apple SDK required
swift test --package-path Packages/NavigationCore

# App build for a connected device
xcodebuild -project FindMyFamily.xcodeproj -scheme FindMyFamily \
  -destination 'generic/platform=iOS' build
```

Update this section in the same commit that makes a command real.

## Longer references

- `README.md` — setup from clean checkout, prerequisites, secrets handling
- `docs/DECISIONS.md` — architecture decision records
- `docs/FIELD_TESTS.md` — measured accuracy, per trial, with conditions
- The project instructions document — full error budget, acceptance criteria, milestones
