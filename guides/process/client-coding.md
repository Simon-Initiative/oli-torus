# Client-side coding standard

This document outlines the rules and guidelines for client-side code development in Torus.

Client-side code here refers to any code written by Torus developers that runs client-side in the browser. This includes complete standalone React applications and small snippets of code that run in the context of a server-rendered page.

Each item here is categorized as either a rule (required) or a guideline (recommended but not absolutely required). Guidelines recognize that there are always unique circumstances where it makes sense to depart from the recommendation. Rules will include words like `must` and `always` and guidelines include words like `should` and `can`.

## Core language

All client-side code must be written in Typescript as opposed to being written directly in JavaScript.

All code must be formatted using [Prettier](https://prettier.io) and pass [ESLint](https://eslint.org/) checks. A GitHub build step will fail for any PR that includes code that triggers an ESLint error.

### Types

Developers should leverage the TypeScript type system to model the domain as much as possible. This includes using type aliases, union and intersection types, discriminated union types, and utility types (`Partial<Type>`, `Readonly<Type>`, etc).

Developers should add TypeScript type annotations to all new code.

Developers should use the TypeScript `type` construct over an `interface` for all cases except for when extensibility is needed. For example, a `type` cannot be used in the following:

```javascript
interface Identifiable {
  id: string;
}

export interface Paragraph extends Identifiable {
  type: "p";
}
```

### Async code

Async code should be written using standard ES6 Promise support or async/await features.

### Functional programming

Code should be written in a functional programming style, leveraging first-class functions, programming as transformation, immutability, pure functions, etc.

#### Immutability

Code should be written leveraging immutable data structures and techniques as must as possible, this is particular importance in React-based UI code.

Legacy Echo code that ports existing Immutable.js code can stay as-is, but new code that needs immutable data structures should be written using Immer.js.

Developers can use the `Object.assign({}, current, update)` pattern as well.

#### Programming as transformation

For conciseness and readability, Code should make heavy use of `map` and `reduce` style data transformations instead of imperative loops and similar constructs. For example:

```javascript
return Object.keys(textEntity)
  .filter((attr) => textEntity[attr] === true)
  .map((attr) => supportedMarkTags[attr])
  .filter((mark) => mark)
  .reduce((acc, mark) => `<${mark}>${acc}</${mark}>`, text);
```

## UI

### Library/framework

User interfaces must be built using React.

Developers should seek first to implement a React component as a functional stateless component. State, if needed, should be added via `useState` or `useReducer` hooks. Side effects should be incorporated via `useEffect`. For more complicated use cases it is acceptable to fall back to a traditional, class-based React component.

### State management

Developers should strive to use the simplest approach possible for global state management. The simplest approach being not using any third-party state management library and instead just maintaining all top-level state in a component (via `useReducer` or one or more `useState` hooks) and passing it down through properties. This approach only scales so far, thus for more complicated applications developers should fall back to a third-party library for global state management.

Our team's experience with Redux overall has been positive, but we recognize that there is a substantial amount of boilerplate in a type-safe Redux implementation. Given that Torus client tends to have smaller, more focused apps we are seeking lighter-weight Redux alternatives including `useReducer` and up and coming new libraries such as [https://recoiljs.org/](https://recoiljs.org/)

### Styling

Components should leverage Bootstrap 4 and be written in a way that works with the Torus theming approach. TODO add more details here, but a main takeaway is that any custom CSS should be captured in a `.scss` definition file.

## Testing

Code should be unit tested using the existing `jest` based unit testing infrastructure.

UI code should be structured in a way that allows the implementation of the logic to be decoupled from the UI implementation, so that this logic can be easily unit tested.
