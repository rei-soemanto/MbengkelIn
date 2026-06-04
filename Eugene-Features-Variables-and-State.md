# Eugene's Features — Variables & State Over Time

> Companion to [Eugene-Features-Explained.md](Eugene-Features-Explained.md). That doc explains *how the features work*; this one is a **variable-level reference**: every piece of state involved (DB columns, enums, ViewModel `@Published` properties, SQL locals, Model/DTO fields) and **how each value changes over time**.
>
> All declarations were read directly from source; line numbers are cited. Where state evolves, the trigger/method that mutates it is named.

## Contents

- [Part A — Money state over time (the centerpiece)](#part-a--money-state-over-time)
- [Part B — Enum state machines](#part-b--enum-state-machines)
- [Part C — Database columns (mutable state)](#part-c--database-columns-mutable-state)
- [Part D — ViewModel state variables & lifecycles](#part-d--viewmodel-state-variables--lifecycles)
- [Part E — SQL function local variables](#part-e--sql-function-local-variables)
- [Part F — Models & DTOs field reference](#part-f--models--dtos-field-reference)
- [Part G — Cross-cutting patterns & caveats](#part-g--cross-cutting-patterns--caveats)

---

## Part A — Money state over time

The whole money model is **3 columns on `users`** plus one derived value:

| Variable | Where | Meaning |
|---|---|---|
| `balance` | `users.balance` (DB) / `User.balance` / `PaymentViewModel.balance` | Real, settled money |
| `held_balance` | `users.held_balance` / `User.heldBalance` / `PaymentViewModel.heldBalance` | Escrow reserved for the customer's active orders |
| `pending_balance` | `users.pending_balance` / `User.pendingBalance` | Provider earnings reserved but not yet settled |
| `availableBalance` | **computed**, `User.swift:24-26` & `PaymentViewModel.swift:40` | `max(0, balance − held_balance)` — what you may spend/withdraw |

### A.1 — Exact per-transition effects

Every change to these three columns is made by **one trigger**, `handle_order_balance` ([`20260601163700_cancel_unwinds_holds_not_freeze.sql`](supabase/migrations/20260601163700_cancel_unwinds_holds_not_freeze.sql)), plus the top-up/withdrawal paths. This table is the complete set of rules:

| Event (trigger branch) | Customer `balance` | Customer `held` | Provider `balance` | Provider `pending` | Source line |
|---|---|---|---|---|---|
| **Top-up success** (`settle_topup`→`increment_user_balance`) | `+= gross_amount` | — | — | — | `…183944:28` |
| **Order created** (INSERT, `To Do`, price≠null) | — | `+= price` | — | — | `163700:16-18` |
| **Price changed while `To Do`** | — | `+= (new − old)` | — | — | `163700:36-41` |
| **Bid accepted** (`To Do → On Progress`) | — | `+= (new − old)` *(0 if unchanged)* | — | `+= price` | `163700:44-54` |
| **Completed** (`On Progress → Done`) | `−= price` | `−= price` | `+= price` | `−= price` | `163700:57-69` |
| **Cancelled from `To Do`** | — | `−= old price` | — | — | `163700:72-73` |
| **Cancelled from `On Progress`** (dispute) | — | `−= old price` | — | `−= old price` | `163700:72-79` |
| **Order deleted** (`To Do`/`On Progress`) | — | `−= old price` | — | `−= old price` *(if was On Progress)* | `163700:22-33` |
| **Withdrawal requested** (`request_withdrawal`) | `−= amount` | — | — | — | `…183935:38` |
| **Withdrawal rejected** (refund trigger) | `+= amount` | — | — | — | `…044343:32-37` |

All `held`/`pending` decrements are floored with `greatest(0, …)` so they can never go negative.

> **The availability gate.** Before accepting a bid, `accept_bid` checks `balance − held_balance ≥ bid.price` ([`20260601183346_accept_bid_rpc.sql:32-35`](supabase/migrations/20260601183346_accept_bid_rpc.sql#L32-L35)). Withdrawal uses the same available-balance rule ([`20260601183935:34`](supabase/migrations/20260601183935_withdrawal_uses_available_balance.sql#L34)). Escrow is never spendable or withdrawable.

### A.2 — Worked timeline (happy path)

Two users: **Customer C** and **Provider Pr**, both starting at zero. Order/bid price = **60,000**. (C tops up 200,000 first — see the caveat in A.4 for why more than the order price is needed.)

| # | Action | `SR.status` | `bid.status` | C.balance | C.held | C.available | Pr.balance | Pr.pending |
|---|---|---|---|---|---|---|---|---|
| 0 | initial | — | — | 0 | 0 | 0 | 0 | 0 |
| 1 | C top-up 200k settles | — | — | **200k** | 0 | 200k | 0 | 0 |
| 2 | C creates order @60k | **To Do** | — | 200k | **60k** | 140k | 0 | 0 |
| 3 | Pr places bid @60k | To Do | **Pending** | 200k | 60k | 140k | 0 | 0 |
| 4 | C accepts bid | **On Progress** | **Accepted** | 200k | 60k | 140k | 0 | **60k** |
| 5a | both mark completed | **Done** | Accepted | **140k** | **0** | 140k | **60k** | **0** |
| 6 | C rates (no money move) | Done | Accepted | 140k | 0 | 140k | 60k | 0 |
| 7 | Pr withdraws 60k | Done | Accepted | 140k | 0 | 140k | **0** | 0 |

At step 4, the *availability check* is `200k − 60k = 140k ≥ 60k` ✓. Losing bids (if any) flip to `AutoRejected` in the same call.

### A.3 — Alternative branch: cancel / dispute instead of completing

Replaying from the end of step 4 (C: 200k/held 60k; Pr: pending 60k), if the order is **cancelled** (customer "Batalkan" or bengkel "Laporkan Kendala" → `open_dispute` → status `Cancelled`):

| # | Action | `SR.status` | C.balance | C.held | C.available | Pr.balance | Pr.pending |
|---|---|---|---|---|---|---|---|
| 5b | dispute/cancel | **Cancelled** | 200k | **0** | **200k** | 0 | **0** |

C is returned to *exactly* the pre-order state (held released, no charge); Pr's pending is reversed. The `order_disputes` row persists as an informational record only. **No money is frozen** (the old "freeze" behavior was superseded — see [Explained §9](Eugene-Features-Explained.md#9-disputes--freeze)).

### A.4 — ⚠️ Finding: order creation + bid acceptance double-reserve

The order-creation hold is **not** credited toward the accept-time availability check:

- Create order @price `P` → `held = P` (trigger `163700:17`).
- Accept bid @price `B` → check `balance − held ≥ B`, i.e. `balance − P ≥ B`, i.e. **`balance ≥ P + B`**.

So a customer who topped up *exactly* their order price `P` and receives a bid `B = P` will hit **"Saldo tidak cukup"** at accept time (`P − P = 0 < P`). The client-side guard at search start only requires `availableBalance ≥ P` ([`CustomerBiddingViewModel.swift:124-128`](MbengkelIn/ViewModels/CustomerBiddingViewModel.swift#L124-L128)), so the failure surfaces only later, at acceptance. This is why the worked timeline tops up 200k for a 60k order. Worth confirming whether the availability check should add back the order's own existing hold before comparing (it does this for *re-search*, but not in `accept_bid`).

### A.5 — Top-up & withdrawal state machines (money side)

- **Top-up credit is idempotent.** `settle_topup` early-returns if the row is already `success` (`183944:23-25`), so duplicate Midtrans webhooks never double-credit `balance`.
- **Withdrawal debits immediately, refunds on reject.** `balance` drops at request time; if an admin rejects a still-`pending` payout, the refund trigger restores it — but never for an already-`paid` row (`044343:32-37`).

---

## Part B — Enum state machines

Five status enums govern the lifecycles. Each value and every transition:

### B.1 `ServiceStatus` — `service_requests.status`
Values: **To Do · On Progress · Done · Cancelled** (enum predates the in-repo migrations).

```
            accept_bid                 mark_order_completed
            (RPC, balance-checked)     (both flags true)
 [To Do] ───────────────────▶ [On Progress] ──────────────────▶ [Done]   ← terminal
   │                                │
   │ cancel_order (To Do only)      │ open_dispute (On Progress only)
   ▼                                ▼
 [Cancelled] ◀───────────────────── (either path)              ← terminal
```

| From → To | Trigger | Money effect |
|---|---|---|
| To Do → On Progress | `accept_bid` | provider `pending += price` (+ hold delta if price changed) |
| On Progress → Done | `mark_order_completed` (only when `customer_completed AND provider_completed`) | settle both sides |
| To Do → Cancelled | `cancel_order` | release customer hold |
| On Progress → Cancelled | `open_dispute` | release hold + reverse pending |
| (no transition out of Done or Cancelled) | | |

### B.2 `BidStatus` — `bids.status`
Values (in-repo enum, `20260528044343:16`): **Pending · Accepted · Rejected · AutoRejected**.

```
                accept_bid (winner)
 [Pending] ─────────────────────────▶ [Accepted]
     │
     │ accept_bid (every other bid on the order)
     └─────────────────────────────────▶ [AutoRejected]

 [Rejected]  ← written only by the client (CustomerBiddingViewModel:382), not accept_bid
```

> **Doc drift:** `CLAUDE.md` lists an `Expired` value, and the client even writes `"Expired"`/`"Rejected"` directly ([`CustomerBiddingViewModel.swift:399,382`](MbengkelIn/ViewModels/CustomerBiddingViewModel.swift#L382)) — but the **migrated enum has only the 4 values above**. Writing `"Expired"` would fail unless the remote enum was altered out-of-band. Flag for verification.

### B.3 `TopupStatus` — `topups.status`
Values (`20260528044343:4`): **pending · success · failed · expired · cancelled**.

```
            settle_topup('success') → credits balance
 [pending] ──────────────────────────────────────────▶ [success]  ← terminal & idempotent
     ├── settle_topup('failed')    ─▶ [failed]
     ├── settle_topup('expired')   ─▶ [expired]
     └── settle_topup('cancelled') ─▶ [cancelled]
```
Only `success` moves money. Once `success`, any further settle call is a no-op (`183944:23-25`).

### B.4 `WithdrawalStatus` — `withdrawals.status`
Values (`20260528043953:4`): **pending · approved · rejected · paid**.

```
 (request_withdrawal: balance already debited) ─▶ [pending]
        │
        ├─ reject_withdrawal (only if pending) ─▶ [rejected] → refund trigger: balance += amount
        ├─ admin (manual)                      ─▶ [approved]
        └─ admin (manual)                      ─▶ [paid]      ← terminal, no refund
```
`reject_withdrawal` refuses anything not `pending` (`044343:66-68`).

### B.5 dispute `status` — `order_disputes.status` (text check)
Values (`20260601142244:15`): **pending · refunded · paid**.

```
 (open_dispute insert) ─▶ [pending] ──admin SQL──▶ [refunded]
                                    └──admin SQL──▶ [paid]
```
No RPC transitions it — only manual admin SQL ([Explained §12](Eugene-Features-Explained.md#12-admin-dispute-resolution)).

---

## Part C — Database columns (mutable state)

Only the **state-bearing** columns are listed (PKs/FKs/static fields omitted unless they change). Full schema is in [Explained §2–§11](Eugene-Features-Explained.md).

### `users`
| Column | Type | Default | Changes when |
|---|---|---|---|
| `balance` | double | — | topup success; withdrawal request/reject; order Done |
| `held_balance` | double | `0` | order create/accept/complete/cancel/delete |
| `pending_balance` | double | `0` | accept (+); complete/cancel/delete (−) |
| `bank_name` / `bank_account_number` / `bank_account_name` | text | null | profile bank-details update |

### `service_requests`
| Column | Type | Default | Changes when |
|---|---|---|---|
| `status` | `ServiceStatus` | "To Do" | accept_bid / mark_order_completed / open_dispute / cancel_order |
| `price` | bigint | null | set to winning bid in `accept_bid`; edited while To Do |
| `bengkel_id` | uuid | null | set on accept |
| `assigned_at` | timestamptz | null | stamped on accept |
| `customer_completed` | bool | `false` | customer calls mark_order_completed |
| `provider_completed` | bool | `false` | provider calls mark_order_completed (photo required) |
| `completed_at` | timestamptz | null | stamped when → Done |
| `completion_photo_url` | text | null | provider completion |
| `rating` | int 1–5 | null | `rate_order` (write-once) → fires average recompute |
| `review` | text | null | set with rating |
| `updated_at` | timestamptz | — | accept / dispute |

### `bids`
| Column | Type | Default | Changes when |
|---|---|---|---|
| `status` | `BidStatus` | "Pending" | accept_bid → Accepted/AutoRejected |

### `topups`
| Column | Type | Default | Changes when |
|---|---|---|---|
| `status` | `TopupStatus` | "pending" | settle_topup |
| `payment_type` | text | null | coalesced on settle |
| `updated_at` | timestamptz | now() | settle |

### `withdrawals`
| Column | Type | Default | Changes when |
|---|---|---|---|
| `status` | `WithdrawalStatus` | "pending" | reject_withdrawal / admin |
| `notes` | text | null | admin |
| `updated_at` | timestamptz | now() | status change |

### `order_locations` / `customer_locations`
| Column | Type | Changes when |
|---|---|---|
| `latitude` / `longitude` | double | every GPS push (upsert keyed on `service_request_id`) |
| `updated_at` | timestamptz | every push |

### `order_disputes`
| Column | Type | Default | Changes when |
|---|---|---|---|
| `status` | text check | "pending" | admin SQL only |
| `resolved_at` | timestamptz | null | admin resolution |

### `behavior_reports`
Append-only — no mutable state columns (no status). Rows are inserted and read back, never updated.

---

## Part D — ViewModel state variables & lifecycles

`@Published` properties drive the SwiftUI views; private vars are realtime/throttle bookkeeping. Initial values and the methods that mutate them are cited.

### D.1 `PaymentViewModel` ([file](MbengkelIn/ViewModels/PaymentViewModel.swift))
**Published:** `balance:Double=0`, `heldBalance:Double=0`, `topups:[Topup]=[]`, `withdrawals:[Withdrawal]=[]`, `isLoading:Bool=false`, `errorMessage:String?=nil`, `successMessage:String?=nil`, `bankName/bankAccountNumber/bankAccountName:String=""`, `paymentTarget:PaymentTarget?=nil`, `currentOrderId:String?=nil (private(set))`.
**Computed:** `hasBankDetails` (all 3 bank fields non-empty), `availableBalance` (`max(0, balance−heldBalance)`).
**Private bookkeeping:** `realtimeChannel`, `realtimeReaderTasks:[Task]`, `knownSuccessTopupIds:Set<String>`, `didLoadTopupsOnce:Bool=false`.

**Lifecycle over time:**
- `start()` → `refresh()` + `startRealtimeSubscription()`.
- `refresh()` (119-141): sets `balance`, `heldBalance`, the 3 bank fields, then `topups`/`withdrawals`; on error sets `errorMessage`.
- realtime event on `topups`/`withdrawals` → `refresh()`; `detectSuccessfulTopups` sets `successMessage` once per newly-settled top-up (suppressed on first load via `didLoadTopupsOnce`).
- `startTopup` / `saveBankDetails` / `requestWithdrawal`: each sets `isLoading=true`+`errorMessage=nil` at entry, `isLoading=false` at exit; success paths set `currentOrderId`+`paymentTarget` (top-up) or `successMessage`.
- `stop()`/`deinit`: cancels tasks, removes channel.

### D.2 `OrderTrackingViewModel` (customer side, [file](MbengkelIn/ViewModels/OrderTrackingViewModel.swift))
**Published:** `providerCoordinate:CLLocationCoordinate2D?=nil`, `lastUpdated:String?=nil`, `order:NearbyOrder?=nil`, `isLive:Bool=false`.
**Computed:** `status` (`order?.status ?? "On Progress"`), `alreadyRated` (`(order?.rating ?? 0) > 0`).
**Private:** `iInitiatedCancel:Bool=false`, `channel`, `serviceRequestId:String?`, `realtimeReaderTasks`.

**Over time:** `start(serviceRequestId:)` seeds `order`/`providerCoordinate`, opens a channel carrying **two** streams. On each `order_locations` event → re-fetch → `apply()` sets `providerCoordinate`+`lastUpdated`, `isLive=true`. On each `service_requests` event → `order` updated, cancellation notification fired (unless `iInitiatedCancel`). `isLive` flips false whenever the channel isn't `.subscribed`. `openDispute` sets `iInitiatedCancel=true`.

### D.3 `BengkelRouteViewModel` (provider side, [file](MbengkelIn/ViewModels/BengkelRouteViewModel.swift))
**Published:** `order:NearbyOrder?=nil`, `bengkelCoordinate:CLLocationCoordinate2D?=nil`, `customerLiveCoordinate:CLLocationCoordinate2D?=nil`.
**Computed:** `status` (`order?.status ?? "To Do"`).
**Private:** `iInitiatedCancel:Bool=false`, `serviceRequestId`, `customerCoordinate` (static destination for distance), `lastPublishedAt:Date?` (throttle), `channel`, `realtimeReaderTasks`.

**Over time:** every GPS fix sets `bengkelCoordinate`; if `status=="On Progress"`, distance→`interval(forDistance:)` (2s `<1km` / 5s `<3km` / 10s) throttles a `publish()` upsert, advancing `lastPublishedAt`. Channel streams update `order` (→ cancellation notify) and `customerLiveCoordinate`. `reportIssue` sets `iInitiatedCancel=true`, uploads optional proof, opens dispute.

### D.4 `OrderCompletionViewModel` ([file](MbengkelIn/ViewModels/OrderCompletionViewModel.swift))
**Published:** `order:NearbyOrder?=nil`, `isLoading:Bool=false`, `errorMessage:String?=nil`.
**Immutable (`let`):** `requestId:String`, `isCustomer:Bool` (injected in init).
**Computed:** `status`, `isFinished` (Done/Cancelled), `mySideCompleted` (this side's flag).
**Private:** `realtimeChannel`, `realtimeReaderTasks`, `hasLoadedOnce:Bool=false`.

**Over time:** `refresh()` reassigns `order`; before reassigning, `notifyOnCounterpartCompletion` fires a notification when the *opposite* party's `*_completed` flag flips false→true (suppressed on first load via `hasLoadedOnce`). `markCompleted(photoData:)` toggles `isLoading`, uploads the provider photo, sets `order` to the RPC result.

### D.5 `OrderRatingViewModel` ([file](MbengkelIn/ViewModels/OrderRatingViewModel.swift))
**Published:** `isSubmitting:Bool=false`, `errorMessage:String?=nil`. No realtime, no private bookkeeping.
**Over time:** `submit(requestId:rating:review:)` validates `1...5` (else `errorMessage`+return false), toggles `isSubmitting` around the `rate_order` call, trims empty review → nil.

### D.6 `LocationPublishViewModel` (provider GPS, adaptive, [file](MbengkelIn/ViewModels/LocationPublishViewModel.swift))
**Published:** `isPublishing:Bool=false`, `errorMessage:String?=nil`.
**Private:** `serviceRequestId`, `customerCoordinate`, `lastPublishedAt`, `statusChannel`, `statusReaderTask`.
**Over time:** `start(...)` sets `isPublishing=true`, observes the order; each fix throttles via adaptive `interval(forDistance:)` and `publish()`es. When the watched order leaves `On Progress`, `stop()` flips `isPublishing=false` and clears all bookkeeping.

### D.7 `CustomerLocationPublishViewModel` (customer GPS, fixed cadence, [file](MbengkelIn/ViewModels/CustomerLocationPublishViewModel.swift))
**Published:** `isPublishing:Bool=false`, `errorMessage:String?=nil`.
**Immutable:** `minInterval:TimeInterval=3` (fixed 3s, no adaptive interval).
**Private:** `serviceRequestId`, `lastPublishedAt`. No channel/tasks — caller must `stop()` it.

### D.8 `BehaviorReportViewModel` ([file](MbengkelIn/ViewModels/BehaviorReportViewModel.swift))
**Published:** `isSubmitting:Bool=false`, `errorMessage:String?=nil`. No realtime.
**Over time:** `submit(serviceRequestId:reason:)` uses `defer { isSubmitting=false }`; guards session, derives lowercased uid, inserts the report.

> **Shared patterns:** `iInitiatedCancel` (tracking + route) suppresses a self-triggered "other party cancelled" notification. `hasLoadedOnce` / `didLoadTopupsOnce` suppress first-load notifications. `lastPublishedAt` throttles every GPS publisher. No `Timer`/`Task.sleep` polling exists in any VM (realtime-only convention).

---

## Part E — SQL function local variables

| Function | Local | Type | Holds / used for |
|---|---|---|---|
| `settle_topup` | `v_topup` | `topups` rowtype | locked row; reads `.status` (idempotency), `.user_id`+`.gross_amount` (credit) |
| `request_withdrawal` | `v_uid` | uuid | `auth.uid()`; owns the withdrawal |
| | `v_balance` | double | total balance (locked) |
| | `v_held` | double | held; availability check `(v_balance−v_held) < p_amount` |
| | `v_bank_name`/`v_bank_account_number`/`v_bank_account_name` | text | snapshot into the new row; account number must be non-empty |
| | `v_id` | uuid | new withdrawal id (returned) |
| `accept_bid` | `v_bid` | `bids` rowtype | the bid; `.service_request_id`/`.price`/`.bengkel_id` |
| | `sr` | `service_requests` rowtype | locked order; authz + status guard; returned |
| | `v_available` | double | `balance − held_balance`; must cover `v_bid.price` |
| `mark_order_completed` | `sr` | rowtype | order; status guard; returned |
| | `is_customer` | bool | `sr.customer_id = auth.uid()` |
| | `is_provider` | bool | bengkel `provider_uid = auth.uid()`; gates the photo requirement |
| `rate_order` | `sr` | rowtype | `update … returning into`; null ⇒ "Order cannot be rated" |
| `handle_order_balance` | `prov` | uuid | provider uid from `bengkels`; gates all `pending_balance` updates |
| `open_dispute` | `sr` | rowtype | order; On-Progress guard; returned |
| | `is_customer`/`is_provider` | bool | authorization |
| | `v_role` | text | `'customer'`/`'provider'` → `order_disputes.initiator_role` |
| `recompute_bengkel_rating` | `target_bengkel` | uuid | `coalesce(new.bengkel_id, old.bengkel_id)`; bengkel to recompute |
| `reject_withdrawal` | `v_status` | `WithdrawalStatus` | locked status; must be `pending` |

(`refund_rejected_withdrawal` has no `DECLARE` block — it reads `NEW`/`OLD` directly.)

---

## Part F — Models & DTOs field reference

### F.1 Models (`Codable + Identifiable`, CodingKeys map camelCase→snake_case)

- **`User`** ([User.swift:10-40](MbengkelIn/Models/User.swift#L10-L40)): `id, name, profileImageUrl?, balance, heldBalance?, pendingBalance?, email?*, phoneNumber?*, role, bankName?, bankAccountNumber?, bankAccountName?` — `*email`/`phoneNumber` are **excluded from CodingKeys** (merged from auth metadata, not `users` columns). Computed `availableBalance = balance − (heldBalance ?? 0)`.
- **`Topup`** ([Topup.swift:10-34](MbengkelIn/Models/Topup.swift#L10-L34)): `id?, userId, orderId, grossAmount, status, paymentType?, redirectUrl?, snapToken?, createdAt?:Date, updatedAt?:Date`.
- **`Withdrawal`** ([Withdrawal.swift:10-34](MbengkelIn/Models/Withdrawal.swift#L10-L34)): `id?, userId, amount, bankName?, bankAccountNumber?, bankAccountName?, status, notes?, createdAt?:Date, updatedAt?:Date`.
- **`OrderLocation`** ([OrderLocation.swift](MbengkelIn/Models/OrderLocation.swift)): `serviceRequestId, providerUid?, latitude, longitude, updatedAt?:String`; computed `id = serviceRequestId`.
- **`CustomerLocation`** ([CustomerLocation.swift](MbengkelIn/Models/CustomerLocation.swift)): `serviceRequestId, customerId?, latitude, longitude, updatedAt?:String`; computed `id = serviceRequestId`.
- **`NearbyOrder`** ([NearbyOrder.swift:3-51](MbengkelIn/Models/NearbyOrder.swift#L3-L51)): `id, customerId, customerName?, serviceType?, description?, isEmergency?, latitude, longitude, price?:Int, status, tireCount?, photoUrls?:[String], vehicleId?, vehicleInfo?, bengkelId?, rating?:Int, review?, customerCompleted?:Bool, providerCompleted?:Bool, completionPhotoUrl?, createdAt?:String, distanceM?:Double`.
- **`IndonesianBank`** ([Bank.swift:12-47](MbengkelIn/Models/Bank.swift#L12-L47)): **not Codable** — static reference data (`id, name, accountLengths:[Int]`) for client-side validation only.

> **Type inconsistency:** `Topup`/`Withdrawal` use `Date?` timestamps; `OrderLocation`/`CustomerLocation`/`NearbyOrder` use `String?`.

### F.2 DTOs (snake_case fields; RPC-param DTOs use the `p_` arg convention)

| DTO | Kind | Maps to | Fields |
|---|---|---|---|
| `CreateTopupRequest` | edge-fn body | `payment` | `action, amount` (camelCase) |
| `CreateTopupResponse` | edge-fn resp | `payment` | `order_id, redirect_url, token` |
| `BankDetailsUpdatePayload` | table update | `users` | `bank_name, bank_account_number, bank_account_name` |
| `RequestWithdrawalParams` | RPC | `request_withdrawal` | `p_amount:Double` |
| `MarkCompletedParams` | RPC (in **ChatDTOs.swift**) | `mark_order_completed` | `p_request_id, p_completion_photo_url?` |
| `RateOrderParams` | RPC | `rate_order` | `p_request_id, p_rating:Int, p_review?` |
| `OpenDisputeParams` | RPC | `open_dispute` | `p_request_id, p_reason, p_proof_url?` |
| `AcceptBidParams` | RPC | `accept_bid` | `p_bid_id` |
| `CancelOrderParams` | RPC | `cancel_order` | `p_request_id` |
| `ServiceRequestPayload` | table insert | `service_requests` | `customer_id, service_type, description, latitude, longitude, price:Int, is_emergency, status, tire_count, photo_urls?, vehicle_id?, vehicle_info?` |
| `StartSearchPayload` | table update | `service_requests` | `price:Int` |
| `OrderLocationPayload` | upsert | `order_locations` | `service_request_id, provider_uid, latitude, longitude` |
| `CustomerLocationPayload` | upsert | `customer_locations` | `service_request_id, customer_id, latitude, longitude` |
| `BehaviorReportPayload` | table insert | `behavior_reports` | `service_request_id, reporter_id, reason` |
| `TodaysEarningRow` | decode | `service_requests` | `price?:Int` |
| `OrdersRequest`/`PlaceBidRequest` | edge-fn body | `bidding` | camelCase (`serviceRequestId`, `bengkelId`, `radiusMeters`, …) |

(`OrderLocationPayload`, `CustomerLocationPayload`, `BehaviorReportPayload` all live inside `OrderDTOs.swift`, not separate files. Insert payloads require `provider_uid`/`customer_id` non-optional, unlike the matching Models.)

---

## Part G — Cross-cutting patterns & caveats

1. **Three numbers, one trigger.** `balance`/`held_balance`/`pending_balance` are only ever moved by `handle_order_balance` (orders) and the topup/withdrawal paths. Part A.1 is the complete rulebook.

2. **`availableBalance` is the spendable view** and exists in two places (`User.swift:24`, `PaymentViewModel.swift:40`) plus mirrored server-side in `accept_bid` and `request_withdrawal`. Escrow is never spendable.

3. **Double-reservation finding (A.4)** — accepting a bid requires `balance ≥ orderPrice + bidPrice` because the creation hold isn't credited back during the accept check. Likely a bug; verify.

4. **`BidStatus` enum drift (B.2)** — the client writes `"Expired"`/`"Rejected"` but the migrated enum has only `Pending/Accepted/Rejected/AutoRejected`. `"Expired"` is not a valid enum value in-repo.

5. **Timestamp type split (F.1)** — `Date?` for payments, `String?` for locations/orders. Harmless but inconsistent.

6. **Terminal states never reverse:** `Done`, `Cancelled` (orders), `success` (topup, idempotent), `paid` (withdrawal). Build no UI that expects to move out of them.

7. **First-load suppression flags** (`didLoadTopupsOnce`, `hasLoadedOnce`) and **self-cancel flags** (`iInitiatedCancel`) exist purely to avoid spurious notifications — they hold no business data.

---

*Companion to [Eugene-Features-Explained.md](Eugene-Features-Explained.md). Every declaration and line number was read directly from source.*
