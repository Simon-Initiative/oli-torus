# TypeScript + React Review Checklist

> Use this during PR review to catch correctness, maintainability, and performance issues. Leave **specific, actionable** comments (file:line + suggested fix). Keep types sound at **boundaries**, state minimal, and renders cheap.

---

## 1) TypeScript Fundamentals

### Project config
- [ ] `tsconfig.json` enables strictness: `"strict": true`, `"noImplicitAny": true`, `"noUncheckedIndexedAccess": true`, `"exactOptionalPropertyTypes": true`, `"useUnknownInCatchVariables": true`, `"noFallthroughCasesInSwitch": true`, `"forceConsistentCasingInFileNames": true`, `"verbatimModuleSyntax": true`, `"jsx": "react-jsx"`.
- [ ] ES modules + tree-shaking friendly: `"module": "esnext"`, `"moduleResolution": "bundler" | "nodenext"`, `"target": "es2022+"`.
- [ ] Linting & types in CI: `eslint --max-warnings=0` and `tsc --noEmit`.

### Types & safety
- [ ] Avoid `any`. Prefer `unknown` + **narrowing** (type predicates).
- [ ] Prefer **discriminated unions** over inheritance and enums.
- [ ] Prefer **readonly** and immutability for shared objects/arrays.
- [ ] Avoid **non-null assertions** (`!`). Narrow instead.
- [ ] No unsafe casts: prefer `satisfies` and `as const` where appropriate.
- [ ] Exhaustive handling for unions via `assertNever`.

**assertNever helper**
```ts
function assertNever(x: never): never {
  throw new Error(`Unhandled case: ${String(x)}`);
}
```

**satisfies + const**
```ts
const roles = ["admin", "editor", "viewer"] as const;
type Role = (typeof roles)[number];

const perms = {
  admin: ["*"],
  editor: ["write", "read"],
  viewer: ["read"],
} as const satisfies Record<Role, readonly string[]>;
```

### Runtime validation at boundaries
- [ ] **Validate untrusted input** (HTTP, storage) with a schema (e.g., zod) before using.
- [ ] Keep DTO types (wire) separate from **domain** types.

```ts
import { z } from "zod";
const UserDto = z.object({ id: z.string(), email: z.string().email() });
type User = z.infer<typeof UserDto>;
const user = UserDto.parse(await res.json());
```

### Errors & async
- [ ] No **floating promises** (await or handle). Use ESLint rule to enforce.
- [ ] Narrow `unknown` in `catch (e)` with user guards; avoid relying on `instanceof Error` only.

---

## 2) React Components

### Component structure
- [ ] **Function components** with typed props; avoid default exports for shared components.
- [ ] Props are **narrow** and stable; avoid passing large objects when only a few fields are needed.
- [ ] `children` typed via `PropsWithChildren` or explicit `ReactNode`.

```ts
type ButtonProps = React.ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: "primary" | "ghost";
};
export function Button({ variant = "primary", ...rest }: ButtonProps) {
  return <button data-variant={variant} {...rest} />;
}
```

### Lists & keys
- [ ] Keys are **stable and unique** (domain id), not array index (unless truly static).
- [ ] Avoid re-creating arrays/objects in render (extract constants/hooks).

### Controlled state
- [ ] Keep **state minimal** and derived where possible (compute from props).
- [ ] Avoid duplicating server state in React state; use a data library for caching (e.g., TanStack Query).
- [ ] For complex local state, use `useReducer` with typed actions.

```ts
type Action =
  | { type: "inc" }
  | { type: "set"; value: number };

function reducer(s: number, a: Action) {
  switch (a.type) {
    case "inc": return s + 1;
    case "set": return a.value;
    default: return assertNever(a);
  }
}
```

### Refs vs state
- [ ] Use `useRef` for **mutable, non-rendering** values (timers, DOM).
- [ ] Don’t store DOM nodes in state.

---

## 3) Hooks Correctness

- [ ] **Rules of Hooks** obeyed (top-level only; never in conditionals/loops).
- [ ] **Dependencies** for `useEffect/useMemo/useCallback` are correct and exhaustive (lint rule).
- [ ] Effects **clean up** subscriptions/timeouts/observers.
- [ ] Avoid stale closures: include used values in deps or use functional setState.

```ts
useEffect(() => {
  const id = setInterval(() => setCount(c => c + 1), 1000);
  return () => clearInterval(id);
}, []); // uses functional update → [] OK
```

- [ ] `useMemo`/`useCallback` used to **stabilize props** to memoized children—but not sprinkled everywhere needlessly.
- [ ] `useTransition` for non-blocking UI updates; `useDeferredValue` to throttle heavy derived computations.

---

## 4) Data Fetching & Caching

- [ ] Fetching abstracted into **custom hooks** (`useUser`), returning `{ data, isLoading, error }`.
- [ ] Requests are **abortable** (AbortController) and handle race conditions on rapid changes.
- [ ] Avoid **setState after unmount** (cleanup/abort in effects).
- [ ] Use **incremental rendering**: Suspense/lazy where appropriate; error boundaries present.

```ts
export function useUser(id: string) {
  return useQuery({ queryKey: ["user", id], queryFn: () => fetchUser(id) });
}
```

---

## 5) Performance

- [ ] Avoid expensive work in render; memoize heavy derived data.
- [ ] Large lists virtualized; images lazy-loaded with intrinsic sizing to avoid layout shift.
- [ ] Prevent unnecessary renders: `React.memo`, stable function/obj props, context slice selectors.
- [ ] Split bundles: `React.lazy` + `Suspense` for rarely used routes/components.

**Memo with stable deps**
```ts
const columns = useMemo(() => buildColumns(locale), [locale]);
```

---

## 6) Accessibility (React specifics)

- [ ] Semantic elements: buttons for actions, links for navigation.
- [ ] Labels for inputs; associate errors via `aria-describedby`, set `aria-invalid` properly.
- [ ] Keyboard operability: focus order, Escape closes dialogs/menus, arrow keys for menus/lists.
- [ ] No `dangerouslySetInnerHTML` with untrusted input; sanitize if unavoidable.
- [ ] Manage focus on route/page changes and when opening/closing modals (restore focus to trigger).

---

## 7) Styling & Theming

- [ ] Design tokens (colors/spacing/typography) centralized; no hard-coded hex scattered.
- [ ] Respect `prefers-reduced-motion`; avoid long blocking animations.
- [ ] Class composition is **deterministic** (e.g., `clsx`, variant utilities) rather than string concat.

---

## 8) Module Boundaries & Imports

- [ ] No circular imports; avoid overusing barrels that hide cycles.
- [ ] Side-effect files are explicit (package.json `"sideEffects"` correct) for tree-shaking.
- [ ] Public API of component libs is small and documented.

---

## 9) Testing

- [ ] **React Testing Library** used: test behavior, not implementation details.
- [ ] **Type tests** for public APIs (e.g., `expectTypeOf`, tsd) where helpful.
- [ ] Async UI tests await settled state (`findBy*`, `waitFor`); no arbitrary `setTimeout`.
- [ ] Accessibility smoke via `axe` on key screens.

---

## Reviewer Red Flags (paste with suggestions)

- “`any` used in public API—replace with union/interface and narrow unknowns.”
- “Effect missing dependency `X`; causes stale closure. Add to deps or switch to functional update.”
- “List uses index as key but order changes—use stable id to prevent state mismatch.”
- “Heavy computation in render—wrap with `useMemo` keyed by inputs.”
- “Untrusted HTML passed to `dangerouslySetInnerHTML`—sanitize or remove.”
- “State duplicates props/derived data—remove and derive in render.”
- “Custom hook returns raw promise—wrap in `{ data, isLoading, error }` and handle abort.”
- “Context provider re-renders everything—split context or memoize value.”

---

## Quick Verification (fast)

- [ ] `tsc --noEmit` passes with strict config.
- [ ] ESLint clean with `plugin:@typescript-eslint/recommended` and `react-hooks` rules.
- [ ] Keyboard walkthrough of changed UI paths (Tab/Shift+Tab/Enter/Esc).
- [ ] React Profiler shows no pathological re-renders after change.
- [ ] Bundle diff for large PRs (no unintended large deps).

---

## Snippets (drop-in fixes)

**Narrowing unknown**
```ts
function isApiError(e: unknown): e is { message: string; code: string } {
  return !!e && typeof e === "object" && "message" in e && "code" in e;
}
try { /* ... */ } catch (e) {
  const msg = isApiError(e) ? e.message : "Unknown error";
}
```

**Abortable fetch**
```ts
useEffect(() => {
  const ac = new AbortController();
  (async () => {
    const res = await fetch(`/api/users/${id}`, { signal: ac.signal });
    if (!res.ok) throw new Error("Bad response");
    setUser(await res.json());
  })().catch(err => {
    if ((err as { name?: string }).name !== "AbortError") setError(err as Error);
  });
  return () => ac.abort();
}, [id]);
```

**Stable context value**
```ts
const Ctx = React.createContext<{count: number; inc(): void} | null>(null);

function Provider({ children }: React.PropsWithChildren) {
  const [count, set] = useState(0);
  const inc = useCallback(() => set(c => c + 1), []);
  const value = useMemo(() => ({ count, inc }), [count, inc]);
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}
```

**Typed component with generics**
```ts
type Option<T extends string | number> = { label: string; value: T };

interface SelectProps<T extends string | number> {
  options: readonly Option<T>[];
  value: T | null;
  onChange(v: T): void;
}
export function Select<T extends string | number>({ options, value, onChange }: SelectProps<T>) {
  // ...
  return (
    <ul>
      {options.map(o => (
        <li key={o.value.toString()}>
          <button onClick={() => onChange(o.value)}>{o.label}</button>
        </li>
      ))}
    </ul>
  );
}
```
