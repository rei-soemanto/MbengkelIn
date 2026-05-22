# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

BengkelIn is a SwiftUI iOS app (university MAD ALP project) that connects vehicle owners with motor/car workshops ("bengkel"). It is a single Xcode project — no Swift Package Manager manifest, no CocoaPods, no fastlane. The only third-party dependency is `supabase-swift`, wired via Xcode's package manager (see `BengkelIn.xcodeproj/project.pbxproj`).

## Build / Run

Open in Xcode and run the `BengkelIn` scheme on an iOS Simulator (no test target exists yet):

```sh
open BengkelIn.xcodeproj
# or from CLI:
xcodebuild -project BengkelIn.xcodeproj -scheme BengkelIn \
  -destination 'platform=iOS Simulator,name=iPhone 15' build
```

There is no lint config, no test target, and no CI. The Supabase URL and publishable key are hard-coded at the top of `BengkelIn/BengkelInApp.swift` as a module-level `let supabase = SupabaseClient(...)` — every ViewModel imports that global directly rather than receiving a client via init.

## Architecture

MVVM with SwiftUI. Three layers under `BengkelIn/`:

- `Models/` — `Codable` structs that map 1:1 to Supabase Postgres tables: `User` (`users`), `Bengkel` (`bengkels`), `Vehicle` (`vehicles`), `BengkelService`. `PhotonSearchResponse` decodes the Photon geocoding API (OpenStreetMap) used by the order flow.
- `ViewModels/` — one `@MainActor`-isolated `ObservableObject` per domain: `AuthViewModel`, `ProfileViewModel`, `VehicleViewModel`, `BengkelViewModel`, `OrderViewModel`. Each owns its async Supabase calls (`supabase.from("…").select/insert/update/delete().execute()`) and publishes `isLoading` / `errorMessage` / `successMessage` for the views to bind to.
- `Views/` split into `Pages/` (full screens grouped by feature: `Authentication`, `Dashboard`, `Profile`, `Bengkel`, `Order`, `Temp Placeholder`) and `Components/` (`Components/Features/<Feature>/...` for feature-scoped reusable views, plus shared atoms at the root of `Components/`).

### App entry & session flow

`BengkelInApp` → `ContentView` owns the single `@StateObject AuthViewModel`. `ContentView` gates on `authViewModel.userSession`: when nil it shows `LoginView`; when present it shows a 4-tab `TabView` (Dashboard / Payment / History / Profile). Payment and History are placeholders in `Views/Pages/Temp Placeholder/`.

`AuthViewModel` also exposes `appMode: AppMode { .customer, .bengkel }`. The Dashboard switches its content based on this mode — the same logged-in user can toggle between using the app as a customer and managing their bengkel. Bengkel-side screens (`RegisterBengkelView`, `UpdateBengkelView`, `BengkelDashboardView`, `BengkelServiceFormView`, `BengkelProfileView`) all assume `appMode == .bengkel`.

### Supabase usage conventions

- Tables touched: `users`, `bengkels`, `vehicles`, plus the `avatars` Storage bucket.
- The user PK is the Supabase `auth.user.id` UUID, lowercased (`uid = sessionUser.id.uuidString.lowercased()`) — match this whenever filtering by user id.
- Sign-up writes `name` and `phone_number` into `auth.users.user_metadata`; `fetchUser()` then merges that metadata onto the row fetched from the `users` table (the `users` row is created by a Postgres trigger on signup — it is not inserted from the client).
- Account deletion re-authenticates with password before deleting the `users` row, then signs out; the auth user itself is not deleted from the client.

### Order flow (maps & geocoding)

`OrderView` + `Views/Components/Features/Order/*` implement workshop ordering with an in-app map. The map uses OpenStreetMap tiles (via `OrderMapView`) and the Photon API for place search (`LocationSearchView` → decoded by `PhotonSearchResponse`). No Apple MapKit search or Google Maps key is involved — keep new location features on the same Photon/OSM stack to avoid adding API keys.
