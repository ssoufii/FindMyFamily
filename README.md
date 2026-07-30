# FindMyFamily

An augmented-reality walking guide to a specific point on the ground, built for cemeteries in
winter.

Snow buries flush grave markers, drifts over headstones, and erases footpaths and section signs.
Map-based apps get a visitor to the right general area and then leave them to search a white field
on foot in the cold. FindMyFamily is an attempt to solve the last twenty meters: raise the phone,
see a trail of arrows on the ground ahead, walk it, arrive.

**Status: pre-MVP, greenfield. Milestone M0.** Nothing here works yet. There is no memorial
database, no accounts, no names or dates, no sharing — by design. See
[Scope](#scope-what-this-repo-is-not-building-yet).

---

## The question the MVP exists to answer

> Can consumer phone hardware, in real outdoor conditions including snow cover, place an AR
> waypoint at a known geographic coordinate accurately and stably enough for a person to walk to
> it and trust it?

If yes, the rest is ordinary app development. If no, we need a different technical approach before
building a product on top of it. The first six milestones are arranged to answer this early and
cheaply. Milestone M1 can kill or redirect the project, and it is deliberately the second thing we
build.

We do not yet know the answer. No accuracy claim appears in this repository unless it was measured
on a device and logged in [`docs/FIELD_TESTS.md`](docs/FIELD_TESTS.md).

---

## Stack, and why

**Native iOS: Swift, ARKit, RealityKit, and the ARCore SDK for iOS for the Geospatial API.**

Decided 2026-07-29 after evaluating Unity + AR Foundation and React Native + ViroReact. Rationale
and the alternatives considered are in [`docs/DECISIONS.md`](docs/DECISIONS.md). The short version:
the product is the AR precision, native is the shortest path from our code to the sensors, and it
is the only stack where the fallback plan — visual relocalization against stored reference features
— is tractable if GPS-grade accuracy turns out to be insufficient.

**iOS only, deliberately and temporarily.** The MVP is an experiment, and an experiment does not
need to be cross-platform. This is a real cost: roughly half the eventual audience, and Android
users skew toward the elderly visitors and out-of-town family in our secondary segments. It is a
recorded amendment to the acceptance criteria below, not an oversight, and it gets revisited the
moment M6 concludes.

---

## Repository layout

Most of this does not exist yet. It is the intended shape, written down so the first commits land
in the right places.

```
.
├── README.md
├── CLAUDE.md                      # working agreement; hard rules for the coordinate math
├── LICENSE                        # TODO: not yet chosen — see Open items
├── .gitignore                     # TODO: needed before the Xcode project lands
├── .swiftlint.yml                 # linting; enforced in CI
├── docs/
│   ├── DECISIONS.md               # ADRs: decision, alternatives, reason, date
│   ├── FIELD_TESTS.md             # every trial, conditions, measured error
│   └── FIELD_TEST_PROTOCOL.md     # how a trial is run, so trials are comparable
├── fixtures/                      # recorded GNSS/heading/AR traces (from M1) — see Privacy
├── ci/
├── Packages/
│   └── NavigationCore/            # pure Swift package: the math and the state machine
│       ├── Package.swift
│       ├── Sources/NavigationCore/
│       │   ├── GeoMath.swift
│       │   ├── TrailGenerator.swift
│       │   ├── AccuracyEvaluator.swift
│       │   ├── NavigationSession.swift
│       │   └── NavigationConfig.swift
│       └── Tests/NavigationCoreTests/
├── FindMyFamily.xcodeproj
└── FindMyFamily/                  # app target
    ├── App/
    ├── AR/                        # ARKit session, RealityKit entities, anchor management
    ├── Adapters/                  # CoreLocation, heading, Geospatial — behind protocols
    ├── Views/                     # SwiftUI: target input, HUD, compass fallback, telemetry
    ├── Config/
    │   └── Secrets.local.xcconfig # UNTRACKED — see Secrets
    └── Resources/
```

### The one architectural rule

`NavigationCore` must not import **ARKit, RealityKit, UIKit, SwiftUI, or CoreLocation.** It defines
its own plain value types and converts at the app boundary.

This is not tidiness for its own sake. The geodesy, bearing math, trail geometry, accuracy tiering,
and session state machine are where the bugs will be, and they are only cheap to test if they can
run without a device. Excluding CoreLocation specifically means `swift test` runs on a Linux CI
runner with no Apple SDK at all. If a task seems to need `CLLocationCoordinate2D` inside the
package, the conversion belongs in `Adapters/`.

---

## Prerequisites

| Requirement | Notes |
| --- | --- |
| macOS + Xcode | Mandatory. Pin the Xcode version here once the project exists and keep CI matched to it. |
| iOS deployment target | ARCore requires a deployment target of 12.0 or higher and building against iOS SDK 15.0 or later. We will target considerably higher for RealityKit; record the chosen floor here. |
| ARCore SDK for iOS | Added via Swift Package Manager from `https://github.com/google-ar/arcore-ios-sdk`, selecting the Geospatial product. CocoaPods also works; SPM is preferred. Add `-ObjC` to Other Linker Flags, set as `$(inherited) -ObjC`. |
| Google Cloud project | The ARCore API must be enabled in a Google Cloud project before the Geospatial API can be used. See [Secrets](#secrets-and-api-keys). |
| Apple Developer Program | Needed for TestFlight, which M6 needs in order to put builds on non-team testers' phones. Free provisioning covers your own devices only and expires after about a week. |
| iPhone | **ARKit does not run in the Simulator.** Every AR feature is device-only, always. |

### Device test matrix

iOS-only for the MVP, so the matrix tests age and hardware capability instead of platform:

- A recent iPhone with dual-band (L1+L5) GNSS
- An iPhone three or more years old
- One LiDAR-equipped Pro model
- One non-LiDAR model

LiDAR is a deliberate variable, not a nicety. Flat unbroken snow defeats *visual* plane detection
because it has no features, but it still has geometry a depth sensor can measure. Whether LiDAR
handles snow well or blooms badly on it is an open question for M1, not a claim.

Profile on the oldest device in the matrix, not the newest.

---

## Setup from a clean checkout

```bash
git clone https://github.com/ssoufii/FindMyFamily.git
cd FindMyFamily
cp FindMyFamily/Config/Secrets.example.xcconfig \
   FindMyFamily/Config/Secrets.local.xcconfig
# open Secrets.local.xcconfig and fill in your own key — see Secrets below
open FindMyFamily.xcodeproj
```

Then:

1. Let Xcode resolve Swift package dependencies on first open.
2. Set your signing team on the app target.
3. Connect a physical iPhone and select it as the run destination. The Simulator will build but
   nothing AR will work.
4. Run.

Verify the domain package independently, without Xcode:

```bash
swift test --package-path Packages/NavigationCore
```

If the project fails to open or a package fails to resolve, that is a bug in this README or in the
pinned dependencies. Fix it here rather than working around it locally.

---

## Secrets and API keys

**This repository is public.** A committed key is scraped by automated bots within minutes, not
days. Treat the rules below as hard.

No key, certificate, or profile is ever committed. Required `.gitignore` entries from day one:
`Secrets.local.xcconfig`, `*.p12`, `*.mobileprovision`, `*.cer`, `DerivedData/`, `.xcuserdata`,
`*.xcuserdatad`, and `Pods/` if CocoaPods ever gets used.

- **Local development:** `FindMyFamily/Config/Secrets.local.xcconfig`, untracked, created by
  copying `Secrets.example.xcconfig`. The example file holds the same keys with empty values and a
  comment explaining where each one comes from.
- **CI:** the same values are injected from repository secrets at build time. CI writes the file,
  uses it, and never logs it.
- **Rotation:** if a key is ever pushed, treat it as compromised. Rotate it in Google Cloud first,
  then worry about git history second.

Restrict the Google Cloud key to this app's bundle ID, and set a quota alert, so a mistake in a
loop costs a warning email rather than a bill.

---

## Running tests

Unit tests are mandatory for `GeoMath`, `TrailGenerator`, `AccuracyEvaluator`, and the session
state machine. Warnings are errors in CI.

```bash
swift test --package-path Packages/NavigationCore
```

Three standing rules:

- Every expected value is derived independently of the implementation — by hand or from a separate
  trusted tool — and the source of the expected value is written in a comment. A test whose
  expected value came from running the code proves only that the code is consistent with itself.
- Edge cases are not optional: hemisphere crossings, the antimeridian, near-polar latitudes, zero
  distance, and identical points.
- At least one test must fail if North and South are swapped. See the frame convention below; that
  bug needs a regression test, not a comment.

Recorded GNSS and heading traces from M1 are checked into `fixtures/` and replayed through a mock
provider, so navigation logic can be exercised in CI without hardware.

---

## Conventions you must know before touching navigation code

These are the sign-error traps. A mirrored or declination-uncorrected trail looks *almost* right,
which is the worst kind of bug.

- **Geodetic coordinates are `Double`.** Never `Float` — single-precision latitude resolves to
  roughly a meter, the same order as the error we are measuring. `CLLocationDegrees` is already a
  `Double`.
- **ARKit works in `Float`.** `simd_float3` and RealityKit transforms are single-precision. Do all
  geodesy in `Double`, convert to `Float` only when handing a position to ARKit, and never convert
  back and recompute.
- **The world frame is East-Up-South, and North is negative Z.** With
  `ARConfiguration.WorldAlignment.gravityAndHeading`, `(1,0,0)` points east, `(0,1,0)` points up,
  and `(0,0,-1)` points **north**. ARKit is right-handed. The ARCore iOS Geospatial API uses the
  same convention — its anchor-creation parameter is named `eastUpSouthQAnchor`. Restate the frame
  in a comment at every conversion site. A dropped sign on Z sends the trail due south while
  looking entirely plausible on screen.
- **Headings are true north, always.** Use `CLHeading.trueHeading`, never `magneticHeading`, and
  log both. A negative `trueHeading` or negative `headingAccuracy` means the value is invalid —
  treat it as unavailable, never as zero. Southern Ontario declination is roughly 10° west; an
  uncorrected 10° error is an 8.7 m lateral miss at 50 m.
- **Units live in names.** `let distance: Double` is unacceptable; `let distanceMeters: Double` is
  the minimum bar. Every angle is documented as degrees or radians, and as true or magnetic.
- **Never use GNSS altitude for placement.** Vertical error is 5–15 m. Ground height comes from
  plane detection, a raycast, or an ARCore terrain anchor — and if plane detection fails on
  featureless snow, from an assumed device height rather than from nothing.
- **Uncertainty travels with position.** `CLLocation.horizontalAccuracy` is a radius in meters and
  a negative value means the fix is invalid. Never store a coordinate without it.
- **No magic numbers.** Arrival radius, accuracy cutoffs, waypoint spacing, and calibration
  thresholds live in `NavigationConfig`.

---

## Field testing

Field testing is engineering work, not a demo. It has a written protocol
([`docs/FIELD_TEST_PROTOCOL.md`](docs/FIELD_TEST_PROTOCOL.md)): physically marked ground-truth
points, repeated trials, structured logs, measured final error, recorded conditions.

Every session logs each state transition with a timestamp, position accuracy, heading accuracy,
tracking state, and which positioning tier was live — Geospatial with VPS resolved, Geospatial
without, or fused sensor fallback. Those three are very different accuracy regimes and a log that
does not distinguish them is not usable data.

Results go in [`docs/FIELD_TESTS.md`](docs/FIELD_TESTS.md), including the trials that went badly —
especially those. Nothing ships on the basis of "it looked right in the parking lot."

---

## Scope: what this repo is _not_ building yet

The MVP is coordinates in, AR trail out, user arrives. Deferred until the acceptance criteria are
met: accounts and cloud sync, memorial records (names, dates, photos), cemetery maps, third-party
grave databases, sharing, multi-grave routing, voice guidance, journaling or virtual flowers,
path-aware routing that avoids walking over other graves, watch and car companions, and
monetization of any kind.

Android is on this list for now, with an explicit revisit trigger: the completion of M6.

If a request conflicts with that list, say so and ask for an explicit scope change rather than
quietly widening the MVP.

---

## Privacy and tone

Three constraints that affect code, not just copy.

**Data.** User location does not leave the device in the MVP. Camera imagery *does* leave the
device whenever the Geospatial API resolves against VPS, and Google's terms require disclosing use
of ARCore and how it collects and processes data, including a prominent link to Google's page on
how it uses data from partner apps. That disclosure comes before the first camera use, in plain
language, with a working decline path that falls back to the fused-sensor tier. Treat it as a
product requirement with a code path, not as paperwork. Grave records are never public or
discoverable by default. No advertising, no data brokerage.

**This repository is public, and that cuts against the line above.** Recorded traces, field logs,
and screenshots will contain real coordinates — plausibly including team members' own family plots
and the addresses where a trace started. Before anything lands in `fixtures/` or
`docs/FIELD_TESTS.md` it gets scrubbed: synthetic or offset coordinates in committed fixtures,
cemetery-level rather than plot-level precision in written results, and no personal plot locations
in the repository at all. Consider making the repository private until M6 is complete.

**Tone.** Every string, animation, and error message in this app will be read by someone standing
in a cemetery in the cold, possibly crying. No confetti, no streaks or badges, no gamification, no
notifications encouraging visits, no exclamation points. Calm, plain, quiet. When the app is
uncertain it says so and shows the uncertainty rather than drawing a confident pinpoint it cannot
justify. Reliability over richness, honesty over confidence, dignity over engagement.

Accessibility target is WCAG 2.2 AA for all 2D UI, with Dynamic Type supported and Reduce Motion
honoured. The 2D compass fallback is the accessibility path as well as the degradation path, so it
is a real screen with real design, not a stub. Touch targets are at least 44×44 pt and preferably
larger, because the user is wearing gloves.

---

## Contributing

- Small, reviewable increments. One concern per commit. Working software at the end of every
  milestone.
- State which milestone and which acceptance criterion your work serves. If you cannot name one,
  stop and ask.
- Record significant technical choices as short ADRs in
  [`docs/DECISIONS.md`](docs/DECISIONS.md) — decision, alternatives, reason, date. Especially
  positioning-strategy choices.
- Never silently swallow a sensor error or a tracking-state change. Log it and surface it.
- Reuse and reposition trail entities rather than creating and destroying them per frame.

## Roadmap

| Milestone | Goal | Exit |
| --- | --- | --- |
| M0 | Foundations | A gray cube renders in AR on two physical iPhones from a clean checkout |
| M1 | Sensor truth | Real accuracy numbers from a real cemetery, logged, per positioning tier |
| M2 | Geo math library | CI green, every function independently verified |
| M3 | Single anchored waypoint | Marker within 3 m of ground truth, 7 of 10 trials, open sky |
| M4 | The trail | A stranger follows it 100 m without help |
| M5 | Robustness and degradation | Every failure path reachable and comprehensible |
| M6 | Winter field trial | Written report against every acceptance criterion, plus an Android decision |

The acceptance criteria in the project instructions specify two Android and two iOS devices. That
is amended to the four-iPhone matrix above for the duration of the MVP. Every other criterion
stands unchanged, including the requirement that the full loop be demonstrated in actual
snow-covered conditions with recorded field tests.

## License

TODO — not yet chosen. Until a `LICENSE` file lands, this is all rights reserved despite the
repository being publicly visible.

## Open items

- License selection.
- Repository visibility: public from creation. Revisit before any field data is committed.
- Owner of the Google Cloud project and billing account for the ARCore API.
- Whether VPS coverage exists inside our target cemeteries at all. Unknown until M1.
- Whether LiDAR depth sensing survives fresh snow. Unknown until M1.
- Android: deferred, revisit at M6.
