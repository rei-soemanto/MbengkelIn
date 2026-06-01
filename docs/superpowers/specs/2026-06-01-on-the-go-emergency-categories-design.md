# On-the-Go Emergency Categories — Design

**Date:** 2026-06-01
**Status:** Approved (pending spec review)

## Goal

Expand the customer-requestable emergency service categories beyond the current
three (Ban Gembos, Ban Pecah, Aki Kering) with additional categories that a
bengkel can realistically handle **on-the-go** — i.e. drive to the stranded
vehicle's location and fix it on the spot. No towing, no shop-only repairs.

## Category Roster (9 total)

| Category | New? | Min price (IDR) | Tire photos? | Notes |
|---|---|---|---|---|
| Ban Gembos | existing | 25.000 | yes | flat / low tire |
| Ban Pecah | existing | 40.000 | yes | burst tire |
| Aki Kering | existing | 60.000 | — | dead battery |
| Kehabisan Bensin | new | 20.000 | — | fuel delivery |
| Mogok / Mesin Mati | new | 50.000 | — | won't-start diagnosis + quick fix |
| Ganti Ban Serep | new | 30.000 | — | install customer's own spare |
| Rantai Motor Lepas | new | 25.000 | — | re-seat / replace chain (motor) |
| Mesin Overheat | new | 35.000 | — | coolant / radiator top-up |
| Ganti Lampu | new | 20.000 | — | blown headlight / bulb swap |

Deliberately excluded as "awkward": *Jumper Aki* (overlaps Aki Kering),
*Rem Blong* (needs towing), *Tambah Angin Ban* (trivial, overlaps Ban Gembos),
*Kunci Tertinggal di Dalam* (locksmith, not a mechanic task).

## Inputs

**Generic only.** No category-specific input fields are added. Every new
category uses the existing flow: vehicle picker + free-text description. Only the
two tire-damage categories (Ban Gembos, Ban Pecah) keep the existing per-tire
count selector + condition photo grid. Ganti Ban Serep installs the customer's
own spare, so it needs no condition photos.

## Architecture — Single Source of Truth

Today the service list is duplicated across four places:

1. `ServiceType` enum (`Models/BengkelService.swift`) — drives the bengkel's
   service-offer picker via `ServiceType.allCases`.
2. `OrderViewModel.services: [String]` — the customer's selectable pills.
3. `OrderViewModel.serviceMinPrices: [String: Int]` — pricing.
4. `OrderViewModel.requiresTireCount` — hardcoded `== "Ban Gembos" || == "Ban Pecah"`.

**Change:** make `ServiceType` the canonical source. Add computed properties to
the enum:

- `var minPrice: Int` — minimum / estimate base price.
- `var requiresTireCount: Bool` — true only for `.banGembos`, `.banPecah`.
- `var iconName: String` — SF Symbol per category (optional polish, see below).
- (`displayName` is already covered by `rawValue`.)

Then refactor `OrderViewModel` to derive from the enum:

- `services` → `ServiceType.allCases.map(\.rawValue)`
- `serviceMinPrices` → built from `ServiceType.allCases`
- `requiresTireCount` → look up the selected `ServiceType` and read its property

After this, **adding a future category is a one-line enum case** plus its
properties — all screens (customer pills, bengkel picker, pricing, photo gate)
update automatically. The enum ordering controls display order; existing three
stay first.

### `allCases` order

```
banGembos, banPecah, akiKering,        // existing, first
kehabisanBensin, mogokMesinMati, gantiBanSerep,
rantaiMotorLepas, mesinOverheat, gantiLampu
```

## Frontend

- **Customer order screen** (`OrderView` + `OrderViewModel`): pills render from
  the derived `services` list — new categories appear automatically. Tire
  count/photo block stays gated on `requiresTireCount`. Pricing label uses the
  derived min price.
- **Bengkel service form** (`BengkelServiceFormView`): already iterates
  `ServiceType.allCases` — new categories appear in the picker automatically.
- **Icons (optional polish):** `OrderRequestCard` and `OrderDetailView`
  currently show a single hardcoded `wrench.and.screwdriver.fill` for all
  services. If trivial, swap to `serviceType.iconName` so each category gets a
  distinct icon. Non-blocking — skip if it widens scope.

## Data / Backend

- **No DB migration.** `service_requests.service_type` is plain `text`; the
  `nearby_service_requests` RPCs cast it to `text`. New raw-value strings store
  fine and don't collide with existing data.
- **Bidding feed verification (open item):** the `bidding` edge function is not
  checked into the repo. During implementation, inspect it via the Supabase MCP
  to confirm whether the mechanic order feed filters by the bengkel's
  `offered_services`. If it filters, providers must add the new services to
  their profile before those orders appear (acceptable — the picker now offers
  them). If it shows all nearby orders, no action needed. Flag findings; do not
  change the function unless required.

## Testing

Manual verification (no test infra exists in this repo):

1. Build succeeds (`xcodebuild` / build-and-run skill).
2. Customer order screen shows all 9 pills; selecting each shows the correct
   estimated price; only Ban Gembos / Ban Pecah show the tire count + photo grid.
3. Bengkel service form lists all 9 categories in the picker.
4. Create one order for a new category (e.g. Kehabisan Bensin) end-to-end and
   confirm it appears in the mechanic feed and can be bid on.

## Out of Scope

- Category-specific input fields (fuel liters, lamp picker, symptom notes).
- Any change to bidding/pricing logic beyond the per-category base price.
- watchOS changes (the watch mirrors whatever category the order carries; no
  category-specific UI there).
