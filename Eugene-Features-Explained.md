# Eugene's Features — End-to-End Explained

> A complete, code-level walkthrough of the features Eugene (`aeugene-uc`) primarily owns in **MbengkelIn**: the **money/backend layer** (escrow, top-up, withdrawal, completion settlement), **live-location tracking**, **order completion & rating**, and **disputes / behavior reports**.
>
> Every claim below is traced **frontend → ViewModel → Repository/Service → Supabase (RPC / edge function / table / trigger)** with real code excerpts and `file:line` citations. Read it top-to-bottom, or jump via the table of contents.
>
> **Companion:** [Eugene-Features-Variables-and-State.md](Eugene-Features-Variables-and-State.md) — a variable-level reference: every DB column, enum, ViewModel `@Published` property, SQL local, and Model/DTO field, plus how each value changes over time (including a worked balance timeline).

---

## Table of Contents

1. [Architecture recap (how the layers connect)](#1-architecture-recap)
2. [The money model (read this first)](#2-the-money-model)
3. [Top-up (Midtrans)](#3-top-up-midtrans)
4. [Withdrawal (+ bank details)](#4-withdrawal--bank-details)
5. [Live-location tracking](#5-live-location-tracking)
6. [Order completion (dual-completion → `Done`)](#6-order-completion)
7. [Rating](#7-rating)
8. [Money-integrity backend (escrow lifecycle + security)](#8-money-integrity-backend)
9. [Disputes & freeze](#9-disputes--freeze)
10. [Behavior reports](#10-behavior-reports)
11. [Completion-photo guard](#11-completion-photo-guard)
12. [Admin dispute resolution (manual SQL)](#12-admin-dispute-resolution)
13. [Caveats & doc-accuracy notes](#13-caveats--doc-accuracy-notes)

---

## 1. Architecture recap

MbengkelIn is **layered MVVM** over Supabase. For Eugene's features the chain is always:

```
View (SwiftUI)
  → ViewModel (@MainActor, @Published state)
    → Repository (supabase.from("table") / supabase.rpc(...))   ← DB tables & RPCs
    → Service     (supabase.functions.invoke / Storage / SDK)   ← edge functions, storage
      → Supabase: RPC (SECURITY DEFINER) / edge function / table
        → Postgres triggers move money & recompute aggregates
```

Two rules dominate the backend design of Eugene's work:

- **The client is treated as hostile.** Direct table writes for money/status columns are *revoked*; every state transition goes through a `SECURITY DEFINER` RPC that derives identity from `auth.uid()` — never from a client-passed id.
- **Realtime, never polling.** Live updates ride Supabase `postgresChange` channels; the project bans `Task.sleep` refresh loops.

---

## 2. The money model

All money lives on the **`users`** table. Three columns matter:

| Column | Meaning |
|---|---|
| `balance` | Total wallet balance. |
| `held_balance` | Escrow reserved for the customer's **active** orders. |
| `pending_balance` | Provider earnings reserved for `On Progress` orders, not yet settled into `balance`. |

**Derived (client-only):** `availableBalance = max(0, balance − held_balance)` — computed in [`PaymentViewModel.swift:40`](MbengkelIn/ViewModels/PaymentViewModel.swift#L40). It is **not** a DB column; it's the amount a user may actually spend or withdraw. Escrowed money can never be withdrawn.

`held_balance` / `pending_balance` are introduced in [`20260528141836_order_balance_holds.sql:1-2`](supabase/migrations/20260528141836_order_balance_holds.sql#L1-L2).

**How money moves over an order's life** (all driven by the `handle_order_balance` trigger on `service_requests`):

| Transition | Effect |
|---|---|
| Order created (`To Do`) | Customer `held_balance += price` (funds reserved) |
| Price changed while `To Do` | Hold adjusted by the delta |
| Bid accepted (`To Do → On Progress`) | Provider `pending_balance += price` (customer hold stays; nothing leaves `balance` yet) |
| Completed (`On Progress → Done`) | Customer `balance -= price` + hold released; provider `balance += price` + pending released |
| Cancelled (any) | Reservations unwound, **nobody charged** (current behavior — see §9) |

**Hard guarantee:** clients cannot write `balance`, `held_balance`, `pending_balance`, or `role` at all. Direct `UPDATE` on `users` is revoked and re-granted only for profile + bank columns — [`20260601191847_rls_money_integrity_hardening.sql:12-16`](supabase/migrations/20260601191847_rls_money_integrity_hardening.sql#L12-L16). All money movement therefore must pass through `SECURITY DEFINER` RPCs/triggers.

---

## 3. Top-up (Midtrans)

The customer tops up their wallet through **Midtrans Snap**. The app *creates* the transaction through an authenticated edge function and opens the Snap web flow; the balance is *credited asynchronously* by a signed **webhook → `settle_topup` RPC**. The client never credits the balance itself.

### Call chain

| # | Step | Location |
|---|---|---|
| 1 | "Top Up Sekarang" → `viewModel.startTopup(amount:)` | [`PaymentView.swift:134-135`](MbengkelIn/Views/Pages/Payment/PaymentView.swift#L134-L135) |
| 2 | Validate min/max, call service, present Snap WebView sheet | [`PaymentViewModel.swift:160-183`](MbengkelIn/ViewModels/PaymentViewModel.swift#L160-L183) |
| 3 | `PaymentService.createTopup(amount:)` invokes `payment` edge fn | [`PaymentService.swift:5-12`](MbengkelIn/Services/PaymentService.swift#L5-L12) |
| 4 | Edge fn: auth-check JWT, insert `pending` topup, call Midtrans Snap | [`payment/index.ts`](supabase/functions/payment/index.ts) |
| 5 | `MidtransWebView` loads Snap URL; on redirect → `paymentFlowFinished()` (refresh only) | [`MidtransWebView.swift`](MbengkelIn/Views/Components/Features/Payment/MidtransWebView.swift), [`PaymentViewModel.swift:248-251`](MbengkelIn/ViewModels/PaymentViewModel.swift#L248-L251) |
| 6 | Midtrans → `midtrans-webhook`: verify SHA-512 signature, call `settle_topup` | [`midtrans-webhook/index.ts`](supabase/functions/midtrans-webhook/index.ts) |
| 7 | `settle_topup` RPC atomically + idempotently credits balance | [`20260601183944_settle_topup_atomic.sql`](supabase/migrations/20260601183944_settle_topup_atomic.sql) |

### Critical code

**ViewModel** ([`PaymentViewModel.swift:160-178`](MbengkelIn/ViewModels/PaymentViewModel.swift#L160-L178)):

```swift
func startTopup(amount: Int) async {
    guard amount >= minTopupAmount else { ... return }
    guard amount <= maxTopupAmount else { ... return }
    isLoading = true; errorMessage = nil
    do {
        let response = try await paymentService.createTopup(amount: amount)
        self.currentOrderId = response.order_id
        if let url = URL(string: response.redirect_url) {
            self.paymentTarget = PaymentTarget(url: url)   // presents the Snap WebView sheet
        } else { self.errorMessage = "URL pembayaran tidak valid." }
    } catch { self.errorMessage = error.localizedDescription }
    isLoading = false
}
```

**Edge function (create)** — auth, pending insert, Snap call ([`payment/index.ts`](supabase/functions/payment/index.ts)):

```ts
const { data: userData, error: userError } = await userClient.auth.getUser();
if (userError || !userData?.user) return json({ error: "Unauthorized" }, 401);
...
const orderId = `topup-${user.id.slice(0, 8)}-${Date.now()}`;
const { error: insertError } = await adminClient.from("topups").insert({
  user_id: user.id, order_id: orderId, gross_amount: amount, status: "pending",
});
...
const snapResponse = await fetch(SNAP_BASE_URL, {
  method: "POST",
  headers: { ..., Authorization: authHeader() },   // Basic base64(serverKey + ":")
  body: JSON.stringify(snapBody),
});
return json({ order_id: orderId, redirect_url: snapData.redirect_url, token: snapData.token });
```

**Webhook** — signature verify, then settle ([`midtrans-webhook/index.ts:39-58`](supabase/functions/midtrans-webhook/index.ts#L39-L58)):

```ts
const valid = await verifySignature(orderId, statusCode, grossAmount, signatureKey);
if (!valid) return json({ error: "Invalid signature" }, 403);
const newStatus = mapTransactionStatus(transactionStatus, fraudStatus);
const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
const { error } = await adminClient.rpc("settle_topup", {
  p_order_id: orderId, p_status: newStatus, p_payment_type: paymentType,
});
```

**Signature check** — SHA-512 of `order_id + status_code + gross_amount + serverKey` ([`_shared/midtrans.ts:34-47`](supabase/functions/_shared/midtrans.ts#L34-L47)):

```ts
const raw = orderId + statusCode + grossAmount + MIDTRANS_SERVER_KEY;
const digest = await crypto.subtle.digest("SHA-512", new TextEncoder().encode(raw));
const hex = Array.from(new Uint8Array(digest)).map(b => b.toString(16).padStart(2, "0")).join("");
return hex === signatureKey;
```

**Atomic settlement RPC** ([`20260601183944_settle_topup_atomic.sql:14-36`](supabase/migrations/20260601183944_settle_topup_atomic.sql#L14-L36)):

```sql
select * into v_topup from public.topups where order_id = p_order_id for update;
if not found then raise exception 'Top-up not found'; end if;
-- Idempotent: an already-successful topup is never touched again (no double-credit).
if v_topup.status = 'success' then return; end if;
if p_status = 'success' then
  perform public.increment_user_balance(v_topup.user_id, v_topup.gross_amount);
end if;
update public.topups
  set status = p_status::"TopupStatus",
      payment_type = coalesce(p_payment_type, payment_type),
      updated_at = now()
  where order_id = p_order_id;
```

### Integrity highlights

- **Idempotent webhook:** Midtrans may deliver duplicate notifications; the `if status = 'success' then return` early-out prevents double-crediting.
- **Signature gate:** mismatch → `403` *before* any DB touch.
- **Privilege lockdown:** `increment_user_balance` and `settle_topup` are revoked from `authenticated`/`anon`; `settle_topup` is granted only to `service_role` — [`20260601192326_lock_down_rpc_execute_grants.sql:12-16`](supabase/migrations/20260601192326_lock_down_rpc_execute_grants.sql#L12-L16). A logged-in user cannot self-credit.
- **`topups` table:** `id, user_id, order_id (unique), gross_amount, status, payment_type, redirect_url, snap_token, …` — [`20260528032101_topups_and_balance.sql:3-14`](supabase/migrations/20260528032101_topups_and_balance.sql#L3-L14). RLS is select-own only; all writes are by the edge function's `service_role` client.
- **Resume pending top-up:** a `pending` row with a stored `redirect_url` is tappable in history → reopens the same Snap URL ([`PaymentViewModel.swift:238-244`](MbengkelIn/ViewModels/PaymentViewModel.swift#L238-L244)).

---

## 4. Withdrawal (+ bank details)

A withdrawal is fully server-side: the **`request_withdrawal` RPC** does an authoritative available-balance check, debits the user, and inserts a `pending` payout. Rejecting a pending payout refunds the money.

### Bank details first

| Step | Location |
|---|---|
| `BankDetailsView` validates bank + account length against `IndonesianBank` table | [`BankDetailsView.swift:74-86`](MbengkelIn/Views/Pages/Payment/BankDetailsView.swift#L74-L86), [`Bank.swift`](MbengkelIn/Models/Bank.swift) |
| `PaymentViewModel.saveBankDetails(...)` builds `BankDetailsUpdatePayload` | [`PaymentViewModel.swift:185-206`](MbengkelIn/ViewModels/PaymentViewModel.swift#L185-L206) |
| `UserRepository.updateBankDetails(uid:payload:)` → `users` update | [`UserRepository.swift:35-40`](MbengkelIn/Repositories/UserRepository.swift#L35-L40) |

(Allowed because bank columns are explicitly re-granted in the hardening migration.)

### Withdrawal call chain

| # | Step | Location |
|---|---|---|
| 1 | "Ajukan Penarikan" → `viewModel.requestWithdrawal(amount:)` (client pre-validates) | [`WithdrawView.swift:84-88`](MbengkelIn/Views/Pages/Payment/WithdrawView.swift#L84-L88) |
| 2 | Re-validate (`>= 10000`, `<= balance`, `hasBankDetails`), call repo | [`PaymentViewModel.swift:208-234`](MbengkelIn/ViewModels/PaymentViewModel.swift#L208-L234) |
| 3 | `WithdrawalRepository.requestWithdrawal` → `rpc("request_withdrawal")` | [`WithdrawalRepository.swift:14-19`](MbengkelIn/Repositories/WithdrawalRepository.swift#L14-L19) |
| 4 | RPC: check + debit + insert pending payout | [`20260601183935_withdrawal_uses_available_balance.sql`](supabase/migrations/20260601183935_withdrawal_uses_available_balance.sql) |
| 5 | Reject → refund (admin RPC or trigger) | [`20260528044343_status_enums_and_withdrawal_refund.sql`](supabase/migrations/20260528044343_status_enums_and_withdrawal_refund.sql) |

### Critical code

**Authoritative RPC** — available-balance check, debit, insert ([`20260601183935_withdrawal_uses_available_balance.sql:18-47`](supabase/migrations/20260601183935_withdrawal_uses_available_balance.sql#L18-L47)):

```sql
v_uid uuid := auth.uid();          -- never trusts a client-passed id
if v_uid is null then raise exception 'Not authenticated'; end if;
if p_amount < 10000 then raise exception 'Minimum withdrawal is Rp10.000'; end if;
select balance, held_balance, bank_name, bank_account_number, bank_account_name
  into v_balance, v_held, v_bank_name, v_bank_account_number, v_bank_account_name
  from public.users where id = v_uid for update;             -- row lock
if v_bank_account_number is null or v_bank_account_number = '' then
  raise exception 'Bank account is not set'; end if;
if (v_balance - coalesce(v_held, 0)) < p_amount then          -- AVAILABLE, not total
  raise exception 'Insufficient balance'; end if;
update public.users set balance = balance - p_amount where id = v_uid;
insert into public.withdrawals
  (user_id, amount, bank_name, bank_account_number, bank_account_name, status)
  values (v_uid, p_amount, v_bank_name, v_bank_account_number, v_bank_account_name, 'pending')
  returning id into v_id;
```

**Rejection refund trigger** ([`20260528044343_status_enums_and_withdrawal_refund.sql:31-47`](supabase/migrations/20260528044343_status_enums_and_withdrawal_refund.sql#L31-L47)):

```sql
if NEW.status = 'rejected'
   and OLD.status is distinct from NEW.status
   and OLD.status <> 'paid' then
  update public.users set balance = balance + NEW.amount where id = NEW.user_id;
end if;
```

### Integrity highlights

- **Escrow can't be withdrawn:** the guard is `(balance − held_balance) < amount`. The client mirrors this via `availableBalance`, but the RPC is the source of truth.
- **Atomic:** lock row `FOR UPDATE` → check → debit `balance` → insert `pending` row, in one transaction. The bank snapshot is copied into the withdrawal row at request time.
- **Trust boundary:** RPC uses `auth.uid()`; direct `users` UPDATE is revoked. `request_withdrawal` is `authenticated`-only; `reject_withdrawal` is `service_role`-only (admin).
- **Refunds** restore money — via `reject_withdrawal` RPC or the `trg_refund_rejected_withdrawal` trigger — and guard against double-refunding an already-`paid` row.

---

## 5. Live-location tracking

When an order is `On Progress`, the assigned **bengkel** streams its live GPS to the en-route **customer**, who watches it move on a map. It's **symmetric**: the customer also publishes their position back. Two tables — `order_locations` (provider) and `customer_locations` (customer) — are written by adaptive-cadence `CLLocationManager` publishers and consumed via Realtime subscriptions filtered to the active `service_request_id`.

> There is **no drawn route polyline and no ETA**. "Route" = two live pins on an Apple `Map`, auto-zoomed to fit both. Proximity surfaces only as an 80 m "near" threshold that enables the Complete button.

### Publishing chain (provider side)

`CLLocationManager` → ViewModel delegate → throttle → `OrderLocationRepository.upsertLocation` → `order_locations` upsert (`onConflict: service_request_id`, so exactly one row per order, overwritten each fix).

| Step | Method | Location |
|---|---|---|
| Receive fix, gate on `On Progress`, throttle | `locationManager(_:didUpdateLocations:)` | [`BengkelRouteViewModel.swift:164-177`](MbengkelIn/ViewModels/BengkelRouteViewModel.swift#L164-L177) |
| Distance→interval (2s `<1km`, 5s `<3km`, else 10s) | `interval(forDistance:)` | [`BengkelRouteViewModel.swift:181-187`](MbengkelIn/ViewModels/BengkelRouteViewModel.swift#L181-L187) |
| Resolve uid, build payload, upsert | `publish(coordinate:requestId:)` | [`BengkelRouteViewModel.swift:189-198`](MbengkelIn/ViewModels/BengkelRouteViewModel.swift#L189-L198) |
| Upsert to DB | `OrderLocationRepository.upsertLocation(_:)` | [`OrderLocationRepository.swift:12-16`](MbengkelIn/Repositories/OrderLocationRepository.swift#L12-L16) |

```swift
func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last else { return }
    self.bengkelCoordinate = location.coordinate
    guard status == "On Progress", let requestId = serviceRequestId else { return }  // only when active
    let distance = customerCoordinate.map {
        location.distance(from: CLLocation(latitude: $0.latitude, longitude: $0.longitude))
    } ?? .greatestFiniteMagnitude
    let minInterval = interval(forDistance: distance)   // 2s/5s/10s by proximity
    if let last = lastPublishedAt, Date().timeIntervalSince(last) < minInterval { return }
    lastPublishedAt = Date()
    Task { await publish(coordinate: location.coordinate, requestId: requestId) }
}
```

```swift
func upsertLocation(_ payload: OrderLocationPayload) async throws {
    try await supabase.from("order_locations")
        .upsert(payload, onConflict: "service_request_id")
        .execute()
}
```

A second publisher, `LocationPublishViewModel`, has the identical publish path and additionally auto-`stop()`s when the order leaves `On Progress` ([`LocationPublishViewModel.swift:66-83`](MbengkelIn/ViewModels/LocationPublishViewModel.swift#L66-L83)).

### Consuming chain (customer side)

Realtime `postgresChange` on `order_locations` → **event is just a trigger** → re-fetch the row → `apply()` → `@Published providerCoordinate` → map pin + auto-fit.

```swift
let channel = supabase.channel("order-tracking-\(serviceRequestId)")
let locationStream = channel.postgresChange(
    AnyAction.self, schema: "public", table: "order_locations",
    filter: "service_request_id=eq.\(serviceRequestId)")
realtimeReaderTasks.append(Task { [weak self] in
    await channel.subscribe()
    Task { [weak self] in
        for await _ in locationStream {                       // event = re-fetch trigger
            if let location = try? await self?.locationRepository
                .fetchLocation(serviceRequestId: serviceRequestId) {
                self?.apply(location)        // → @Published providerCoordinate
                self?.isLive = true
            }
        }
    }
})
```

([`OrderTrackingViewModel.swift:55-89`](MbengkelIn/ViewModels/OrderTrackingViewModel.swift#L55-L89)) — the same channel also carries a stream on `service_requests` (filter `id=eq.<id>`) to react to status flips (Done → prompt review, Cancelled → notify).

The mechanic consumes the customer's location symmetrically via `customer_locations` ([`BengkelRouteViewModel.swift:88-93`](MbengkelIn/ViewModels/BengkelRouteViewModel.swift#L88-L93)); the customer's publisher is `CustomerLocationPublishViewModel`.

### Map rendering

- Tracking screens use SwiftUI `Map` with **Apple MapKit default tiles** — *not* the OSM overlay.
- The OSM tile overlay (`OSMTileOverlay : MKTileOverlay`) in [`OrderMapView.swift`](MbengkelIn/Views/Components/Features/Order/OrderMapView.swift) is used only by the order-*creation* map.
- **Photon** (`LocationService`) is geocoding for address search — **not used** in tracking; tracking consumes raw lat/long.
- Auto-fit camera: `MKCoordinateRegion.fitting(_:_:)` ([`MKCoordinateRegion+Fit.swift:11-55`](MbengkelIn/Extensions/MKCoordinateRegion+Fit.swift#L11-L55)), invoked once per screen (`didFitBoth` guard) when the counterpart's first live coordinate arrives.

### Realtime prerequisites

| Migration | Sets up |
|---|---|
| [`20260529031243_order_live_locations.sql`](supabase/migrations/20260529031243_order_live_locations.sql) | Creates `order_locations` (PK `service_request_id`); RLS (provider INSERT/UPDATE own, both parties SELECT); adds to `supabase_realtime` publication |
| [`20260601122732_order_locations_replica_identity_full.sql`](supabase/migrations/20260601122732_order_locations_replica_identity_full.sql) | `replica identity full` — **required** so the filtered (`service_request_id=eq.<id>`) UPDATE subscription keeps matching past the first position |
| [`20260601124112_customer_live_locations.sql`](supabase/migrations/20260601124112_customer_live_locations.sql) | Creates `customer_locations` (mirror); RLS; publication + replica identity full |

Both realtime conditions hold: (1) table is in the publication, (2) RLS grants `SELECT` to the non-owning party — so each side receives the other's movement live without polling. Channels are torn down on `stop()` / `deinit` / `.onDisappear`.

---

## 6. Order completion

An `On Progress` order requires **both** parties to confirm before it becomes `Done`. Each side flips its own boolean (`customer_completed` / `provider_completed`); the RPC flips `status='Done'` + stamps `completed_at` only when **both** are true, and the balance trigger settles the money on that transition.

### Call chain

| # | Step | Location |
|---|---|---|
| 1 | Customer = confirm button; provider = `PhotosPicker` (photo mandatory) | [`CompleteOrderButton.swift:52-74`](MbengkelIn/Views/Components/Features/Order/Completion/CompleteOrderButton.swift#L52-L74) |
| 2 | `markCompleted(photoData:)` uploads photo (provider), calls repo | [`OrderCompletionViewModel.swift:108-122`](MbengkelIn/ViewModels/OrderCompletionViewModel.swift#L108-L122) |
| 3 | `OrderRepository.markOrderCompleted` → `mark_order_completed` RPC | [`OrderRepository.swift:99-108`](MbengkelIn/Repositories/OrderRepository.swift#L99-L108) |
| 4 | RPC flips flags, settles on both-true | [`20260601184934_completion_photo_guard_and_rate_order.sql:3-53`](supabase/migrations/20260601184934_completion_photo_guard_and_rate_order.sql#L3-L53) |

When only one side has confirmed, the button shows *"Menunggu konfirmasi pihak lain" / "Dana ditahan sampai kedua pihak menyelesaikan pesanan."* ([`CompleteOrderButton.swift:42-49`](MbengkelIn/Views/Components/Features/Order/Completion/CompleteOrderButton.swift#L42-L49)).

```swift
func markCompleted(photoData: Data? = nil) async {
    isLoading = true; errorMessage = nil
    do {
        var photoUrl: String? = nil
        if let photoData {
            let uid = try await authService.currentUID()
            photoUrl = try await storageService.uploadOrderPhoto(uid: uid, data: photoData)
        }
        self.order = try await orderRepository.markOrderCompleted(requestId: requestId, completionPhotoUrl: photoUrl)
    } catch { self.errorMessage = error.localizedDescription }
    isLoading = false
}
```

The VM also opens a Realtime subscription on the single `service_requests` row ([`OrderCompletionViewModel.swift:82-97`](MbengkelIn/ViewModels/OrderCompletionViewModel.swift#L82-L97)) so each device sees the counterpart's flag flip live and fires a local notification.

### The RPC (server-authoritative)

[`20260601184934_completion_photo_guard_and_rate_order.sql:3-53`](supabase/migrations/20260601184934_completion_photo_guard_and_rate_order.sql#L3-L53):

```sql
is_customer := (sr.customer_id = auth.uid());
is_provider := exists (
  select 1 from public.bengkels b
  where b.id = sr.bengkel_id and b.provider_uid = auth.uid()
);
if not (is_customer or is_provider) then raise exception 'Not authorized for this order'; end if;
if sr.status <> 'On Progress' then raise exception 'Order is not in progress'; end if;

if is_customer then
  update public.service_requests set customer_completed = true where id = p_request_id;
end if;
if is_provider then
  if coalesce(p_completion_photo_url, sr.completion_photo_url) is null then
    raise exception 'Foto penyelesaian wajib dilampirkan';   -- mandatory proof-of-work
  end if;
  update public.service_requests
    set provider_completed = true,
        completion_photo_url = coalesce(p_completion_photo_url, completion_photo_url)
    where id = p_request_id;
end if;

update public.service_requests
  set status = 'Done', completed_at = now()
  where id = p_request_id and customer_completed and provider_completed;
```

Identity comes **only** from `auth.uid()`; `p_request_id` is the sole client input. Money settlement on `Done` happens in the `handle_order_balance` trigger (§8), not the RPC.

**Earnings read-back:** the bengkel's "Pendapatan Hari Ini" sums `price` of `Done` rows with `completed_at >= startOfDay` — `OrderRepository.fetchTodaysEarnings` ([`OrderRepository.swift:23-34`](MbengkelIn/Repositories/OrderRepository.swift#L23-L34)).

---

## 7. Rating

After completion, the customer rates the bengkel 1–5 with an optional review. Server-authoritative, write-once.

### Call chain

| # | Step | Location |
|---|---|---|
| 1 | `OrderReviewSheet` with tappable `InteractiveStarRating` | [`OrderReviewSheet.swift`](MbengkelIn/Views/Components/Features/Order/Completion/OrderReviewSheet.swift), [`InteractiveStarRating.swift:16-27`](MbengkelIn/Views/Components/Features/Bengkel/Dashboard/InteractiveStarRating.swift#L16-L27) |
| 2 | `OrderRatingViewModel.submit` validates `1...5`, trims review | [`OrderRatingViewModel.swift:19-40`](MbengkelIn/ViewModels/OrderRatingViewModel.swift#L19-L40) |
| 3 | `OrderRepository.submitRating` → `rate_order` RPC | [`OrderRepository.swift:91-97`](MbengkelIn/Repositories/OrderRepository.swift#L91-L97) |
| 4 | RPC writes rating; trigger recomputes bengkel average | below |

```swift
func submitRating(requestId: String, rating: Int, review: String?) async throws {
    try await supabase.rpc(
        "rate_order",
        params: RateOrderParams(p_request_id: requestId, p_rating: rating, p_review: review)
    ).execute()
}
```

### `rate_order` RPC

[`20260601184934_completion_photo_guard_and_rate_order.sql:57-87`](supabase/migrations/20260601184934_completion_photo_guard_and_rate_order.sql#L57-L87) — customer-owned, `Done`-only, write-once:

```sql
if p_rating < 1 or p_rating > 5 then raise exception 'Rating must be between 1 and 5'; end if;
update public.service_requests
  set rating = p_rating, review = p_review
  where id = p_request_id
    and customer_id = auth.uid()     -- only the owning customer
    and status = 'Done'              -- only after completion
    and rating is null               -- write-once
  returning * into sr;
if not found then raise exception 'Order cannot be rated'; end if;
```

### Average-rating trigger

Writing `rating` fires `trg_recompute_bengkel_rating`, recomputing `bengkels.average_rating` / `total_reviews` from all rated orders ([`20260528104418_add_rating_to_service_requests.sql:5-36`](supabase/migrations/20260528104418_add_rating_to_service_requests.sql#L5-L36)):

```sql
update public.bengkels b
set average_rating = coalesce(agg.avg_rating, 0),
    total_reviews = coalesce(agg.cnt, 0)
from (
  select avg(rating)::float8 as avg_rating, count(rating) as cnt
  from public.service_requests
  where bengkel_id = target_bengkel and rating is not null
) agg
where b.id = target_bengkel;
```

`StarRatingView` ([`StarRatingView.swift:10-32`](MbengkelIn/Views/Components/Features/Bengkel/Dashboard/StarRatingView.swift#L10-L32)) is the read-only fractional renderer for already-rated orders and the bengkel's displayed average.

---

## 8. Money-integrity backend

The escrow lifecycle (§2) is enforced by one trigger plus a set of `SECURITY DEFINER` RPCs.

### `accept_bid` — atomic, balance-checked

Replaces the client's racy 3-write sequence. Locks the order `for update`, checks `auth.uid()` ownership, verifies **available** balance, accepts one bid + auto-rejects the rest, moves to `On Progress` ([`20260601183346_accept_bid_rpc.sql:3-54`](supabase/migrations/20260601183346_accept_bid_rpc.sql#L3-L54)):

```sql
if sr.customer_id <> auth.uid() then raise exception 'Not authorized for this order'; end if;
if sr.status <> 'To Do' or sr.bengkel_id is not null then raise exception 'Order no longer open'; end if;
select (balance - held_balance) into v_available from public.users where id = sr.customer_id;
if v_available is null or v_available < v_bid.price then raise exception 'Saldo tidak cukup'; end if;
update public.bids set status = 'Accepted' where id = v_bid.id;
update public.bids set status = 'AutoRejected'
  where service_request_id = v_bid.service_request_id and id <> v_bid.id;
update public.service_requests
  set status = 'On Progress', bengkel_id = v_bid.bengkel_id, price = v_bid.price,
      assigned_at = now(), updated_at = now()
  where id = sr.id;
```

Repo: `OrderRepository.acceptBid` ([`OrderRepository.swift:134-143`](MbengkelIn/Repositories/OrderRepository.swift#L134-L143)).

### Completion settlement branch

In `handle_order_balance` ([`20260601163700_cancel_unwinds_holds_not_freeze.sql:57-69`](supabase/migrations/20260601163700_cancel_unwinds_holds_not_freeze.sql#L57-L69)):

```sql
-- completed: On Progress -> Done (settle both sides)
if OLD.status = 'On Progress' and NEW.status = 'Done' then
  update public.users
    set balance = balance - coalesce(NEW.price,0),
        held_balance = greatest(0, held_balance - coalesce(NEW.price,0))
    where id = NEW.customer_id;
  select provider_uid into prov from public.bengkels where id = NEW.bengkel_id;
  if prov is not null then
    update public.users
      set balance = balance + coalesce(NEW.price,0),
          pending_balance = greatest(0, pending_balance - coalesce(NEW.price,0))
      where id = prov;
  end if;
end if;
```

### `restrict_order_delete`

A customer may delete only non-active orders ([`20260601183352_restrict_order_delete.sql:3-7`](supabase/migrations/20260601183352_restrict_order_delete.sql#L3-L7)):

```sql
create policy "Customers delete own service requests."
  on public.service_requests for delete
  using (auth.uid() = customer_id and status in ('To Do','Cancelled','Done'));
```

(The trigger's `DELETE` branch still releases holds, so deleting a stray row never strands escrow.)

### Security model (the client is hostile)

**a) Direct table writes revoked** — [`20260601191847_rls_money_integrity_hardening.sql`](supabase/migrations/20260601191847_rls_money_integrity_hardening.sql):

```sql
revoke insert on public.users from authenticated, anon;
revoke update on public.users from authenticated, anon;
grant update (name, profile_image_url, bank_name, bank_account_number, bank_account_name)
  on public.users to authenticated;
```

`service_requests` direct UPDATE is revoked (status/bengkel_id/price/rating/*_completed only change via RPCs). The `bids`-can-self-accept policy is dropped. A `normalize_new_service_request` BEFORE-INSERT trigger forces every new order to a clean `To Do` state so a customer can't insert a pre-assigned/pre-completed/pre-rated row.

**b) RPC EXECUTE locked down** — [`20260601192326_lock_down_rpc_execute_grants.sql`](supabase/migrations/20260601192326_lock_down_rpc_execute_grants.sql): `increment_user_balance` + `settle_topup` revoked from public/anon/authenticated; admin helpers → `service_role`; trigger functions have EXECUTE revoked from all roles (they still fire; `SECURITY DEFINER` chains run as owner).

**c) Identity always from `auth.uid()`** — `accept_bid`, `mark_order_completed`, `rate_order`, `cancel_order`, `request_withdrawal` all resolve the actor server-side; client inputs are opaque ids only. A `reject_self_bid` trigger ([`20260601184825_reject_self_bid_trigger.sql`](supabase/migrations/20260601184825_reject_self_bid_trigger.sql)) backstops that a bengkel can never bid on its own order.

> The unit tests in [`MoneyIntegrityDTOTests.swift`](MbengkelInUnitTests/MoneyIntegrityDTOTests.swift) assert the Swift DTOs encode to the exact RPC arg names (`p_bid_id`, `p_request_id`, nil-omission). They can't exercise the SQL itself — repos use the global `supabase` client with no DI.

---

## 9. Disputes & freeze

A dispute is opened when an **On Progress** order is cancelled by either side.

### Frontend trigger

- **Customer:** `OrderTrackingViewModel.openDispute(reason:)` ([`OrderTrackingViewModel.swift:113-117`](MbengkelIn/ViewModels/OrderTrackingViewModel.swift#L113-L117)).
- **Bengkel ("Laporkan Kendala"):** `BengkelRouteViewModel.reportIssue(reason:photoData:)` ([`BengkelRouteViewModel.swift:121-137`](MbengkelIn/ViewModels/BengkelRouteViewModel.swift#L121-L137)) — supports an optional proof photo.

Both go through `OrderRepository.openDispute` → `open_dispute` RPC ([`OrderRepository.swift:69-78`](MbengkelIn/Repositories/OrderRepository.swift#L69-L78)).

### `open_dispute` RPC

[`20260601142327_dispute_completion_and_freeze_functions.sql:4-56`](supabase/migrations/20260601142327_dispute_completion_and_freeze_functions.sql#L4-L56) — authorizes parties, requires `On Progress` + non-empty reason, inserts an `order_disputes` row, flips the order to `Cancelled`:

```sql
v_role := case when is_customer then 'customer' else 'provider' end;
insert into public.order_disputes
  (service_request_id, initiated_by, initiator_role, reason, proof_url)
values (p_request_id, auth.uid(), v_role, btrim(p_reason), p_proof_url);
update public.service_requests set status = 'Cancelled', updated_at = now()
  where id = p_request_id;
```

`order_disputes` table ([`20260601142244_order_disputes_and_completion_photo.sql:8-18`](supabase/migrations/20260601142244_order_disputes_and_completion_photo.sql#L8-L18)): `service_request_id`, `initiated_by`, `initiator_role ('customer'|'provider')`, `reason`, `proof_url?`, `status ('pending'|'refunded'|'paid')`, timestamps. SELECT-only RLS for the parties; **no INSERT policy** — written exclusively via the RPC.

### ⚠️ "Freeze" was superseded — funds are now UNWOUND

There are two competing `handle_order_balance` versions in history:

- **(a) Original FREEZE** ([`20260601142327_...:183-196`](supabase/migrations/20260601142327_dispute_completion_and_freeze_functions.sql#L183-L196)): an `On Progress → Cancelled` did nothing (`null`), leaving the customer's `held_balance` and the bengkel's `pending_balance` frozen pending manual admin resolution.
- **(b) Current — freeze REMOVED** ([`20260601163700_cancel_unwinds_holds_not_freeze.sql:71-80`](supabase/migrations/20260601163700_cancel_unwinds_holds_not_freeze.sql#L71-L80), later timestamp = the one that runs): **any** cancel unwinds reservations and charges nobody:

```sql
-- cancelled (To Do OR On Progress): unwind reservations, charge nobody.
if NEW.status = 'Cancelled' and OLD.status <> 'Cancelled' then
  update public.users set held_balance = greatest(0, held_balance - coalesce(OLD.price,0)) where id = NEW.customer_id;
  if OLD.status = 'On Progress' then
    select provider_uid into prov from public.bengkels where id = OLD.bengkel_id;
    if prov is not null then
      update public.users set pending_balance = greatest(0, pending_balance - coalesce(OLD.price,0)) where id = prov;
    end if;
  end if;
end if;
```

That migration also runs a one-time correction rebuilding everyone's `held_balance`/`pending_balance` from active orders, releasing money earlier freezes had locked. The reason: the freeze locked available balance and caused false "saldo tidak cukup" errors on the customer's next order.

**Net result:** a disputed `On Progress` cancellation **no longer freezes funds** — the customer returns to their exact pre-order balance, the bengkel's pending is reversed, and the `order_disputes` row survives as an *informational* record only.

---

## 10. Behavior reports

A **post-order** informational report. After an order is `Done` or `Cancelled`, a party can report the *other* side's behavior. It moves no money and changes no order state.

### Call chain

| # | Step | Location |
|---|---|---|
| 1 | `ReportBehaviorSheet` collects free-text `reason` → `viewModel.submit(...)` | [`ReportBehaviorSheet.swift:37`](MbengkelIn/Views/Components/Features/Order/History/ReportBehaviorSheet.swift#L37) (from [`CustomerHistoryView.swift:45`](MbengkelIn/Views/Pages/History/CustomerHistoryView.swift#L45) / [`BengkelHistoryView.swift:29`](MbengkelIn/Views/Pages/History/BengkelHistoryView.swift#L29)) |
| 2 | `BehaviorReportViewModel.submit` resolves uid, delegates | [`BehaviorReportViewModel.swift:20-36`](MbengkelIn/ViewModels/BehaviorReportViewModel.swift#L20-L36) |
| 3 | `BehaviorReportRepository.submit` → insert | [`BehaviorReportRepository.swift:12-20`](MbengkelIn/Repositories/BehaviorReportRepository.swift#L12-L20) |

```swift
try await supabase.from("behavior_reports")
    .insert(BehaviorReportPayload(
        service_request_id: serviceRequestId,
        reporter_id: reporterId,
        reason: reason))
    .execute()
```

### Table & RLS

`behavior_reports` ([`20260601171021_behavior_reports.sql:4-10`](supabase/migrations/20260601171021_behavior_reports.sql#L4-L10)): `id`, `service_request_id` (FK cascade), `reporter_id` (FK cascade), `reason` (NOT NULL), `created_at`.

- **Reported fields:** only `service_request_id`, `reporter_id`, `reason`. There is **no `reported_user` column** — the reportee is implied (the other party). No category/enum, no proof, no status.
- **Who can report whom** (INSERT RLS, [`:17-33`](supabase/migrations/20260601171021_behavior_reports.sql#L17-L33)): `reporter_id = auth.uid()` AND the caller is a party to the order (its `customer_id`, or the order's bengkel's `provider_uid`).
- **SELECT:** a reporter reads back only their own reports. No admin policy in-repo.

---

## 11. Completion-photo guard

The provider must attach a proof photo to complete. Enforced in two layers.

- **Frontend (mandatory by construction):** the provider's control is a `PhotosPicker`; `markCompleted(photoData:)` is only reachable *after* a photo is picked ([`CompleteOrderButton.swift:59-75`](MbengkelIn/Views/Components/Features/Order/Completion/CompleteOrderButton.swift#L59-L75)). There is no photo-less provider path. The photo is uploaded to Storage and its URL passed to the RPC.
- **Backend backstop (the real guard):** inside `mark_order_completed` ([`20260601184934_...:31-44`](supabase/migrations/20260601184934_completion_photo_guard_and_rate_order.sql#L31-L44)) — applies only to the provider branch, accepts a photo passed now *or* already stored (`coalesce(p_completion_photo_url, sr.completion_photo_url)`), else raises `Foto penyelesaian wajib dilampirkan`. The customer side completes without a photo.

The `completion_photo_url` column was added in [`20260601142244_order_disputes_and_completion_photo.sql:2`](supabase/migrations/20260601142244_order_disputes_and_completion_photo.sql#L2). The mandatory check first appears in the `:184934` migration (an earlier version had the column but no guard).

---

## 12. Admin dispute resolution

There is **no admin UI and no admin RPC** in the repo — resolution is documented as **manual SQL** in [`docs/admin-dispute-resolution.md`](docs/admin-dispute-resolution.md). Summary:

- **Current money semantics:** because a disputed cancel now **unwinds** the reservation (§9), the customer is already made whole and `order_disputes` is an informational record. No routine resolution is needed.
- **List pending:** `select … from order_disputes d join service_requests sr … where d.status='pending'`.
- **Optional manual remedies** (if an admin wants to penalize/compensate), wrapped in `do $$ … $$` blocks that re-check the dispute is still `pending`:
  - **REFUND:** `held_balance -= price` (customer), `pending_balance -= price` (provider), `status='refunded'`.
  - **PAY the bengkel:** customer `balance -= price` & `held_balance -= price`; provider `balance += price` & `pending_balance -= price`; `status='paid'`.

---

## 13. Caveats & doc-accuracy notes

These surfaced while tracing the code and are worth knowing:

1. **`MarkCompletedParams` lives in `ChatDTOs.swift`, not `OrderDTOs.swift`** — it's defined at [`Models/DTOs/ChatDTOs.swift:10-13`](MbengkelIn/Models/DTOs/ChatDTOs.swift#L10-L13), but `CLAUDE.md`'s directory index lists it under `OrderDTOs.swift`. Minor index drift.

2. **The "freeze on dispute" behavior is dead code.** It exists only in the superseded migration [`20260601142327`](supabase/migrations/20260601142327_dispute_completion_and_freeze_functions.sql) and in stale comments (including the header of the `order_disputes` migration). The live behavior is **unwind, charge nobody** ([`20260601163700`](supabase/migrations/20260601163700_cancel_unwinds_holds_not_freeze.sql)). Don't be misled by the comments.

3. **An earlier cancel-charges-customer migration was also superseded** — [`20260601131408_cancel_accepted_order_charges_customer.sql`](supabase/migrations/20260601131408_cancel_accepted_order_charges_customer.sql) once made an `On Progress` cancel settle like a completion (charge customer, pay bengkel). The current trigger overrides it.

4. **There are duplicate migration files** with identical logical names but different timestamps (e.g. two `..._lock_down_rpc_execute_grants.sql`, two `..._rls_money_integrity_hardening.sql`). This is a symptom of the rebase/merge collisions noted in the contributor analysis — only the latest-timestamp version is authoritative.

5. **Tracking uses Apple MapKit tiles, not OSM.** The OSM overlay + Photon geocoding power the order-*creation* map only.

6. **No DI = no integration tests.** Repositories use the global `supabase` client directly, so none of these RPC call paths are unit-testable end-to-end; the tests only pin DTO encoding shapes.

---

*Generated from a code-level trace of the MbengkelIn repo. Every `file:line` reference was read directly from source; the SQL/Swift excerpts are quoted, not paraphrased.*
