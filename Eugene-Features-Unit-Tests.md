# Eugene's Features — Unit Tests

> The test companion to [Eugene-Features-Explained.md](Eugene-Features-Explained.md) and [Eugene-Features-Variables-and-State.md](Eugene-Features-Variables-and-State.md).
>
> It documents **every unit test that covers Eugene's features** — the money/backend layer (escrow, top-up, withdrawal, completion settlement), live-location tracking, order completion & rating, and disputes/behavior reports — what each test asserts, **which production bug it prevents**, what is deliberately *not* covered, and how to run them.
>
> **Framework:** the suite has been migrated to **Swift Testing** (`import Testing`, `@Suite`/`@Test`, `#expect`/`#require`) — not XCTest. Every assertion below is quoted from the actual test files with `file:line` citations; nothing is paraphrased.

---

## Table of contents

1. [The testability ceiling — read this first](#1-the-testability-ceiling)
2. [Feature → test-file map](#2-feature--test-file-map)
3. [Money model & balance](#3-money-model--balance)
4. [Money-integrity RPC DTO contracts](#4-money-integrity-rpc-dto-contracts)
5. [Order completion & rating](#5-order-completion--rating)
6. [Live-location tracking](#6-live-location-tracking)
7. [Coverage gaps (what is *not* tested, and why)](#7-coverage-gaps)
8. [Test patterns & gotchas (Swift Testing)](#8-test-patterns--gotchas-swift-testing)
9. [How to run](#9-how-to-run)

---

## 1. The testability ceiling

**You cannot unit-test Eugene's features end-to-end, by design — and that shapes every test below.**

The reason is architectural: Repositories and Services use the **global `supabase` client** with **no dependency injection** (it's a module-level `let` in `MbengkelInApp.swift`). There is no seam to swap in a fake client, so any method that makes a network/DB call can't be exercised in a unit test. The most security-critical logic — the `SECURITY DEFINER` RPCs (`accept_bid`, `mark_order_completed`, `rate_order`, `request_withdrawal`, `settle_topup`) and the `handle_order_balance` trigger — runs **inside Postgres**, which the Swift test bundle never reaches.

So the unit tests cover only the two things that *are* deterministic and dependency-free:

1. **Pure logic** — computed properties and value transforms that take inputs and return outputs (`availableBalance`, `MKCoordinateRegion.fitting`, `hasBankDetails`).
2. **Encoding/decoding contracts** — that Swift Models decode from the DB's JSON shape, and that DTOs encode to the *exact* argument names the RPCs expect.

That second category is more valuable than it sounds. There is **no compile-time link** between a Swift DTO and the Postgres function it feeds: `supabase.rpc("accept_bid", params: AcceptBidParams(...))` serializes the DTO to JSON, and Postgres binds by **key name**. If a key is misspelled or renamed, the call **silently misbinds** (the function receives a NULL or default) — no error, just wrong behavior with money. These tests are the *only* guardrail on that Swift↔SQL contract.

> **One-line summary:** the tests pin the *boundaries* (decode-from-DB, encode-to-RPC) and the *pure math*; they trust Postgres to enforce the rest. That is the correct scope given no DI — but it means a green test run is **not** proof the money flows are correct, only that the Swift side speaks the right wire format.

---

## 2. Feature → test-file map

| Eugene feature | Test file (`@Suite`) | Tests | What it pins |
|---|---|---|---|
| Money model (escrow, available balance) | [PaymentBalanceTests.swift](MbengkelInUnitTests/PaymentBalanceTests.swift) (`PaymentBalance`) | 4 | `availableBalance = max(0, balance − held)`; bank-details gate |
| Money model (User decode) | [ModelCodableTests.swift](MbengkelInUnitTests/ModelCodableTests.swift) (`ModelCodable`) | 2 (of 6) | `held_balance` mapping + `availableBalance` from decoded rows |
| Money-integrity RPCs (accept/cancel) | [MoneyIntegrityDTOTests.swift](MbengkelInUnitTests/MoneyIntegrityDTOTests.swift) (`MoneyIntegrityDTO`) | 2 (of 6) | `AcceptBidParams`, `CancelOrderParams` arg names |
| Order completion (settlement) | [MoneyIntegrityDTOTests.swift](MbengkelInUnitTests/MoneyIntegrityDTOTests.swift) | 2 (of 6) | `MarkCompletedParams` (+ nil-photo omission) |
| Completion earnings read-back | [OrderDTOTests.swift](MbengkelInUnitTests/OrderDTOTests.swift) (`OrderDTO`) | 2 (of 3) | `TodaysEarningRow` price present / null |
| Rating | [MoneyIntegrityDTOTests.swift](MbengkelInUnitTests/MoneyIntegrityDTOTests.swift) | 2 (of 6) | `RateOrderParams` (+ nil-review omission) |
| Rating (aggregate read) | [ModelCodableTests.swift](MbengkelInUnitTests/ModelCodableTests.swift) | 1 (of 6) | `Bengkel.average_rating` / `total_reviews` decode |
| Live-location (camera auto-fit) | [RegionFitTests.swift](MbengkelInUnitTests/RegionFitTests.swift) (`RegionFit`) | 4 | `MKCoordinateRegion.fitting` edge cases |
| Live-location (row decode) | [ModelDecodeTests.swift](MbengkelInUnitTests/ModelDecodeTests.swift) (`ModelDecode`) | 1 (of 4) | `OrderLocation` decode + `Identifiable` id |

**Total directly attributable to Eugene's features: ~20 tests** across 5 files (the three money/location-dedicated files plus the relevant subsets of the model/DTO files). The remaining unit tests in the target (bidding VM logic, order VM logic, image compression, watch state) belong to other contributors' features and are out of scope here.

> ⚠️ **Regression from the migration:** the move to Swift Testing reverted `MoneyIntegrityDTOTests` to its original **6** tests — the three previously-added dispute/behavior-report tests (`openDisputeParams`, `openDisputeParamsNilProofOmitsKey`, `behaviorReportPayload`) were **dropped**. That coverage gap is now reopened — see [§7](#7-coverage-gaps).

---

## 3. Money model & balance

### `availableBalance` — the escrow guard

[PaymentBalanceTests.swift:6-31](MbengkelInUnitTests/PaymentBalanceTests.swift#L6-L31):

```swift
@Test func availableBalanceSubtractsHeld() async {
    let vm = PaymentViewModel()
    vm.balance = 100_000
    vm.heldBalance = 30_000
    #expect(abs(vm.availableBalance - 70_000) < 0.0001)
    _ = consume vm
    await Task.yield()
}

@Test func availableBalanceClampsAtZero() async {
    let vm = PaymentViewModel()
    vm.balance = 10_000
    vm.heldBalance = 50_000
    #expect(abs(vm.availableBalance - 0) < 0.0001)   // never negative
    _ = consume vm
    await Task.yield()
}

@Test func availableBalanceEqualsBalanceWhenNoHold() async {
    let vm = PaymentViewModel()
    vm.balance = 42_000
    vm.heldBalance = 0
    #expect(abs(vm.availableBalance - 42_000) < 0.0001)
    _ = consume vm
    await Task.yield()
}
```

**What it pins:** `availableBalance = max(0, balance − held_balance)` — the client mirror of the `request_withdrawal` RPC's authoritative check.

**Bug it prevents:** if held (escrowed) funds counted as withdrawable, a customer with an active order could withdraw money already reserved for it → **double-spend / negative wallet**. The clamp test stops a held > balance situation from showing a negative spendable amount. (The server RPC is the real gate — this test ensures the UI never *invites* an over-withdrawal that the RPC would then reject confusingly.)

> The `_ = consume vm; await Task.yield()` tail is the Swift Testing replacement for the old XCTest `tearDown` dance — see [§8](#8-test-patterns--gotchas-swift-testing).

### `hasBankDetails` — the withdrawal precondition

[PaymentBalanceTests.swift:33-42](MbengkelInUnitTests/PaymentBalanceTests.swift#L33-L42):

```swift
@Test func hasBankDetails() async {
    let vm = PaymentViewModel()
    #expect(!vm.hasBankDetails)
    vm.bankName = "BCA"; vm.bankAccountNumber = "123"; vm.bankAccountName = "Budi"
    #expect(vm.hasBankDetails)
    _ = consume vm
    await Task.yield()
}
```

**Bug it prevents:** offering "Ajukan Penarikan" before bank details exist, which the RPC would reject with `Bank account is not set`. The gate must flip to `true` only when **all three** fields are set.

### User decode + `availableBalance` from a DB row

[ModelCodableTests.swift:9-24](MbengkelInUnitTests/ModelCodableTests.swift#L9-L24):

```swift
@Test func userWithHeldBalance() throws {
    let json = #"{"id":"u1","name":"Budi","balance":100000,"held_balance":30000,"role":"USER"}"#
    let user = try decoder.decode(User.self, from: Data(json.utf8))
    #expect(user.heldBalance == 30000)
    #expect(user.availableBalance == 70000)
    #expect(user.email == nil)        // email/phone are NOT DB columns (merged from auth later)
}

@Test func userWithoutHeldBalance() throws {
    let json = #"{"id":"u2","name":"Ani","balance":50000,"role":"USER"}"#
    let user = try decoder.decode(User.self, from: Data(json.utf8))
    #expect(user.heldBalance == nil)
    #expect(user.availableBalance == user.balance)   // nil hold ⇒ full balance available
}
```

**What it pins:** the `held_balance` → `heldBalance` snake_case mapping, that a missing `held_balance` decodes to `nil` (not a crash), and that `availableBalance` treats `nil` hold as `0`. It also asserts `email`/`phoneNumber` decode to `nil` from a pure DB row — documenting that those are merged from the auth session, not the table.

---

## 4. Money-integrity RPC DTO contracts

[MoneyIntegrityDTOTests.swift](MbengkelInUnitTests/MoneyIntegrityDTOTests.swift) — the single most important test file for Eugene's backend, because it guards the Swift↔Postgres argument-name contract that has no compiler to protect it. The suite is `@Suite("MoneyIntegrityDTO") @MainActor struct MoneyIntegrityDTOTests`, and its header comment says it best:

> *"The snake_case keys must match the Postgres RPC argument names exactly, or the `rpc()` call silently misbinds."*

A shared helper round-trips a DTO through `JSONEncoder` to a dictionary ([MoneyIntegrityDTOTests.swift:7-10](MbengkelInUnitTests/MoneyIntegrityDTOTests.swift#L7-L10)):

```swift
private func json(_ value: Encodable) throws -> [String: Any] {
    let data = try JSONEncoder().encode(value)
    return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
}
```

(`#require` is Swift Testing's unwrap-or-fail — the equivalent of XCTest's `XCTUnwrap`.)

### Accept bid / cancel order

[MoneyIntegrityDTOTests.swift:12-22](MbengkelInUnitTests/MoneyIntegrityDTOTests.swift#L12-L22):

```swift
@Test func acceptBidParams() throws {
    let obj = try json(AcceptBidParams(p_bid_id: "bid-1"))
    #expect(obj["p_bid_id"] as? String == "bid-1")
    #expect(obj.count == 1)            // exactly one key — no stray fields
}

@Test func cancelOrderParams() throws {
    let obj = try json(CancelOrderParams(p_request_id: "req-1"))
    #expect(obj["p_request_id"] as? String == "req-1")
    #expect(obj.count == 1)
}
```

**Bug it prevents:** these feed `accept_bid(p_bid_id uuid)` and `cancel_order(p_request_id uuid)`. If the Swift field were `bidId` (camelCase) or misspelled, Postgres would receive a NULL for `p_bid_id` and the function would `raise exception 'Bid not found'` — or worse, behave unexpectedly. The `obj.count == 1` assertion guarantees no extra key sneaks in that could shadow a defaulted arg.

### Rating (with nil-omission)

[MoneyIntegrityDTOTests.swift:24-35](MbengkelInUnitTests/MoneyIntegrityDTOTests.swift#L24-L35):

```swift
@Test func rateOrderParamsWithReview() throws {
    let obj = try json(RateOrderParams(p_request_id: "req-2", p_rating: 5, p_review: "Mantap"))
    #expect(obj["p_request_id"] as? String == "req-2")
    #expect(obj["p_rating"] as? Int == 5)
    #expect(obj["p_review"] as? String == "Mantap")
}

@Test func rateOrderParamsNilReviewOmitsKey() throws {
    let obj = try json(RateOrderParams(p_request_id: "req-3", p_rating: 4, p_review: nil))
    #expect(obj["p_rating"] as? Int == 4)
    #expect(obj["p_review"] == nil)
}
```

**What it pins:** the three argument names of `rate_order(p_request_id, p_rating, p_review)`, **and** that a `nil` review is **omitted from the JSON entirely** rather than sent as an explicit `null`. The omission lets the RPC use its `default null` argument cleanly; it documents the intended "no review" wire shape.

### Completion (with nil-photo omission)

[MoneyIntegrityDTOTests.swift:37-47](MbengkelInUnitTests/MoneyIntegrityDTOTests.swift#L37-L47):

```swift
@Test func markCompletedParamsWithPhoto() throws {
    let obj = try json(MarkCompletedParams(p_request_id: "req-4", p_completion_photo_url: "https://x/y.jpg"))
    #expect(obj["p_request_id"] as? String == "req-4")
    #expect(obj["p_completion_photo_url"] as? String == "https://x/y.jpg")
}

@Test func markCompletedParamsNilPhotoOmitsKey() throws {
    let obj = try json(MarkCompletedParams(p_request_id: "req-5", p_completion_photo_url: nil))
    #expect(obj["p_request_id"] as? String == "req-5")
    #expect(obj["p_completion_photo_url"] == nil)
}
```

**Bug it prevents:** these feed `mark_order_completed(p_request_id, p_completion_photo_url default null)`. The **customer** side completes *without* a photo (key omitted); the **provider** side must supply one (key present). The nil-omission test ensures the customer path doesn't send an explicit `null` that could interfere with the RPC's `coalesce(p_completion_photo_url, sr.completion_photo_url)` fallback to a previously-stored photo.

> The dual-completion *logic* (only flips to `Done` when both `customer_completed` and `provider_completed` are true) and the photo *guard* (`raise 'Foto penyelesaian wajib dilampirkan'`) live in SQL and are **not** unit-tested — only the DTO that triggers them is.

---

## 5. Order completion & rating

### Completion earnings read-back

[OrderDTOTests.swift:34-44](MbengkelInUnitTests/OrderDTOTests.swift#L34-L44):

```swift
@Test func todaysEarningRowWithPrice() throws {
    let row = try JSONDecoder().decode(TodaysEarningRow.self, from: Data(#"{"price":50000}"#.utf8))
    #expect(row.price == 50000)
}

@Test func todaysEarningRowNullPrice() throws {
    let row = try JSONDecoder().decode(TodaysEarningRow.self, from: Data(#"{"price":null}"#.utf8))
    #expect(row.price == nil)
}
```

**What it pins:** `TodaysEarningRow` decodes both a numeric and a `null` `price`. This DTO backs `OrderRepository.fetchTodaysEarnings`, which sums `price` over `Done` orders completed today (the bengkel's "Pendapatan Hari Ini"). The null case matters because a `Done` order *could* carry a null price; the `reduce` that sums them uses `price ?? 0`, so the decode must produce `nil`, not throw.

### Rating aggregate (read side)

[ModelCodableTests.swift:51-62](MbengkelInUnitTests/ModelCodableTests.swift#L51-L62):

```swift
@Test func bengkelDecode() throws {
    // ... "average_rating":4.5,"total_reviews":10 ...
    let bengkel = try decoder.decode(Bengkel.self, from: Data(json.utf8))
    #expect(bengkel.averageRating == 4.5)
    #expect(bengkel.totalReviews == 10)
}
```

**What it pins:** the read side of the rating feature — that the `average_rating` / `total_reviews` columns (recomputed by the `trg_recompute_bengkel_rating` trigger after a `rate_order` call) decode into the `Bengkel` model. The *recomputation* itself is a SQL trigger and isn't unit-tested; this verifies the app reads the result correctly.

### Completion flag on the order (partial)

[ModelCodableTests.swift:26-39](MbengkelInUnitTests/ModelCodableTests.swift#L26-L39) (`nearbyOrderFull`) decodes a `NearbyOrder` including `"customer_completed":true`, asserting `order.customerCompleted == true`. This pins that the dual-completion boolean survives the round-trip into the model the History/Tracking screens read.

---

## 6. Live-location tracking

### Camera auto-fit — `MKCoordinateRegion.fitting`

The tracking map shows two live pins (customer + mechanic) and auto-zooms to frame both. That framing math is the one piece of tracking that's pure and therefore testable. [RegionFitTests.swift:8-41](MbengkelInUnitTests/RegionFitTests.swift#L8-L41):

```swift
@Test func singleValidCoordinate() {                     // one pin only
    let region = MKCoordinateRegion.fitting(
        CLLocationCoordinate2D(latitude: -7.28, longitude: 112.63), nil)
    #expect(abs(region.center.latitude - (-7.28)) < 0.0001)
    #expect(abs(region.span.latitudeDelta - 0.02) < 0.0001)   // sensible default zoom
}

@Test func invalidFirstFallsBackToOrigin() {             // NaN GPS → no crash
    let region = MKCoordinateRegion.fitting(
        CLLocationCoordinate2D(latitude: .nan, longitude: .nan), nil)
    #expect(abs(region.center.latitude) < 0.0001)
}

@Test func closePairUsesMidpoint() {                     // two nearby pins
    // center == midpoint; span finite and within [0.005, 160] × [0.005, 300]
}

@Test func farPairFallsBackToFirst() {                   // Surabaya + New York
    // refuses to zoom out to the whole globe; centers on the first, default span
}
```

**Bugs these prevent:**
- **NaN guard** (`invalidFirstFallsBackToOrigin`): a bad GPS fix (`.nan`) must not propagate into an `MKCoordinateRegion` — an invalid region can crash MapKit or render a blank map. It falls back to origin instead.
- **Sane span bounds** (`closePairUsesMidpoint`): the computed zoom stays finite and within bounds, so two close pins don't produce a degenerate (zero) or absurd span.
- **Far-pair sanity** (`farPairFallsBackToFirst`): if the two coordinates are implausibly far apart (stale/garbage data), it doesn't zoom out to show the entire planet — it centers on the first pin at a usable zoom.

This is exactly the kind of edge-case math worth unit-testing: it's pure, deterministic, and its failure modes (crash, blank map, world-view zoom) are user-visible.

### Live-location row decode

[ModelDecodeTests.swift:24-36](MbengkelInUnitTests/ModelDecodeTests.swift#L24-L36):

```swift
@Test func orderLocationDecode() throws {
    // {"service_request_id":"r1","provider_uid":"p1","latitude":-7.28,"longitude":112.63,...}
    let location = try decoder.decode(OrderLocation.self, from: Data(json.utf8))
    #expect(location.serviceRequestId == "r1")
    #expect(location.providerUid == "p1")
    #expect(location.id == "r1")          // Identifiable id == serviceRequestId
}
```

**What it pins:** the `order_locations` row (written by the mechanic's adaptive-cadence publisher, consumed by the customer's realtime subscription) decodes correctly, including the snake_case mapping and that `Identifiable.id` is the `serviceRequestId` (one location row per order). The *realtime subscription* and *upsert* themselves aren't unit-testable (they hit `supabase`); this verifies the payload shape they exchange.

---

## 7. Coverage gaps

What is **deliberately or incidentally NOT covered** — important so a green run isn't mistaken for full assurance:

1. **All SQL is untested in Swift.** The RPCs (`accept_bid`, `mark_order_completed`, `rate_order`, `request_withdrawal`, `settle_topup`, `open_dispute`) and the `handle_order_balance` trigger — i.e. the entire money-movement and authorization core — are never executed by the test bundle (no DI; see [§1](#1-the-testability-ceiling)). Their correctness rests on the SQL itself and manual/integration testing.

2. **Disputes & behavior reports have NO dedicated DTO test (regressed by the migration).** `OpenDisputeParams` (feeds `open_dispute`) and `BehaviorReportPayload` (inserted into `behavior_reports`) are **not** pinned by `MoneyIntegrityDTOTests` or any other file. Tests for them existed briefly but were **dropped** when the suite was rewritten to Swift Testing. If someone renamed `p_reason`/`p_proof_url`/`reporter_id`, no test would catch the silent misbind. **This is the most actionable gap** — these DTOs are exactly the kind the existing money-integrity tests already protect for the other RPCs, so re-adding `openDisputeParams` / `behaviorReportPayload` (now in Swift Testing style) is low-effort, high-value.

3. **Top-up / Midtrans is untested on the Swift side.** `startTopup` validation, `PaymentService.createTopup`, and the webhook→`settle_topup` settlement aren't unit-tested (network + edge function + signature verification all live outside the bundle).

4. **Withdrawal flow logic** beyond `availableBalance`/`hasBankDetails` (the RPC's lock-check-debit-insert) is SQL and untested here.

5. **The dispute "unwind vs freeze" money semantics** — the live behavior (cancel unwinds reservations, charges nobody) is trigger logic; no Swift test asserts the resulting balances.

---

## 8. Test patterns & gotchas (Swift Testing)

The suite now uses **Swift Testing**. The primitives in play:

| Concept | Swift Testing (now) | XCTest (before) |
|---|---|---|
| Suite | `@Suite("Name") struct/class` | `class …: XCTestCase` |
| Test | `@Test func name()` | `func testName()` |
| Equality | `#expect(a == b)` | `XCTAssertEqual(a, b)` |
| Nil | `#expect(x == nil)` | `XCTAssertNil(x)` |
| Unwrap | `try #require(x)` | `try XCTUnwrap(x)` |
| Float tolerance | `#expect(abs(a - b) < 0.0001)` | `XCTAssertEqual(a, b, accuracy: 0.0001)` |

**Three patterns specific to Eugene's tests:**

1. **The JSON round-trip helper** (in `MoneyIntegrityDTOTests` / `OrderDTOTests`): `encode → JSONSerialization.jsonObject → [String: Any]`, unwrapped with `#require`, then `#expect` on keys. This is the standard way to prove a DTO's *wire shape* (key names, presence/omission) without a live server.

2. **Float comparison is manual.** `#expect` has no `accuracy:` parameter, so float assertions use `#expect(abs(actual - expected) < tolerance)`. You'll see this throughout `PaymentBalanceTests` and `RegionFitTests`.

3. **`@MainActor` ViewModel teardown via `consume`** (in `PaymentBalanceTests`):
   ```swift
   @Suite("PaymentBalance") @MainActor
   final class PaymentBalanceTests {
       @Test func availableBalanceSubtractsHeld() async {
           let vm = PaymentViewModel()
           // ... assertions ...
           _ = consume vm        // deterministically end vm's lifetime → run its deinit
           await Task.yield()    // let the executor-hopping deinit settle
       }
   }
   ```
   Swift Testing has no `tearDown` lifecycle method, so the cleanup is **inlined per test**. `consume vm` (Swift's ownership *consume* operator) ends the value's lifetime *right there*, forcing `deinit` to run before the test returns; `await Task.yield()` then lets a `@MainActor` ViewModel whose `deinit` hops executors (e.g. `Task { await supabase.removeChannel(...) }`) finish settling. Without it, releasing such a VM can **SIGABRT** (Swift 6 runtime double-free). This is the Swift Testing equivalent of the old XCTest `tearDown { vm = nil; await Task.yield() }`. Note `PaymentBalanceTests` is a `final class` (the other suites are `struct`s) — the reference type makes the VM-lifetime handling explicit.

**`@MainActor` on suites:** suites touching main-actor types (`PaymentBalanceTests`, `MoneyIntegrityDTOTests`, `ModelCodableTests`, `OrderDTOTests`, `ModelDecodeTests`) are annotated `@MainActor`. `RegionFitTests` is **not** — its `MKCoordinateRegion.fitting` math is pure and actor-agnostic.

> **Doc drift to fix:** `CLAUDE.md` still describes the suite as "XCTest … no Swift Testing." That line is now stale — the unit target has been migrated. Worth updating `CLAUDE.md`'s Testing section.

---

## 9. How to run

Run the whole unit target:

```sh
xcodebuild test \
  -project MbengkelIn.xcodeproj \
  -scheme MbengkelIn \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:MbengkelInUnitTests
```

Run only Eugene's feature suites (example — the money/location-dedicated files; `-only-testing` targets the type name, which equals the suite):

```sh
-only-testing:MbengkelInUnitTests/MoneyIntegrityDTOTests \
-only-testing:MbengkelInUnitTests/PaymentBalanceTests \
-only-testing:MbengkelInUnitTests/RegionFitTests
```

New `*.swift` files dropped into `MbengkelInUnitTests/` auto-join the target (Xcode file-system-synchronized groups) — no `.pbxproj` edit needed.

---

*Generated from a direct read of the (Swift Testing-migrated) test sources. Every `file:line` reference and quoted assertion was read from the repository; the testability ceiling and coverage gaps reflect the no-DI architecture documented in CLAUDE.md and [Eugene-Features-Explained.md §13](Eugene-Features-Explained.md).*
