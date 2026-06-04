# MbengkelIn, Explained From 0 to 100

> A complete walkthrough of this app for an experienced software engineer who has **never written Swift**. It assumes you know general programming (variables, functions, OOP, HTTP, databases, async) but explains every Swift/SwiftUI/Supabase concept this codebase touches, then shows how the whole thing fits together end to end.
>
> Everything here is grounded in the actual source files. Where I describe general Swift/Supabase behavior (stable, well-known language/platform semantics) rather than something I read in a file, treat it as standard-knowledge; where I cite a file, it's traceable to this repo.

---

## Table of contents

1. [What the app is (the 30-second version)](#1-what-the-app-is)
2. [Part A — The Swift language from zero](#part-a--the-swift-language-from-zero)
3. [Part B — SwiftUI (the UI framework)](#part-b--swiftui-the-ui-framework)
4. [Part C — The architecture (layered MVVM)](#part-c--the-architecture-layered-mvvm)
5. [Part D — The backend (Supabase)](#part-d--the-backend-supabase)
6. [Part E — Realtime, in depth](#part-e--realtime-in-depth)
7. [Part F — End-to-end flows](#part-f--end-to-end-flows)
8. [Part G — Money integrity & security model](#part-g--money-integrity--security-model)
9. [Part H — The watchOS companion](#part-h--the-watchos-companion)
10. [Appendix — Swift symbol cheat sheet](#appendix--swift-symbol-cheat-sheet)

---

## 1. What the app is

**MbengkelIn** is an iOS app (built with SwiftUI) that connects stranded vehicle owners with nearby workshops ("bengkel" is Indonesian for workshop/garage). Think "Uber, but for roadside motor/car repair, with a reverse-auction twist."

Two kinds of human use it, but they can be the **same logged-in account** toggling modes:

- **Customer** (`role == "USER"`): "My tire blew out at this GPS pin. I'll pay up to Rp X. Who can come?"
- **Bengkel / mechanic** (`role == "PROVIDER"`): sees nearby open requests, **bids** a price, and if the customer accepts, drives out, does the job, and gets paid.

The money is held in an in-app wallet (escrow), so the app also has top-ups (via Midtrans, an Indonesian payment gateway) and withdrawals to a bank account.

The **core loop**:

```
Customer posts request  →  app holds their money in escrow (a DB trigger)
   →  nearby mechanics get a live push  →  mechanics place bids
   →  customer accepts one bid  →  order becomes "On Progress", money earmarked for that mechanic
   →  mechanic drives out (live location on a map) + in-app chat
   →  both sides tap "done"  →  order becomes "Done", money settles to the mechanic
   →  customer rates the mechanic
```

There's also an **Apple Watch app** that mirrors the customer's active order and lets them accept a bid / mark done / rate, all without typing.

The backend is **Supabase** — a hosted Postgres database plus auth, file storage, realtime, and serverless functions. The iOS app talks to it directly through an official Swift SDK. There is **no custom backend server** of your own; the "business logic that must be trusted" lives inside the Postgres database as SQL functions and triggers.

---

# Part A — The Swift language from zero

Swift is a statically-typed, compiled language (like Go/Rust/Kotlin in spirit). It's safety-oriented: a lot of bug classes (null dereferences, uninitialized memory, data races) are pushed into the type system so they become compile errors instead of runtime crashes. Here's everything this codebase uses.

### A.1 Files, imports, the compiler

A `.swift` file is just a list of declarations (types, functions, constants). There's no header/implementation split like C. At the top you see:

```swift
import Foundation
import SwiftUI
import Supabase
```

**TypeScript:**
```typescript
import { createClient } from "@supabase/supabase-js";   // named imports
import * as React from "react";                          // or whole-namespace import
```
*Difference: Swift imports a **whole module** (every public symbol becomes usable by name). TS usually imports **named symbols** in braces, so you list exactly what you pull in.*

`import` pulls in a **module** (a library). `Foundation` is Apple's standard library of basic types (dates, data, URLs). `SwiftUI` is the UI framework. `Supabase` is the third-party SDK for the backend. Unlike JS/Python, you import a whole module, not individual symbols — once imported, every public type in it is usable by name.

There's no `main()` you write by hand; the entry point is marked with `@main` (covered later).

### A.2 Comments

`// like this` and `/* ... */`. You'll also see `// MARK: Something` — that's a special comment that Xcode turns into a navigation bookmark; functionally it's just a comment.

### A.3 Constants and variables: `let` vs `var`

```swift
let supabase = SupabaseClient(...)   // constant — can never be reassigned
var email = ""                       // variable — can be reassigned later
```

**TypeScript:**
```typescript
const supabase = createClient(/* ... */); // const — binding can never be reassigned
let email = "";                            // let — can be reassigned
```
*Difference: Swift `let` on a **struct** also freezes its fields (deep). TS `const` only stops you reassigning the **binding** — an object held by `const` can still have its properties mutated.*

- `let` = immutable binding (like `const` in JS, `final` in Java). You can't point it at a different value.
- `var` = mutable binding.

Swift strongly nudges you toward `let`. (Note for value types, covered next: `let` on a struct also makes the struct's *contents* immutable — you can't mutate its fields either.)

The Models in this app use `var` for every field on purpose. From [User.swift](MbengkelIn/Models/User.swift#L10-L22):

```swift
struct User: Codable, Identifiable {
    var id: String
    var name: String
    var profileImageUrl: String?
    ...
}
```

The codebase convention (see CLAUDE.md) is: model fields are `var` so a fetched record can be locally mutated (e.g. `fetchedUser.email = sessionUser.email` in the auth flow). DTOs, by contrast, use `let` because they're write-once payloads.

### A.4 Types, type inference, and the colon `:`

Every value has a type known at compile time. You can write the type explicitly with a colon, or let the compiler infer it:

```swift
var email: String = ""     // explicit
var email = ""             // inferred as String from the literal ""
@Published var bids: [Bid] = []   // explicit: an array of Bid, starting empty
```

**TypeScript:**
```typescript
let email: string = "";    // explicit
let email2 = "";           // inferred as string
let bids: Bid[] = [];       // Swift [Bid]  ==  TS Bid[]
// Swift [String: Any]  ==  TS Record<string, unknown>
```
*Near-identical: the colon-for-type syntax and type inference work the same. Only the array/dictionary spellings differ (`[Bid]` → `Bid[]`, `[K: V]` → `Record<K, V>` or `Map<K, V>`).*

`[Bid]` means "array of `Bid`". `[String: Any]` means "dictionary from String keys to Any values". The colon means "has type". You'll also see the colon used for **protocol conformance** and **inheritance** (next sections) — same symbol, context tells them apart.

### A.5 The two kinds of types: value types vs reference types

This is **the single most important Swift concept** and the one most likely to trip up someone coming from Java/Python/JS. Swift has:

- **Value types**: `struct`, `enum`. Assigning or passing them **copies** the whole value. Two variables never secretly share the same instance.
- **Reference types**: `class`. Assigning or passing them shares a **pointer** to one heap object, like objects in Java/Python.

```swift
struct Point { var x: Int }
var a = Point(x: 1)
var b = a        // b is a COPY
b.x = 99         // a.x is still 1

class Box { var x = 1 }
let p = Box()
let q = p        // q points to the SAME object
q.x = 99         // p.x is now 99 too
```

**TypeScript:**
```typescript
// TS has NO value-type structs. Every object/array is ALWAYS a reference.
type Point = { x: number };
let a: Point = { x: 1 };
let b = a;            // b references the SAME object — NOT a copy
b.x = 99;            // a.x is now 99 too  ←  a Swift struct would still read 1
let bCopy = { ...a }; // to get Swift's struct-copy behavior you must spread/clone MANUALLY

class Box { x = 1; }
const p = new Box();
const q = p;          // same object — matches Swift's class
q.x = 99;             // p.x is now 99 too
```
*This is the **biggest** Swift↔TS gap. Swift `struct`/`enum` copy on every assignment and pass; TS has no equivalent — objects behave like Swift `class`es (shared references). Anytime you'd rely on Swift value semantics, in TS you'd hand-copy with `{...obj}` / `structuredClone` / `[...arr]`.*

Why it matters here: **Models and DTOs are `struct`s** (value types — they're just data, copying is safe and predictable), while **ViewModels and Services/Repositories are `class`es** (reference types — they have identity, are shared, and SwiftUI must observe the *same* instance over time).

A `struct` can still have mutable fields and methods; "value type" is about copy-on-assign semantics, not immutability.

### A.6 `struct`

A `struct` groups named fields (and can have methods and computed properties). Example from [BengkelService.swift](MbengkelIn/Models/BengkelService.swift#L46-L56):

```swift
struct BengkelService: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString   // default value
    var serviceType: ServiceType
    var isActive: Bool
}
```

**TypeScript:**
```typescript
interface BengkelService {            // the data shape
  id: string;
  serviceType: ServiceType;
  isActive: boolean;
}
// Swift's free memberwise init ≈ just an object literal:
const s: BengkelService = { id: crypto.randomUUID(), serviceType: "Ban Gembos", isActive: true };
```
*Swift hands you a free `init(serviceType:isActive:)` and lets fields have defaults inline. TS has no memberwise initializer — you write an object literal `{...}` (or a class with a constructor) and supply defaults yourself. Remember: that TS object is a shared reference, not a value (see A.5).*

- `id: String = UUID().uuidString` gives a **default value**: a fresh random UUID string, used if the caller doesn't supply one.
- The `: Codable, Identifiable, Hashable` part lists **protocols** this struct conforms to (explained in A.13).
- Structs get a free **memberwise initializer**: `BengkelService(serviceType: .banGembos, isActive: true)` — you don't have to write a constructor.

### A.7 `class`

A `class` is a reference type and supports inheritance. Example from [AuthService.swift](MbengkelIn/Services/AuthService.swift#L11):

```swift
class AuthService {
    func signIn(email: String, password: String) async throws -> Session {
        return try await supabase.auth.signIn(email: email, password: password)
    }
}
```

**TypeScript:**
```typescript
class AuthService {
  async signIn(email: string, password: string): Promise<Session> {
    return await supabase.auth.signIn({ email, password });
  }
}
```
*Classes map almost 1:1. Swift `async throws -> Session` ≈ TS `async ...: Promise<Session>` — but TS doesn't encode "can throw" in the type (any async function may reject). There's no `final` keyword in TS.*

Classes don't get a free memberwise init; if they have stored properties without defaults you must write `init`. You'll see ViewModels declared `class ... : ObservableObject`.

`final class` (e.g. `final class CustomerBiddingViewModel`) means "this class cannot be subclassed" — a small performance and clarity win.

### A.8 `enum` — far more powerful than in most languages

An `enum` is a type with a fixed set of cases. Swift enums can also carry **raw values** and **associated values**, and have methods/computed properties.

**Raw-value enum** from [BengkelService.swift](MbengkelIn/Models/BengkelService.swift#L10-L43):

```swift
enum ServiceType: String, Codable, CaseIterable {
    case banGembos = "Ban Gembos"
    case banPecah = "Ban Pecah"
    case akiKering = "Aki Kering"
    ...

    var minPrice: Int {            // a computed property on the enum
        switch self {
        case .banGembos: return 25000
        case .banPecah: return 40000
        ...
        }
    }

    var requiresTireCount: Bool {
        self == .banGembos || self == .banPecah
    }
}
```

**TypeScript:**
```typescript
// TS enums can't carry methods/computed props, so the idiomatic equivalent is
// a string-literal union + lookup tables / helper functions.
type ServiceType =
  | "Ban Gembos" | "Ban Pecah" | "Aki Kering"
  | "Mogok / Mesin Mati" | "Ganti Ban Serep"
  | "Rantai Motor Lepas" | "Mesin Overheat";

const MIN_PRICE: Record<ServiceType, number> = {
  "Ban Gembos": 25000, "Ban Pecah": 40000, /* ...rest... */
} as Record<ServiceType, number>;

const requiresTireCount = (t: ServiceType) => t === "Ban Gembos" || t === "Ban Pecah";

const ALL_SERVICE_TYPES: ServiceType[] = ["Ban Gembos", "Ban Pecah" /* ... */]; // ≈ CaseIterable
```
*Difference: a Swift enum is a real type with attached behavior, an exhaustive `switch` the compiler checks, and a free `rawValue`. The closest type-safe TS is a string-literal union + lookup maps. (TS's own `enum` keyword exists but can't hold methods and has runtime quirks, so unions are usually preferred.) TS `switch` is only exhaustiveness-checked if you add a `default: const _x: never = t`.*

- `: String` means each case has a backing **raw value** of type `String`. `ServiceType.banGembos.rawValue` is `"Ban Gembos"`. You can go the other way: `ServiceType(rawValue: "Ban Gembos")` returns `ServiceType?` (optional, because the string might not match any case).
- `CaseIterable` auto-generates `ServiceType.allCases` (an array of every case). The order form uses `ServiceType.allCases.map(\.rawValue)` to list services.
- `switch self` must be **exhaustive** — cover every case (or have a `default`). The compiler enforces this, so adding a new service forces you to handle its price.
- `self` inside an enum method is the current case.

**Associated-value enum** — a case can carry data. The loading-state type (referenced as `LoadingPhase` throughout the ViewModels) is this style:

```swift
enum LoadingPhase {
    case idle
    case loading(message: String)                 // carries a String
    case failed(title: String, message: String)   // carries two Strings
}
```

**TypeScript:**
```typescript
// Swift associated-value enum  ==  TS discriminated union (tagged union)
type LoadingPhase =
  | { kind: "idle" }
  | { kind: "loading"; message: string }
  | { kind: "failed"; title: string; message: string };

const phase: LoadingPhase = { kind: "loading", message: "Membuat pesanan..." };
// switch (phase.kind) { ... } — TS narrows the object's type inside each branch
```
*This is the one place TS keeps up nicely: discriminated unions are the direct analogue of Swift's associated-value enums, including the type-narrowing-per-case behavior. You just add an explicit `kind`/`tag` field that Swift generates implicitly.*

Used like `loadingPhase = .loading(message: "Membuat pesanan...")`. This is Swift's version of a tagged union / sum type. It's how the app models "either nothing, or loading-with-a-message, or failed-with-a-reason" in **one** value that can't be in an invalid combination.

A plain enum with no raw/associated values is also common, e.g. [AuthViewModel.swift](MbengkelIn/ViewModels/AuthViewModel.swift#L12-L15):

```swift
enum AppMode { case customer; case bengkel }
```

**TypeScript:**
```typescript
type AppMode = "customer" | "bengkel";
```

### A.9 Optionals — the question mark `?` (the big one)

Swift has **no implicit null**. A normal `String` can *never* be nil. If a value might be absent, its type must be an **optional**, written with a trailing `?`:

```swift
var profileImageUrl: String?   // either a String, or nil
```

**TypeScript:**
```typescript
profileImageUrl?: string;       // optional property → type is `string | undefined`
let y: string | null = null;    // or model "absent" explicitly with null
```
*Same core idea, different spelling. Swift `String?` is `Optional<String>`; TS models absence as `T | undefined` (the `?` on a property) or `T | null`. With `strictNullChecks` on, TS also refuses to let you use the value until you've checked it — same safety guarantee.*

`String?` is actually sugar for the enum `Optional<String>` with cases `.some(value)` and `.none`. This forces you to handle absence explicitly — there's no "undefined is not a function" class of bug.

Ways this codebase unwraps optionals:

**`if let`** — run a block only if non-nil, binding the unwrapped value:
```swift
if let user = change.session?.user { self.userSession = user }
```
**TypeScript:**
```typescript
const user = change.session?.user;
if (user) { this.userSession = user; }   // inside the if, TS narrows `user` to non-null
```

**`guard let`** — the inverse: bind it for the rest of the scope, else bail out early. Very common at the top of functions ([CustomerBiddingViewModel.swift](MbengkelIn/ViewModels/CustomerBiddingViewModel.swift#L302-L303)):
```swift
func loadReceivedBids() async {
    guard let serviceRequestId = serviceRequestId else { return }
    // serviceRequestId is now a non-optional String for the rest of the function
    ...
}
```
**TypeScript:**
```typescript
async loadReceivedBids(): Promise<void> {
  const id = this.serviceRequestId;
  if (!id) return;          // early-return guard — TS's idiom for `guard let`
  // `id` is now `string` (not `string | undefined`) for the rest of the function
}
```
`guard` *must* exit the scope in its `else` (here `return`), which keeps the "happy path" un-indented below. *TS has no `guard` keyword; the idiom is `if (!x) return;`, after which TS **narrows** `x` to non-null for the rest of the scope — the same payoff. (This is why `guard let a = x else { return }` is **not** the same as a `try/catch`: it unwraps an optional, it doesn't catch a thrown error.)*

**`??` nil-coalescing** — provide a fallback:
```swift
order.tireCount ?? 1          // use tireCount, or 1 if nil
bid.bengkel?.name ?? "Sebuah bengkel"
```
**TypeScript:**
```typescript
order.tireCount ?? 1;                   // identical `??` nullish-coalescing operator
bid.bengkel?.name ?? "Sebuah bengkel";  // `?.` + `??` — same syntax as Swift
```

**Optional chaining `?.`** — "call this only if the thing is non-nil; otherwise the whole expression is nil":
```swift
authViewModel.currentUser?.role     // String? — nil if currentUser is nil
change.session?.user                // nil-safe drill-down
```
**TypeScript:**
```typescript
authViewModel.currentUser?.role;   // same `?.` optional chaining → string | undefined
change.session?.user;
```
*`?.` and `??` were borrowed into TS/JS from exactly this family — these two are 1:1 with Swift.*

**Force unwrap `!`** — "I promise this isn't nil; crash if I'm wrong." Used sparingly and only where nil is genuinely impossible, e.g. [MbengkelInApp.swift](MbengkelIn/MbengkelInApp.swift#L13):
```swift
supabaseURL: URL(string: "https://nerrnpbopdfrdcfvjowx.supabase.co")!
```
**TypeScript:**
```typescript
const url = new URL("https://nerrnpbopdfrdcfvjowx.supabase.co")!; // `!` = non-null assertion
```
*Important difference: Swift's `!` performs a real runtime check and **crashes** if the value is nil. TS's `!` is **compile-time only** — it just silences the type-checker and emits nothing, so a wrong `!` yields `undefined` at runtime rather than a crash.*

The URL string is a compile-time constant known to be valid, so `!` is acceptable. In general, `!` is a code smell unless the invariant is obvious.

**`try?`** — turns a throwing call into an optional (covered in error handling): success → value, failure → nil.

### A.10 The dot `.`

The dot does several related things; context disambiguates:

1. **Member access**: `user.name`, `supabase.auth`, `result.geometry.coordinates`.
2. **Method call**: `array.map(...)`, `supabase.removeChannel(channel)`.
3. **Enum case shorthand** — when the type is known, you can omit the type name: `.banGembos` instead of `ServiceType.banGembos`, `.loading(message:)`, `.medium`. This "leading dot" is everywhere in SwiftUI (`.padding()`, `.font(.headline)`).
4. **Chained modifiers** in SwiftUI: `Text("Masuk").font(.headline).foregroundColor(...)` — each returns a new value you can dot onto again.

### A.11 Functions and methods

```swift
func login(email: String, password: String) async {
    ...
}
```

**TypeScript:**
```typescript
async login(email: string, password: string): Promise<void> { /* ... */ }
// Swift call:  login(email: "a@b.com", password: "x")   ← argument labels REQUIRED
// TS call:     login("a@b.com", "x")                    ← positional, no labels
```
*Difference: Swift requires **argument labels** at the call site (and lets the external label differ from the internal name, or be suppressed with `_`). TS arguments are positional and unlabeled; to get labelled call sites you pass a single object: `login({ email, password })`. Swift `-> T` ≈ TS `: T` return annotation; no `->` (Swift `Void`) ≈ `: void`.*

- `func name(...) -> ReturnType` — `->` is the return-type arrow. No `->` means it returns `Void` (nothing).
- **Argument labels**: callers write the parameter names at the call site: `login(email: "a@b.com", password: "x")`. This is mandatory by default and makes calls self-documenting.
- You can give an external label different from the internal name, or suppress it with `_`:
  ```swift
  func selectSearchResult(_ result: PhotonSearchFeature)  // called as selectSearchResult(x), no label
  func searchOSM(query: String, coordinate: ...)          // called with query:
  ```
- `async` marks a function as asynchronous (A.18). `throws` marks it as able to error (A.17). They stack: `async throws`.

`@discardableResult` (seen on `acceptBid`, `markOrderCompleted`) tells the compiler "the caller is allowed to ignore the return value without a warning."

### A.12 Closures (lambdas / anonymous functions)

A closure is a function value written in braces. Full form:

```swift
{ (x: Int) -> Int in return x + 1 }
```

**TypeScript:**
```typescript
(x: number): number => x + 1;   // arrow function
```

Usually shortened drastically via type inference and shorthand argument names `$0, $1`:

```swift
rows.reduce(0.0) { $0 + Double($1.price ?? 0) }   // $0 = accumulator, $1 = element
pending.map { $0.id }                              // transform each element to its id
bids.filter { $0.status.lowercased() == "pending" }
```

**TypeScript:**
```typescript
rows.reduce((acc, r) => acc + (r.price ?? 0), 0);   // note: TS reduce takes (callback, initial)
pending.map(p => p.id);
bids.filter(b => b.status.toLowerCase() === "pending");
```
*Swift's positional closure args `$0`/`$1` ≈ TS named arrow params. Watch the `reduce` argument order: Swift is `reduce(initial) { acc, el in ... }`; TS is `reduce((acc, el) => ..., initial)` — the seed comes last.*

**Trailing-closure syntax**: if the last argument is a closure, you can move it outside the parentheses. This is why so much SwiftUI looks like `Button { action } label: { ... }` — those braces are closures.

**Capture lists** `[weak self]` appear on closures inside ViewModels:

```swift
searchCountdownTask = Task { [weak self] in
    guard let self else { return }
    ...
}
```

**TypeScript:**
```typescript
// No [weak self] in TS — JS is garbage-collected, so there are no ARC retain cycles to break.
this.searchCountdownTask = (async () => {
  // an arrow function captures `this` automatically; no manual capture list
})();
```
*Difference: `[weak self]` has no TS counterpart. JS's garbage collector reclaims unreachable objects (it even handles reference cycles), so you never manually weaken a capture. Swift must, because it uses reference counting (A.21).*

`[weak self]` captures `self` (the ViewModel) **weakly** — without keeping it alive. Without it, a long-lived closure (a Task, a timer, a realtime stream) would strongly retain the ViewModel and the ViewModel retains the closure → a **retain cycle** → memory leak. `weak` makes `self` optional inside; `guard let self else { return }` re-binds it or bails if the object was already freed. This is Swift's manual side of **ARC** (Automatic Reference Counting, A.21).

### A.13 Protocols (interfaces) and conformance

A `protocol` is an interface: a set of requirements (properties/methods) a type promises to provide. A type **conforms** by listing the protocol after a colon and implementing the requirements.

```swift
struct User: Codable, Identifiable { ... }
```

**TypeScript:**
```typescript
interface Identifiable { id: string; }
interface User extends Identifiable { /* ...fields... */ }  // `: Protocol` ≈ `extends`/`implements`
```
*Difference: Swift auto-synthesizes `Codable`/`Equatable`/`Hashable` for you; TS has **none** of these. There's no compile-time JSON decode (`Codable`) — you `JSON.parse` into `any` and validate by hand or with a library like `zod`. There's no value-equality protocol — `===` on objects compares **references**, not contents. `Identifiable` is just an interface that requires an `id`.*

`User` conforms to `Codable` and `Identifiable`. The protocols this app relies on:

- **`Codable`** = `Encodable & Decodable`. "This type can be converted to/from an external format" — here, JSON. This is what lets a `User` struct be decoded straight from a Supabase row, and a DTO be encoded into a request body. The compiler **auto-synthesizes** the conversion if every field is itself Codable. (See A.16 for the snake_case mapping.)
- **`Identifiable`** requires an `id` property. SwiftUI uses it to tell list items apart efficiently (so `ForEach` knows which row is which). `User`, `Bid`, `BengkelService`, etc. all have `id`.
- **`Equatable`** requires `==`. Two values can be compared for equality. Auto-synthesized for structs/enums whose parts are all Equatable. `WatchOrderState` is `Equatable` ([WatchOrderState.swift](MbengkelIn/Models/DTOs/WatchOrderState.swift#L14)) so the watch bridge can cheaply check "did the state actually change before re-sending?"
- **`Hashable`** (implies Equatable) requires the value can produce a hash, so it can be a `Set` member or `Dictionary` key. `BengkelService` is `Hashable`. SwiftUI also uses Hashable for some navigation/identity.
- **`CaseIterable`** auto-provides `.allCases` (used by `ServiceType`).
- **`ObservableObject`** (a SwiftUI/Combine protocol) — a *class* that publishes changes so views re-render. All ViewModels conform.
- **`CLLocationManagerDelegate`**, **`WCSessionDelegate`** — Apple framework protocols for receiving callbacks (GPS updates, watch messages). `OrderViewModel` and `WatchSessionManager` conform to receive those events.

Protocols can be used as **generic constraints**, e.g. `LocationSearchView<VM: LocationSearchable>` — a view generic over "any ViewModel that supports map search." More in A.15.

### A.14 Computed properties

A property with no stored value — it runs code each time it's read. From [User.swift](MbengkelIn/Models/User.swift#L24-L26):

```swift
var availableBalance: Double {
    balance - (heldBalance ?? 0)
}
```

**TypeScript:**
```typescript
get availableBalance(): number {        // a Swift computed property == a TS `get` accessor
  return this.balance - (this.heldBalance ?? 0);
}
```

Reading `user.availableBalance` computes `balance − heldBalance` on the fly. There's no `=` and no backing storage. The ViewModels use these heavily for derived UI state, e.g. [CustomerBiddingViewModel.swift](MbengkelIn/ViewModels/CustomerBiddingViewModel.swift#L26-L29):

```swift
var searchProgress: Double {
    guard searchTotalSeconds > 0 else { return 0 }
    return Double(searchSecondsRemaining) / Double(searchTotalSeconds)
}
```

### A.15 Generics

Generics let code work over "some type to be filled in later," with optional constraints. You saw `[Bid]` — that's `Array<Bid>`, the generic `Array` specialized to `Bid`. `Optional<String>`, `Set<String>`, `Task<Void, Never>` are all generics.

User-defined example: the search overlay view is `LocationSearchView<VM: LocationSearchable>` — it works with **any** ViewModel `VM` as long as `VM` conforms to `LocationSearchable`. Both `OrderViewModel` and `BengkelViewModel` conform, so the same overlay UI is reused for "where's the customer" and "where's the workshop." `<...>` introduces a type parameter; `: LocationSearchable` constrains it.

### A.16 `CodingKeys` — mapping Swift names to JSON/DB names

Postgres columns are `snake_case` (`profile_image_url`); Swift convention is `camelCase` (`profileImageUrl`). The bridge is a nested enum named `CodingKeys` that `Codable` looks for ([User.swift](MbengkelIn/Models/User.swift#L28-L39)):

```swift
enum CodingKeys: String, CodingKey {
    case id
    case profileImageUrl = "profile_image_url"
    case heldBalance = "held_balance"
    ...
}
```

**TypeScript:**
```typescript
// TS has no CodingKeys / no auto-decode. You map snake_case ⇄ camelCase by hand
// (or with a library like zod or camelcase-keys):
function toUser(row: any): User {
  return { id: row.id, profileImageUrl: row.profile_image_url, heldBalance: row.held_balance /* ... */ };
}
```
*This whole mechanism is a Swift-`Codable` convenience with no TS twin — in TS the DB row arrives as untyped JSON and you transform/validate it yourself.*

Each case is a Swift property name; its raw `String` value is the JSON key. Cases listed without `= "..."` (like `id`, `name`) map to the identical name. **A property omitted from `CodingKeys` is not encoded/decoded at all** — that's how `availableBalance` (a computed property) and `email`/`phoneNumber` (filled from auth metadata, not the DB row) are excluded from the DB mapping even though they're declared on the struct.

DTOs skip `CodingKeys` by simply naming their fields in snake_case directly ([OrderDTOs.swift](MbengkelIn/Models/DTOs/OrderDTOs.swift#L4-L17)):

```swift
struct ServiceRequestPayload: Encodable {
    let customer_id: String
    let service_type: ServiceType
    let latitude: Double
    ...
}
```

**TypeScript:**
```typescript
interface ServiceRequestPayload {
  customer_id: string;       // snake_case fields → no mapping needed (match DB columns directly)
  service_type: ServiceType;
  latitude: number;
}
```

### A.17 Error handling: `throws`, `try`, `do`/`catch`

Swift errors are explicit and checked. A function that can fail is marked `throws`. To call it you must prefix `try`, and either be inside another `throws` function or wrap it in `do/catch`.

```swift
func login(email: String, password: String) async {
    do {
        let session = try await authService.signIn(email: email, password: password)
        self.userSession = session.user
        await fetchUser()
    } catch {
        self.errorMessage = error.localizedDescription   // `error` is implicitly available in catch
    }
}
```

**TypeScript:**
```typescript
async login(email: string, password: string): Promise<void> {
  try {
    const session = await this.authService.signIn(email, password);  // no per-call `try` keyword
    this.userSession = session.user;
    await this.fetchUser();
  } catch (error) {                          // TS requires naming the binding; its type is `unknown`
    this.errorMessage = (error as Error).message;
  }
}
```
*Differences: TS has **no** per-call `try` prefix, **no** checked `throws` in signatures (any function may throw, invisibly), and **no** `try?`/`try!`. The `catch` binding must be named (`catch (error)`). Swift's `defer { }` ≈ TS's `try { } finally { }`.*

- `try` — "this call may throw; if it does, propagate/handle it."
- `do { } catch { }` — the catch block runs on error; `error` is the thrown value, and `.localizedDescription` is a human-readable message.
- `try?` — "if it throws, give me `nil` instead." Turns failure into an optional. The codebase uses this for best-effort cleanup where a failure is acceptable: `try? await orderRepository.deleteOrder(id: id)`.
- `try!` — "crash on failure." Rare; only when failure is impossible.
- `defer { }` — schedule cleanup to run when the scope exits, no matter how. [AuthViewModel.loadInitialSession](MbengkelIn/ViewModels/AuthViewModel.swift#L52-L54) uses `defer { isInitializing = false }` so the loading flag is always cleared even if the `try` throws.

The app's convention (CLAUDE.md, confirmed in the code): **Repositories/Services `throw` and don't catch; ViewModels catch and convert errors into `errorMessage`** for the UI.

### A.18 Concurrency: `async`/`await`, `Task`, `@MainActor`, actors

Modern Swift concurrency (structured async/await, like Kotlin coroutines or JS async). Key pieces, all present here:

- **`async` function**: can suspend (pause) without blocking the thread. You call it with `await`:
  ```swift
  let session = try await authService.getCurrentSession()
  ```
  `await` marks a **suspension point** — execution may pause here and resume later; nothing after the `await` runs until the awaited work finishes.

- **`Task { ... }`**: starts a new asynchronous unit of work from synchronous code. SwiftUI buttons are synchronous, so to call an async function you wrap it:
  ```swift
  Button { Task { await authViewModel.login(email: email, password: password) } } label: { ... }
  ```
  A `Task` is also a handle you can cancel. `Task<Void, Never>` means "produces nothing (`Void`), never throws (`Never`)." The ViewModels store such handles to cancel timers/subscriptions later, e.g. `private var searchCountdownTask: Task<Void, Never>?`.

- **`for await x in stream`**: an **async loop** over an asynchronous sequence — each iteration awaits the next element. This is how realtime is consumed:
  ```swift
  for await _ in stream { await self.loadReceivedBids() }
  ```
  (The `_` means "I don't care about the element's value, just that an event arrived.")

- **`AsyncStream`**: wraps a callback-style source into an awaitable sequence. [AuthService.authStateChanges](MbengkelIn/Services/AuthService.swift#L29-L39) wraps Supabase's auth events into an `AsyncStream` the ViewModel can `for await` over.

- **Actors and `@MainActor`**: An **actor** is a reference type that serializes access to its mutable state so two tasks can't race on it. `@MainActor` is a special global actor meaning "this code runs on the **main thread**" — the only thread allowed to touch UI. **Every ViewModel is annotated `@MainActor`** so that assigning to `@Published` properties (which updates the UI) is always thread-safe:
  ```swift
  @MainActor
  class AuthViewModel: ObservableObject { ... }
  ```
  When background async work needs to update UI state, you'll see `Task { @MainActor in ... }` to hop back onto the main actor ([OrderViewModel.swift](MbengkelIn/ViewModels/OrderViewModel.swift#L154-L161)).

- **`nonisolated`**: opts a specific method *out* of the actor's isolation. `OrderViewModel` is `@MainActor`, but the CoreLocation delegate callbacks are declared `nonisolated func locationManager(...)` because the framework calls them from a background context; inside, they hop back with `Task { @MainActor in ... }`.

- **`MainActor.assumeIsolated { }`** ([MbengkelInApp.swift](MbengkelIn/MbengkelInApp.swift#L27)): "I know this is already running on the main actor, let me call main-actor code without `await`." Used in the AppDelegate launch callback.

**TypeScript (the whole section at a glance):**
```typescript
const session = await this.authService.getCurrentSession();   // await — same as Swift (no `try`)

// Task { ... }  ≈  a fire-and-forget async IIFE:
void (async () => { await authViewModel.login(email, password); })();

for await (const _ of stream) { await this.loadReceivedBids(); }  // async iteration — near-identical

// @MainActor / actor / nonisolated:  NO equivalent.
// JS is single-threaded — one main thread, no data races, nothing to isolate.
```
*This is the friendliest area for a JS dev: `async`/`await`/`for await` came from the same lineage and map almost 1:1. The thread-safety machinery (`actor`, `@MainActor`, `nonisolated`) has **no** analogue because JS concurrency is single-threaded and cooperative — everything already runs on "the main actor." Swift's `Task` is also a cancellable handle; the closest JS analogue is an `AbortController`.*

This concurrency model is *why* CLAUDE.md warns about a `deinit` that "hops executors" causing a crash — tearing down a `@MainActor` object whose cleanup schedules `await supabase.removeChannel(...)` has subtle ordering rules.

### A.19 Collections & functional operators

- **Array** `[T]`: ordered list. `.first`, `.isEmpty`, `.count`, `.append(...)`, `.prefix(n)`.
- **Set** `Set<T>`: unordered unique elements; O(1) membership. `knownBidIds: Set<String>` tracks which bids were already seen so only *new* ones trigger a notification.
- **Dictionary** `[K: V]`: key→value map. `["state": data]`, `["notifTitle": title, "notifBody": body]`.

Functional transforms (all take closures):

- `map` — transform each element: `ServiceType.allCases.map(\.rawValue)`. `\.rawValue` is a **key path** — a reference to a property, shorthand for `{ $0.rawValue }`.
- `filter` — keep elements matching a predicate: `fetched.filter { $0.status.lowercased() == "pending" }`.
- `compactMap` — map *and* drop nils: `photosData.compactMap { $0 }` turns `[Data?]` into `[Data]` (only the non-nil photos).
- `reduce` — fold to a single value: `rows.reduce(0.0) { $0 + Double($1.price ?? 0) }` sums prices.
- `first(where:)` — first element matching a predicate: `vehicles.first(where: { $0.id == vehicleId })`.
- `forEach` — run a side effect per element: `realtimeReaderTasks.forEach { $0.cancel() }`.

**TypeScript:**
```typescript
fetched.filter(b => b.status.toLowerCase() === "pending");   // filter — same
ServiceType.allCases.map(t => t);                            // map — same
photosData.filter((d): d is Data => d != null);              // compactMap ≈ filter-out-null
rows.reduce((acc, r) => acc + (r.price ?? 0), 0);            // reduce (seed is the 2nd arg)
vehicles.find(v => v.id === vehicleId);                      // first(where:) ≈ Array.find
tasks.forEach(t => t.cancel());                              // forEach — same
// Set<String> → new Set<string>()    |    [K: V] dictionary → Map<K,V> or Record<K,V>
// key path \.rawValue → arrow (x => x.rawValue)
```
*`map`/`filter`/`reduce`/`forEach` are essentially identical. `compactMap` has no single TS method — use `.filter(x => x != null)` (with a type-guard for proper narrowing), or `.flatMap`. Swift's terse key path `\.rawValue` becomes a small arrow `x => x.rawValue`.*

### A.20 Strings & interpolation

`"text"` is a `String`. **String interpolation** embeds values with `\( ... )`:

```swift
"Harga penawaran harus minimal Rp\(minPrice)"
supabase.channel("bids-updates-\(serviceRequestId)")
filter: "service_request_id=eq.\(serviceRequestId)"
```

**TypeScript:**
```typescript
`Harga penawaran harus minimal Rp${minPrice}`;        // backticks + ${ } template literals
supabase.channel(`bids-updates-${serviceRequestId}`);
`service_request_id=eq.${serviceRequestId}`;
```
*Direct 1:1 — Swift's `\( … )` inside `"..."` is TS's `${ … }` inside backticks `` `...` ``.*

`#"..."#` is a **raw string** (backslashes are literal) — used for the regex `#"\.\d+"#` in the date parser. `#" ... "#` plus regex options is how `parseISODate` strips fractional seconds.

### A.21 Memory management (ARC) in one paragraph

Swift uses **ARC** (Automatic Reference Counting): each `class` instance has a count of strong references; when it hits zero the object is freed and its `deinit` runs. There's no garbage collector. The only thing *you* manage is **breaking cycles** with `weak`/`unowned` (A.12). `deinit { }` is the destructor — ViewModels use it to cancel tasks and remove realtime channels ([CustomerBiddingViewModel.swift](MbengkelIn/ViewModels/CustomerBiddingViewModel.swift#L97-L109)).

**TypeScript:** none of this exists. JS/TS use a tracing garbage collector, so there's no reference counting, no `deinit`, and no `weak`/`unowned` — the GC reclaims unreachable objects (including reference cycles) on its own. (The rough equivalent of `deinit` cleanup is doing it explicitly, e.g. an `AbortController.abort()` or a React `useEffect` cleanup return.)

### A.22 Access control & other modifiers

- `private` — visible only within the enclosing type/file. Dependencies are `private let authService = AuthService()`.
- (no modifier) — `internal`, the default: visible within the module.
- `static` — belongs to the type, not an instance: `static let shared = WatchSessionManager()` (a singleton), `OrderViewModel.defaultCenter`, `WatchOrderState.empty`.
- `self` — the current instance (like `this`). `Self` (capital) — the current *type* (used in `Self.parseISODate(...)` to call a static method).
- `convenience init` — a secondary initializer that must call another initializer. `CustomerBiddingViewModel` has a `convenience init(resuming order:)` that re-enters an in-progress order.
- `lazy` / property wrappers (`@Published`, `@State`, etc.) — covered in Part B because they're SwiftUI-flavored.

**TypeScript:**
```typescript
private authService = new AuthService();      // `private` — same keyword
static shared = new WatchSessionManager();    // `static` — same keyword
// self → this   |   Self (the type itself) → typeof ClassName (or just the class value)
// convenience init → a static factory method, or constructor overloads
```
*`private`/`static` are the same. `internal` (Swift's default) ≈ TS's default module visibility. Swift's `Self` (capital) refers to the type; in TS you'd write `typeof ClassName` or pass the class itself.*

That's the language. Now the UI framework that this app is built in.

---

# Part B — SwiftUI (the UI framework)

SwiftUI is **declarative**: you describe what the UI *should look like for the current state*, and the framework figures out the minimal changes to the screen when state changes. You never imperatively say "set this label's text." Instead: state changes → SwiftUI re-runs your view-describing code → it diffs and updates the screen. (Conceptually identical to React's render model.)

### B.1 A view is a `struct` conforming to `View`

```swift
struct LoginView: View {
    var body: some View {
        ...
    }
}
```

- A view is a lightweight **value type** (struct) — cheap to create and throw away. SwiftUI creates and destroys these constantly; that's fine because they're just descriptions, not the actual on-screen pixels.
- The single requirement of `View` is a computed property **`body`** that returns the view's content.
- **`some View`** is an **opaque return type**: "I return *one specific* concrete View type, but I won't spell out the (often enormous, compiler-generated) name." It lets you return complex nested view trees without writing their types.

### B.2 The view tree & composition

Views nest to form a tree. You build UI by composing small views inside container views. From [LoginView.swift](MbengkelIn/Views/Pages/Authentication/LoginView.swift):

```swift
NavigationStack {            // gives navigation (push/pop) capability
  ZStack {                   // layers children back-to-front
    Color(.systemBackground).ignoresSafeArea()   // background fill
    VStack(spacing: 24) {    // vertical stack of children, 24pt apart
      Text("MbengkelIn").font(.largeTitle).fontWeight(.bold)
      CustomInputField(iconName: "envelope", placeholder: "Email", text: $email)
      Button { ... } label: { Text("Masuk") ... }
      ...
    }
    .padding(.horizontal, 24)
  }
}
```

- **Stacks**: `VStack` (vertical), `HStack` (horizontal), `ZStack` (depth/overlay). They take a trailing closure listing child views.
- **`Spacer()`** pushes siblings apart (absorbs free space).
- **`Text`, `Image`, `Button`, `Picker`, `TextField`** are leaf views. `Image(systemName: "wrench.and.screwdriver.fill")` uses **SF Symbols**, Apple's built-in icon set (every `systemImage:` / `systemName:` string is an icon name).

### B.3 Modifiers

A **modifier** is a method on a view that returns a *new, wrapped* view with some change applied. They chain:

```swift
Text("Masuk")
    .font(.headline)
    .foregroundColor(Color(.systemBackground))
    .frame(maxWidth: .infinity)
    .frame(height: 55)
    .background(Color.primary.opacity(0.9))
    .cornerRadius(12)
```

Order matters (e.g. padding-then-background ≠ background-then-padding). Common ones here: `.padding`, `.frame`, `.background`, `.cornerRadius`, `.foregroundColor/.foregroundStyle`, `.font`, `.shadow`, `.disabled(...)`, `.tint(...)`.

### B.4 State management — the heart of SwiftUI (and of this app)

SwiftUI needs to know *which* state, when changed, should re-render *which* views. It does this with **property wrappers** (the `@Something` annotations). Each one is a different kind of "this value is special; watch it." Here are all the ones this app uses:

**`@State`** — local, view-owned, simple value state. From [LoginView.swift](MbengkelIn/Views/Pages/Authentication/LoginView.swift#L12-L13):
```swift
@State private var email = ""
@State private var password = ""
```
The view owns this; mutating it re-renders the view. Use for small, private, value-type UI state (text field contents, toggles, "is this sheet showing"). `@State private var bidOrder: NearbyOrder?` in ContentView is an optional that, when set, presents a sheet.

**`@Binding`** — a *reference* to state owned by someone else. A child view that needs to read **and write** a parent's state takes a `@Binding`. You pass one with the `$` prefix:
```swift
CustomInputField(... text: $email)   // $email is a Binding<String> to LoginView's email
```
Inside `CustomInputField`, `text` is declared `@Binding var text: String`; typing into it writes back up to `LoginView.email`. The `$` is the **projected value** of a property wrapper — for `@State`/`@Published` it's the `Binding`.

**`ObservableObject` + `@Published`** — for reference-type (class) state shared across views, i.e. ViewModels:
```swift
@MainActor
class AuthViewModel: ObservableObject {
    @Published var userSession: Supabase.User?
    @Published var currentUser: User?
    @Published var isLoading = false
    ...
}
```
`@Published` means "when this property changes, emit a change notification." Any view observing this object re-renders. This is the bridge between your business logic (ViewModel) and the UI.

**`@StateObject`** — a view **creates and owns** an ObservableObject (its lifetime is tied to the view; it's created once and survives re-renders):
```swift
@StateObject private var authViewModel = AuthViewModel()     // ContentView owns the single AuthViewModel
@StateObject private var viewModel = FeatureViewModel()
```

**`@ObservedObject`** — a view **receives** an ObservableObject from a parent (doesn't own its lifetime):
```swift
struct LoginView: View {
    @ObservedObject var authViewModel: AuthViewModel   // passed in from ContentView
}
```
The app-wide rule (CLAUDE.md): `AuthViewModel` is created **once** with `@StateObject` in `ContentView` and passed down as `@ObservedObject` everywhere else; feature ViewModels are usually `@StateObject` in the screen that owns them.

**`@EnvironmentObject` / `@Environment`** — read something from the environment (a shared context). This app uses `@Environment(\.scenePhase) private var scenePhase` to observe whether the app is active/background ([ContentView.swift](MbengkelIn/ContentView.swift#L16)). `\.scenePhase` is a **key path** into the environment.

**Why two wrappers for the same object (`@StateObject` vs `@ObservedObject`)?** Ownership/lifetime. `@StateObject` guarantees the object is created once and not destroyed on each re-render; `@ObservedObject` just watches an object whose life is managed elsewhere. Using `@ObservedObject` where you should use `@StateObject` is a classic SwiftUI bug (the object gets recreated and loses state).

### B.5 Reacting to data: `if let`, `ForEach`, conditionals in the view

Because `body` is just code that returns views, you use normal Swift control flow to vary the UI:

```swift
if let errorMessage = authViewModel.errorMessage {
    Text(errorMessage).foregroundColor(.red)
}
```
The `Text` only appears when `errorMessage` is non-nil. [ContentView.swift](MbengkelIn/ContentView.swift#L22-L47) is one big conditional that **is the session gate**:

```swift
Group {
    if !network.isConnected { OfflineView { ... } }
    else if authViewModel.isInitializing { SplashView() }
    else if authViewModel.userSession != nil { /* the 4-tab app */ }
    else { LoginView(authViewModel: authViewModel) }
}
```

`ForEach` renders one view per element of a collection (this is where `Identifiable` matters — SwiftUI uses `id` to track rows across updates).

### B.6 Navigation & presentation

- **`TabView`** — the bottom tab bar. Each child gets a `.tabItem { Label(...) }`. [ContentView.mainTabView](MbengkelIn/ContentView.swift#L69-L102) builds the 4 tabs (Dashboard / Payment / History / Profile), and the labels/icons change based on `isBengkelMode`.
- **`NavigationStack`** + **`NavigationLink`** — push/pop navigation. `NavigationLink(destination: RegistrationView(...)) { ... }` pushes the registration screen when tapped.
- **`.sheet(item:)` / `.fullScreenCover(item:)`** — present a modal driven by an optional. When the bound optional becomes non-nil, the modal appears with that item; setting it back to nil dismisses. ContentView uses `.sheet(item: $bidOrder)` and `.fullScreenCover(item: $bengkelBiddingViewModel.activeBengkelOrder)`. The `item:` is `Identifiable` so SwiftUI knows what's being presented.
- **`.alert(...)`** — native pop-up dialogs. ContentView wires several to ViewModel optionals (e.g. `lostBidAlert`, `expiredBidAlert`) via a custom `Binding(get:set:)` that maps "non-nil ⇒ show."
- **`.presentationDetents([.medium])`** — how tall a sheet is.

### B.7 View lifecycle hooks

- **`.onAppear { }` / `.onDisappear { }`** — run when a view enters/leaves the screen. The convention: tear down realtime channels in `.onDisappear`.
- **`.task { }`** — run an async job tied to the view's lifetime (auto-cancelled when the view disappears). **`.task(id:)`** re-runs whenever the `id` changes. ContentView uses `.task(id: authViewModel.userSession?.id)` to start/stop the watch observer whenever the logged-in user changes ([ContentView.swift](MbengkelIn/ContentView.swift#L60-L66)), and `.task(id: authViewModel.currentUser?.role)` to start the mechanic's bidding subscription only for PROVIDERs.
- **`.onChange(of:)`** — run a closure when a value changes. Used for `scenePhase` (refresh on returning to foreground) and `network.isConnected` (reload session when connectivity returns).

### B.8 Bridging UIKit: `UIViewRepresentable`

SwiftUI is newer than Apple's older UIKit framework. When SwiftUI lacks something (here: an OpenStreetMap map), you wrap a UIKit view in a struct conforming to `UIViewRepresentable`. `OrderMapView` wraps UIKit's `MKMapView` with an OSM tile overlay so it can be used like any SwiftUI view. (You implement `makeUIView` to build it and `updateUIView` to sync it with SwiftUI state.) This is the standard escape hatch.

### B.9 App entry point

[MbengkelInApp.swift](MbengkelIn/MbengkelInApp.swift):

```swift
@main
struct MbengkelInApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
```

- **`@main`** marks the program's entry point (replaces a hand-written `main()`).
- **`App`** protocol — the app itself is a value type with a `body` of type `some Scene`.
- **`WindowGroup`** — the top-level window container; on iOS it's the app's single window. It hosts `ContentView()`, the root view.
- **`@UIApplicationDelegateAdaptor(AppDelegate.self)`** — bridges in a classic UIKit **AppDelegate** so the app can hook low-level lifecycle events. This app's `AppDelegate` sets up push-notification presentation and activates the watch connection at launch ([MbengkelInApp.swift](MbengkelIn/MbengkelInApp.swift#L24-L38)).

You now have the language and the UI framework. Next: how the code is *organized*.

---

# Part C — The architecture (layered MVVM)

The app is **layered MVVM** (Model–View–ViewModel with extra layers below the ViewModel). The point of the layering is a strict **dependency direction** and **single responsibility** per layer, so that, e.g., all database access is in one kind of place and never leaks into the UI.

```
View  →  ViewModel  →  Repository  →  Supabase DB (tables)
                    →  Service     →  External APIs / SDKs (Auth, Storage, Photon, Midtrans)
   Models & DTOs flow through all layers as the data being passed around.
```

### C.1 The layers, top to bottom

| Layer | Folder | What it is | Example in this repo |
|---|---|---|---|
| **View** | `Views/` | SwiftUI screens & components. Only talks to ViewModels. | [LoginView.swift](MbengkelIn/Views/Pages/Authentication/LoginView.swift) |
| **ViewModel** | `ViewModels/` | `@MainActor` `ObservableObject`. Holds `@Published` UI state, orchestrates Repositories + Services, catches errors. **Never touches the DB directly.** | [AuthViewModel.swift](MbengkelIn/ViewModels/AuthViewModel.swift), [OrderViewModel.swift](MbengkelIn/ViewModels/OrderViewModel.swift) |
| **Repository** | `Repositories/` | Stateless. One per DB table. Does `supabase.from("table")...` CRUD and RPC calls. `async throws`, no error handling. | [OrderRepository.swift](MbengkelIn/Repositories/OrderRepository.swift) |
| **Service** | `Services/` | Stateless. Wraps non-table SDK/API work: Auth SDK, Storage, Photon geocoding, notifications, the watch bridge, Midtrans. | [AuthService.swift](MbengkelIn/Services/AuthService.swift) |
| **DTO** | `Models/DTOs/` | `Encodable`/`Decodable` payloads for insert/update/RPC params and ad-hoc responses. snake_case fields. | [OrderDTOs.swift](MbengkelIn/Models/DTOs/OrderDTOs.swift) |
| **Model** | `Models/` | `Codable + Identifiable` domain structs mapping DB rows. Pure data + `CodingKeys`. | [User.swift](MbengkelIn/Models/User.swift) |
| **Protocol** | `Protocols/` | Shared behavior contracts. | `LocationSearchable` |

### C.2 The rules (and why)

These are the load-bearing invariants (from CLAUDE.md, confirmed against the code):

1. **ViewModels never call `supabase` for table CRUD.** They go through a Repository. *Why:* keeps DB shape and queries in one swappable place; makes ViewModel logic the only thing with branching/business rules.
2. **No inline `Encodable` structs in ViewModels** — every payload is a named DTO. *Why:* the wire format is explicit and reusable, not buried in a method.
3. **Models are pure data.** No business logic beyond trivial computed conveniences like `availableBalance`.
4. **Repositories & Services are stateless** — parameters in, value out or throw. No `@Published`.
5. **ViewModels are `@MainActor` `ObservableObject`s.**

Trace one operation to see it: customer accepts a bid →
`CustomerBiddingViewModel.acceptBid(_:)` (ViewModel, catches errors) → `OrderRepository.acceptBid(bidId:)` (Repository) → `supabase.rpc("accept_bid", params: AcceptBidParams(...))` (DTO `AcceptBidParams` carries the param) → the Postgres function runs the whole transaction. The ViewModel never wrote SQL or touched `supabase.from(...)`.

### C.3 The one sanctioned exception

Realtime channels and edge-function calls (`supabase.channel(...)`, `supabase.functions.invoke(...)`) are set up **inside ViewModels** (and the app-level `WatchSessionManager`). This is the *only* place a ViewModel references `supabase` directly. You can see it in [CustomerBiddingViewModel.startRealtimeSubscription](MbengkelIn/ViewModels/CustomerBiddingViewModel.swift#L263-L289). All ordinary table CRUD still goes through a Repository. CLAUDE.md also notes the bidding ViewModels still have some inline `supabase.from("bids")` calls that haven't been extracted into a `BidRepository` yet — a known, documented debt.

### C.4 The global client

There is no dependency injection of the backend client. A single module-level constant is created once and imported everywhere ([MbengkelInApp.swift](MbengkelIn/MbengkelInApp.swift#L12-L20)):

```swift
let supabase = SupabaseClient(
  supabaseURL: URL(string: "https://nerrnpbopdfrdcfvjowx.supabase.co")!,
  supabaseKey: "sb_publishable_...",
  options: ...
)
```

Every Repository and Service references this global `supabase` directly. The trade-off (noted in CLAUDE.md): because there's no injected/mockable client, **network code isn't unit-testable** — so the test suite only covers pure logic (pricing, mapping, ViewModel decisions), not DB calls.

---

# Part D — The backend (Supabase)

### D.1 What Supabase is

**Supabase** is an open-source "Firebase alternative" built around a real **PostgreSQL** database. You get, as managed services, all talking to that one Postgres instance:

- **Database** — Postgres (real SQL, real tables, foreign keys, triggers).
- **Auth** — email/password (and more) user accounts, JWT sessions.
- **PostgREST** — an auto-generated REST API over your tables (this is what `supabase.from("table").select()...` hits under the hood).
- **Realtime** — a websocket server that streams row changes to subscribed clients.
- **Storage** — S3-like file buckets.
- **Edge Functions** — Deno (TypeScript) serverless functions for logic that can't live in the DB or shouldn't run on the client (e.g. talking to Midtrans).

The crucial mental model: **the iOS app talks to Postgres almost directly.** There's no Express/Django server you wrote in between. So "the backend code" is mostly **SQL** — tables, **RLS policies**, **RPC functions**, and **triggers** — versioned in this repo under [supabase/migrations/](supabase/migrations/). (The `bidding` edge function is deployed but not checked in; `payment` and `midtrans-webhook` are checked in under `supabase/functions/`.)

### D.2 The publishable key and why direct DB access is safe

The app ships a `sb_publishable_...` key — a **public** key, safe to embed. It does *not* grant blanket DB access. Safety comes from **Row-Level Security (RLS)**: every table has policies that, per logged-in user, decide which rows they may `SELECT`/`INSERT`/`UPDATE`/`DELETE`. Postgres enforces these on every query. So even though the client can *attempt* any query, it only ever sees/modifies rows the policies allow.

### D.3 Authentication

Handled by Supabase Auth, wrapped in [AuthService.swift](MbengkelIn/Services/AuthService.swift) and orchestrated by [AuthViewModel.swift](MbengkelIn/ViewModels/AuthViewModel.swift):

- **Sign up**: `supabase.auth.signUp(email:password:data:)`. The `data:` dictionary writes `name` and `phone_number` into the auth user's **metadata**. A **Postgres trigger on signup** then creates the matching row in the `users` table (the client does *not* insert it). After signup the app signs the user out and tells them to confirm their email.
- **Sign in**: `supabase.auth.signIn(email:password:)` returns a `Session` (contains the user + JWT tokens). The JWT is what RLS reads as `auth.uid()`.
- **Session persistence**: the SDK caches the session locally. On launch, `loadInitialSession()` tries a fresh session; if the network is down it falls back to `authService.cachedSession()` so a logged-in user isn't bounced to the login screen by a transient outage ([AuthViewModel.swift](MbengkelIn/ViewModels/AuthViewModel.swift#L52-L67)).
- **Auth state stream**: `authStateChanges()` exposes sign-in/out/token-refresh events as an `AsyncStream`; `AuthViewModel.init` loops over it to keep `userSession` in sync ([AuthViewModel.swift](MbengkelIn/ViewModels/AuthViewModel.swift#L34-L47)).
- **The user-ID convention**: the PK is the auth user's UUID, **lowercased**: `session.user.id.uuidString.lowercased()`. Always lowercased when filtering (`AuthService.currentUID()`).
- **fetchUser merge**: the DB `users` row doesn't store email/phone; `fetchUser()` fetches the row, then overlays `email` and `phone_number` from the auth session/metadata onto the in-memory `User` struct ([AuthViewModel.swift](MbengkelIn/ViewModels/AuthViewModel.swift#L106-L130)).
- **Account deletion**: re-authenticates with the password first, deletes the `users` row, then signs out (the auth user itself isn't deleted client-side).

### D.4 Tables (the data model)

The main tables (full schema in CLAUDE.md), each with a Repository:

- **`users`** — profile + wallet: `balance`, `held_balance` (escrow held for active orders), `pending_balance` (provider earnings awaiting settlement), `role` ("USER"/"PROVIDER"), bank details. `availableBalance = balance − held_balance`.
- **`vehicles`** — a customer's vehicles.
- **`bengkels`** — workshops: location, `status` (Pending/Verified/Rejected), `offered_services` (JSONB array of `BengkelService`), `average_rating`, `total_reviews`.
- **`service_requests`** — the central "order" table: `service_type` (a Postgres enum), location, `price`, `status` ("To Do" → "On Progress" → "Done"/"Cancelled"), `bengkel_id` (set on accept), `tire_count`, `photo_urls` (JSONB), `vehicle_id`/`vehicle_info`, `rating`/`review`, `customer_completed`/`provider_completed` (dual-confirm), `completed_at`.
- **`bids`** — a mechanic's offer on a request: `price`, `notes`, `status` ("Pending"/"Accepted"/"Rejected"/"AutoRejected"/"Expired").
- **`chat_messages`**, **`order_locations`** (live mechanic GPS), **`topups`**, **`withdrawals`**.

### D.5 How a Repository call maps to SQL

[OrderRepository.fetchOrders](MbengkelIn/Repositories/OrderRepository.swift#L14-L21):

```swift
return try await supabase.from("service_requests")
    .select()
    .eq("customer_id", value: customerId)
    .order("created_at", ascending: false)
    .execute()
    .value
```

This builds and sends `GET .../service_requests?customer_id=eq.<id>&order=created_at.desc` to PostgREST. `.execute()` performs it; `.value` decodes the JSON rows straight into `[NearbyOrder]` (works because `NearbyOrder` is `Decodable`). RLS still filters server-side. Embedded joins use PostgREST syntax: `.select("*, bengkel:bengkels(*)")` fetches each bid **with** its related bengkel row nested in.

### D.6 RPCs — trusted server-side functions

For anything that **moves money** or must be **atomic/trusted**, the app does NOT do multi-step writes from the client. It calls a Postgres function via `supabase.rpc("fn_name", params: SomeDTO)`. These functions are declared `security definer` (they run with the function owner's privileges, bypassing the caller's RLS) but re-check authorization using `auth.uid()` internally.

Example — [accept_bid](supabase/migrations/20260601183346_accept_bid_rpc.sql):

```sql
create or replace function public.accept_bid(p_bid_id uuid)
returns public.service_requests
language plpgsql
security definer
as $function$
...
  -- lock the order row for the transaction
  select * into sr from public.service_requests where id = v_bid.service_request_id for update;
  if sr.customer_id <> auth.uid() then raise exception 'Not authorized'; end if;
  if sr.status <> 'To Do' or sr.bengkel_id is not null then raise exception 'Order no longer open'; end if;
  -- balance check
  select (balance - held_balance) into v_available from public.users where id = sr.customer_id;
  if v_available < v_bid.price then raise exception 'Saldo tidak cukup'; end if;
  -- atomic state change
  update public.bids set status = 'Accepted' where id = v_bid.id;
  update public.bids set status = 'AutoRejected' where service_request_id = v_bid.service_request_id and id <> v_bid.id;
  update public.service_requests set status = 'On Progress', bengkel_id = v_bid.bengkel_id, price = v_bid.price ...;
$function$;
grant execute on function public.accept_bid(uuid) to authenticated;
```

In one transaction it: verifies the caller owns the order, checks the order is still open, checks the customer can afford it, marks the chosen bid Accepted and all others AutoRejected, and flips the order to On Progress. The client can't bypass any of this because it never does the individual writes — it just calls the function. The accompanying migration `lock_down_rpc_execute_grants` revokes broad execute and grants only to `authenticated`.

Other RPCs: `mark_order_completed`, `rate_order`, `cancel_order`, `open_dispute`, `request_withdrawal`, `increment_user_balance`, the `nearby_*` distance functions.

### D.7 Triggers — automatic reactions to row changes

A **trigger** is a function Postgres runs automatically when rows change. The money escrow is implemented entirely as one trigger on `service_requests` — [handle_order_balance](supabase/migrations/20260528141836_order_balance_holds.sql):

- **INSERT** a `To Do` request with a price → add `price` to the customer's `held_balance` (money is now escrowed; `availableBalance` drops).
- **To Do → On Progress** (a bid accepted) → add `price` to the chosen provider's `pending_balance`.
- **On Progress → Done** → subtract from customer `balance` + `held_balance`; add to provider `balance`; subtract provider `pending_balance` (settlement).
- **→ Cancelled** → release the customer's hold (and the provider's pending, if it was in progress).
- **Price changed while still To Do** → adjust the hold by the delta.

`greatest(0, ...)` clamps balances so they never go negative. This means the wallet is **always consistent** regardless of which client did what — the DB is the single source of truth for money. The Swift side only *reads* balances; it never computes settlements.

### D.8 Storage buckets

Supabase Storage = file buckets with their own access policies. Three buckets, wrapped by `StorageService`:

- **`avatars`** — profile pictures at `{uid}/profile.jpg`.
- **`order-photos`** — e.g. flat-tire photos at `{uid}/{uuid}.jpg`; deleted when an order is cancelled.
- **`chat-images`** — images in order chat at `{serviceRequestId}/{uuid}.jpg`.

Flow you can see in [OrderViewModel.createOrder](MbengkelIn/ViewModels/OrderViewModel.swift#L275-L301): each tire photo's raw `Data` is uploaded via `storageService.uploadOrderPhoto(uid:data:)`, which returns a URL string; those URLs are stored in the order's `photo_urls` JSONB column. (`ImageCompressor` shrinks images before upload.)

### D.9 Edge functions

Deno/TypeScript serverless functions for logic that must run off-device or hit secrets:

- **`bidding`** — the mechanic order feed (`ordersForMechanic`) and bid placement (`placeBid`), invoked via `supabase.functions.invoke`. (Deployed remotely; not checked in.)
- **`payment`** — creates a Midtrans Snap top-up transaction and returns a payment URL (`PaymentService.createTopup`).
- **`midtrans-webhook`** — receives Midtrans settlement callbacks, verifies the signature, and credits the wallet via `increment_user_balance`. This is the trusted server-to-server path that actually adds money.

### D.10 Migrations

Every backend change is a timestamped SQL file in [supabase/migrations/](supabase/migrations/). The history reads like the app's backend changelog: schema for bidding, balance holds, chat + dual completion, live locations, dispute/freeze functions, RLS money-integrity hardening, locking down RPC grants, adding/removing `service_type` enum values, etc. Note an important detail (CLAUDE.md): `service_type` is a **Postgres enum**, so adding a service requires an `alter type ... add value` migration, not just a new Swift `ServiceType` case — the Swift enum and the DB enum must be kept in sync.

---

# Part E — Realtime, in depth

This app is **live** — bids appear, statuses flip, and locations move on screen without the user refreshing. That's Supabase Realtime, and the codebase has firm rules about it (CLAUDE.md): **never poll** (no timers that re-fetch on an interval as a substitute for live updates).

### E.1 The mechanism

Supabase Realtime is a websocket server that broadcasts Postgres row changes (`INSERT`/`UPDATE`/`DELETE`). The Swift SDK exposes it as a **channel** you subscribe to, yielding an **async stream** of change events. The canonical pattern, from [CustomerBiddingViewModel.startRealtimeSubscription](MbengkelIn/ViewModels/CustomerBiddingViewModel.swift#L263-L289):

```swift
let channel = supabase.channel("bids-updates-\(serviceRequestId)")
let stream = channel.postgresChange(
    AnyAction.self, schema: "public", table: "bids",
    filter: "service_request_id=eq.\(serviceRequestId)"
)
Task { [weak self] in
    await channel.subscribe()
    await self?.loadReceivedBids()          // cold-start reconcile after subscribe
    for await _ in stream {                 // every change event...
        await self?.loadReceivedBids()      // ...re-fetch the authoritative list
    }
}
```

Note the pattern: realtime is used as a **trigger to re-fetch**, not as the data itself. When *any* bid for this order changes, the stream yields; the ViewModel responds by re-querying the canonical list via the repository/`supabase.from`. This avoids trying to reconstruct local state from individual deltas (simpler and less error-prone). The `await channel.subscribe()` then an immediate `loadReceivedBids()` handles the race where a bid lands during the subscribe handshake.

### E.2 The two prerequisites for an event to actually arrive

Realtime is easy to misconfigure. For a client to receive a change, **both** must hold (CLAUDE.md):

1. **Publication** — the table must be added to the `supabase_realtime` publication (`alter publication supabase_realtime add table public.<table>;`). Published tables include `service_requests`, `bids`, `chat_messages`, `order_locations`, `topups`, `withdrawals`, `bengkels`.
2. **RLS** — Realtime enforces RLS *per subscriber*. A user only receives change events for rows they're allowed to `SELECT`. This is why a mechanic can receive *other customers'* new orders: a dedicated policy grants it. [open_orders_select_policy](supabase/migrations/20260528052010_open_orders_select_policy.sql):

```sql
create policy "Authenticated can view open service requests."
    on public.service_requests
    for select to authenticated
    using (status = 'To Do' and bengkel_id is null);
```

So any authenticated mechanic can `SELECT` (and therefore receive realtime events for) **open, unassigned** requests — which is exactly how new jobs pop up instantly without polling the edge function. Once a request is assigned (`bengkel_id` set) it stops matching this policy, so losing mechanics stop seeing it.

Additionally, filtered `UPDATE`/`DELETE` events need `replica identity full` on the table (so the changed row's columns are present for the subscription filter) — there are migrations doing exactly that for `order_locations`.

### E.3 "But I see `Task.sleep` in the bidding ViewModel — isn't that polling?"

No, and the distinction matters. The `Task.sleep` calls in [CustomerBiddingViewModel](MbengkelIn/ViewModels/CustomerBiddingViewModel.swift#L174-L205) are **countdown timers for business rules**, not data refreshers:

- a 120-second **search window** (if no bids arrive, prompt to retry/raise price),
- a per-offer 120-second **decision window** (auto-expire offers the customer ignored),
- a 10-second decision prompt before auto-cancelling.

These implement *time-based order logic*, and they update a visible countdown. Data still arrives via the realtime stream. The "no polling" rule forbids `sleep`-loops used to *fetch data on an interval*; it doesn't forbid timers that enforce deadlines.

### E.4 Teardown

Channels must be removed when no longer needed (`supabase.removeChannel(channel)`), in `.onDisappear` or the ViewModel's `deinit`, and the reader `Task`s cancelled. You can see the careful teardown in `stopRealtimeSubscription()` and `deinit`. Forgetting this leaks websocket subscriptions and the ViewModel.

---

# Part F — End-to-end flows

Now the whole thing in motion. Each flow names the real types involved.

### F.1 App launch & the session gate

1. `@main MbengkelInApp` creates the window with `ContentView()`. `AppDelegate.didFinishLaunching` activates the watch session.
2. `ContentView` owns the single `@StateObject AuthViewModel`. Its `init` kicks off `loadInitialSession()` and starts the auth-state stream loop.
3. `ContentView.body` is the gate (in priority order): **offline?** → `OfflineView`; **still initializing?** → `SplashView`; **have a session?** → the 4-tab app; **else** → `LoginView`.
4. If logged in and `role == "PROVIDER"`, a segmented `Picker` ("Pelanggan" / "Bengkel") appears above the tabs, bound to `authViewModel.appMode`; tab labels/icons and the Dashboard's content switch on it. The same account is both customer and workshop.
5. `.task(id: userSession?.id)` starts/stops `WatchSessionManager` for the current user. `.task(id: currentUser?.role)` starts the mechanic's global bidding subscription only for providers (so they get incoming-job modals app-wide).

### F.2 Sign up / log in

- **Login**: `LoginView` has `@State email/password`, bound into `CustomInputField`s. Tapping "Masuk" runs `Task { await authViewModel.login(...) }`. The ViewModel calls `AuthService.signIn`, stores `userSession`, and `fetchUser()`s the profile. On error, `errorMessage` is set and rendered in red. `.disabled(authViewModel.isLoading)` blocks double-taps; a `ProgressView` overlay shows while loading.
- **Sign up**: `RegistrationView` → `authViewModel.signUp(...)` → `AuthService.signUp` (writes name/phone into auth metadata) → a DB trigger creates the `users` row → the app signs out and shows "check your email."

### F.3 Customer creates an order (the request side)

Driven by [OrderViewModel](MbengkelIn/ViewModels/OrderViewModel.swift):

1. `prepareForNewOrder()` resets all per-order state, including `hasResolvedLocation = false`.
2. Customer picks a **service** (`selectService`), which sets `estimatedPrice` from `ServiceType.minPrice` (× tire count for tire services).
3. Customer sets **location** three possible ways, each setting `hasResolvedLocation = true`: tap "use current location" (CoreLocation GPS → reverse-geocode via Photon), drag the map (`updateLocationFromMap`), or search an address (`selectSearchResult`). The live address search is a Combine pipeline: `$locationAddress` is **debounced 400ms**, de-duplicated, and routed to `searchOSM` ([OrderViewModel.swift](MbengkelIn/ViewModels/OrderViewModel.swift#L67-L78)). The `hasResolvedLocation` guard exists specifically to stop the app from silently creating an order at the default coordinate.
4. For tire services, the customer attaches one photo per tire.
5. `createOrder()` validates (service chosen, location resolved, vehicle chosen, photo count matches tire count), uploads photos to the `order-photos` bucket, stashes the pending details, and navigates to the bidding screen.

### F.4 Bidding (the auction)

Customer side — [CustomerBiddingViewModel](MbengkelIn/ViewModels/CustomerBiddingViewModel.swift):

1. `startSearch(price:)`: checks `price ≥ minPrice`, refetches the user, verifies `availableBalance ≥ price`, then **inserts** a `service_requests` row with `status: "To Do"` (or updates the existing one's price). That insert fires the balance trigger → the price is now **held** in escrow.
2. Subscribes to realtime on `bids` for this request, starts the 120s search countdown.
3. Mechanics nearby (next flow) place bids → realtime fires → `loadReceivedBids()` re-fetches the pending bids (cheapest first), pushes a local notification for each genuinely new bid (tracked via the `knownBidIds` `Set`), and arms the per-offer expiry watcher.
4. Customer **accepts** a bid → `OrderRepository.acceptBid` → the `accept_bid` RPC atomically marks it Accepted, AutoRejects the rest, and flips the order to On Progress (trigger moves money to the provider's `pending_balance`). Or the customer **rejects** (`status = "Rejected"`) or lets it **expire** (`status = "Expired"`).
5. If the search times out with no bids, the customer is prompted to retry, raise the price, or cancel (which deletes the order and its photos, releasing the hold).

Mechanic side — `BengkelBiddingViewModel` (invoked globally for providers from `ContentView`):

1. Subscribes to realtime on open `service_requests` (the open-orders RLS policy lets them see unassigned `To Do` rows). New rows produce an **incoming-job modal** (`IncomingJobModal` via `.sheet(item:)`).
2. Mechanic taps to bid → `PlaceBidSheet` (price ≥ the order's min) → `placeBid(...)` via the `bidding` edge function → a `bids` row appears, which the customer receives in realtime.
3. If the mechanic's bid is accepted, `activeBengkelOrder` is set → a `fullScreenCover` presents `BengkelRouteView` (navigation to the customer). If they lose/expire/get-rejected, ContentView surfaces an alert (`lostBidAlert`, `expiredBidAlert`, `rejectedBidAlert`).

### F.5 In-progress: tracking, live location, chat

- The assigned mechanic publishes their GPS to `order_locations` (`LocationPublishViewModel`); the customer's `OrderTrackingViewModel` subscribes via realtime and animates the mechanic's marker on the OSM map. `order_locations` has `replica identity full` so filtered updates carry full rows.
- `ChatViewModel` provides per-order chat backed by `chat_messages` (realtime), with image messages in the `chat-images` bucket, plus presence and read-cursor services.

### F.6 Completion & rating

- The order uses **dual confirmation**: `customer_completed` and `provider_completed`. Each side taps "done"; `mark_order_completed` flips status to "Done" only when **both** are true. That On Progress → Done transition fires the trigger that settles money (customer pays, provider earns).
- `completed_at` is stamped, feeding the bengkel's "Pendapatan Hari Ini" (today's earnings) — see [OrderRepository.fetchTodaysEarnings](MbengkelIn/Repositories/OrderRepository.swift#L23-L34).
- The customer then rates via the `rate_order` RPC, which writes `rating`/`review` and fires a trigger recomputing the bengkel's `average_rating` and `total_reviews`.

### F.7 Payments (top-up & withdrawal)

- **Top-up**: `PaymentViewModel` → `PaymentService.createTopup` → `payment` edge function → Midtrans Snap URL → shown in a `MidtransWebView`. When the user pays, Midtrans calls `midtrans-webhook`, which verifies the signature and credits `balance` via `increment_user_balance`. The client sees the new balance arrive via realtime on `topups`/`users`.
- **Withdrawal**: created via the `request_withdrawal` RPC (validates against `availableBalance`, not raw balance). `withdrawals` is realtime-published so the list updates live.

---

# Part G — Money integrity & security model

The defining backend principle: **the client is never trusted with money or authorization.** Concretely:

1. **No client-passed user IDs for money.** Trusted functions read `auth.uid()` from the JWT, not a parameter. `accept_bid` checks `sr.customer_id <> auth.uid()` and refuses if they differ.
2. **All money movement is server-side**, in `SECURITY DEFINER` RPCs and triggers, inside transactions with row locks (`for update`). The Swift app only *reads* balances; it never adds, holds, or settles money itself.
3. **RLS on every table** scopes reads/writes per user — and doubles as the realtime authorization layer.
4. **RPC execute grants are locked down** to `authenticated` (a dedicated migration revokes broad grants).
5. **Webhooks verify signatures** before crediting (Midtrans), so only legitimate settlement callbacks add funds.

The net effect: even a modified/malicious client can't over-spend, double-accept an order, credit itself, or see other users' private rows, because Postgres — not the app — is the gatekeeper.

---

# Part H — The watchOS companion

A **customer-only** Apple Watch app that mirrors the active order. It has **no login, no text entry, and links no Supabase SDK**. Architecture is **"phone as the brain"**:

- The **iPhone** is the authenticated client. `WatchSessionManager` (a `@MainActor` singleton, [WatchSessionManager.swift](MbengkelIn/Services/WatchConnectivity/WatchSessionManager.swift)) subscribes to the customer's active `service_requests` + `bids` via realtime, builds a `WatchOrderState` snapshot, JSON-encodes it, and pushes it to the watch via `WCSession.updateApplicationContext`. It also forwards each local notification via `transferUserInfo`.
- The **watch** receives that state and renders a 3-stage progress bar (**Mencari Bengkel → Sedang Dikerjakan → Selesai**), accept-only offer rows, a finish button, and a tappable star rating. When the user acts, the watch sends a command (`approveBid`/`finishJob`/`submitRating`) back via `WCSession.sendMessage`; the phone executes it against the existing repositories (`OrderRepository.acceptBid` / `markOrderCompleted` / `submitRating`).

Communication is **WatchConnectivity** (`WCSession`), Apple's phone↔watch channel — *not* Supabase. The `WatchOrderState` DTO is intentionally **duplicated** in both targets ([Models/DTOs/WatchOrderState.swift](MbengkelIn/Models/DTOs/WatchOrderState.swift) and the watch copy) because the two build targets share no files. It's `Codable` (so it can be JSON-encoded across the bridge) and `Equatable` (so the phone can skip re-sending an unchanged state).

---

# Appendix — Swift symbol cheat sheet

| Symbol / keyword | Meaning |
|---|---|
| `let` / `var` | immutable / mutable binding |
| `Type?` | **optional** — value or `nil` |
| `x?.y` | optional chaining — `y` only if `x` non-nil, else whole expr is nil |
| `x ?? y` | nil-coalescing — `x`, or `y` if `x` is nil |
| `x!` | force-unwrap an optional (crash if nil) |
| `if let x = opt` / `guard let x = opt else {…}` | safely unwrap |
| `:` | "has type", or "conforms to / inherits" |
| `->` | function return type |
| `_` | "ignore this" (unused arg label, unused value, discarded element) |
| `$0`, `$1` | shorthand closure arguments |
| `\.foo` | key path (a reference to property `foo`) |
| `\( … )` | string interpolation |
| `{ … }` (as an argument) | a closure (anonymous function) |
| `[weak self]` | capture `self` weakly to avoid a retain cycle |
| `async` / `await` | asynchronous function / suspension point |
| `Task { … }` | start async work from sync code |
| `for await x in seq` | async loop over an async sequence |
| `throws` / `try` / `try?` / `try!` | can-error / call it / make-optional-on-error / crash-on-error |
| `do { } catch { }` | handle thrown errors |
| `defer { }` | run on scope exit, always |
| `some View` | opaque return type (one concrete View, unspelled) |
| `@Published` | ObservableObject property that triggers UI updates |
| `@State` / `@Binding` | view-local state / a reference to someone else's state |
| `@StateObject` / `@ObservedObject` | own / receive an ObservableObject |
| `$value` | the projected value (usually a Binding) of a wrapped property |
| `@MainActor` | runs on the main thread (UI-safe) |
| `nonisolated` | opt a method out of its actor's isolation |
| `struct` / `class` / `enum` | value type / reference type / fixed-set type |
| `protocol` | interface |
| `Codable` / `Identifiable` / `Equatable` / `Hashable` / `CaseIterable` | JSON-convertible / has `id` / `==` / hashable / `.allCases` |
| `static` | type-level member |
| `self` / `Self` | this instance / this type |

---

## One-paragraph summary

MbengkelIn is a SwiftUI iOS app where the UI (Views) observes `@MainActor` ViewModels (`ObservableObject`s with `@Published` state), which orchestrate stateless Repositories (table CRUD) and Services (auth, storage, geocoding, payments, the watch bridge), passing pure `struct` Models and DTOs around. It talks almost directly to a Supabase Postgres backend; trust lives in the database — RLS policies scope every row per user (doubling as realtime authorization), and all money/authorization logic runs in `SECURITY DEFINER` RPCs and triggers keyed on `auth.uid()`, never on the client. Realtime websockets stream row changes that ViewModels use as a signal to re-fetch authoritative data (never polling). The core flow is a reverse auction: a customer posts a request (money held by a trigger), nearby mechanics bid live, the customer accepts one (atomic RPC → money earmarked), both confirm completion (trigger settles the payment), and the customer rates the mechanic — with an Apple Watch companion mirroring it all over WatchConnectivity while the phone does the actual backend work.
