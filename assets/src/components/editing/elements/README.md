# Editor components

Editor components allow the display and editing of content model elements.

One editor component is created for each content model element (e.g. p, table,
img, etc).

## Creating a new editor component

Here are the steps required to implement new editor components.

1. Develop the React component that renders and allows editing of the contet model element. Use an existing
   editor component (e.g. `Image.tsx`) as an example for how to structure your component. Wire the completed component
   into the `editorFor` factory function in `../editors.tsx`.
2. Perform any customization of the Slate editor by creating a custom `with` function and inserting it into the
   change of withs in `../Editor.tsx`.
3. Develop a `Command` within `commands` to use in creating instances of content model elements that pertain to your
   editor component.
