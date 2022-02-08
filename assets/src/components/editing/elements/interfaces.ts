import * as ContentModel from 'data/content/model/elements/types';
import { RenderElementProps } from 'slate-react';
import { CommandContext } from './commands/interfaces';

// This is the interface that all editing components must implement.
// Note the lack of an onEdit callback. The components instead directly
// use the editor reference to change the model element (using updateModel helper
// from ./utils is the preferred way to do this).  The top level slate onChange
// event will then fire and the model update will be reflected in the complete
// slate data model.

export interface EditorProps<T extends ContentModel.ModelElement> {
  // The context for button/toolbar actions like toggling or inserting
  // elements.
  commandContext: CommandContext;

  // The model / content element to render (like an image, or youtube)
  model: T;

  // Slate attributes that must be rendering as part of the
  // top level dom element that the component renders.
  attributes: RenderElementProps['attributes'];

  // The child elements that the component must render.
  children: any;
}
