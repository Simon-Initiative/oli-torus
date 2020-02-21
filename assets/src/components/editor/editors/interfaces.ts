
import { ReactEditor } from 'slate-react';
import * as ContentModel from 'data/content/model';

// This is the interface that all editing components must implement.
// Note the lack of an onEdit callback. The components instead directly
// use the editor reference to change the model element (using updateModel helper
// from ./utils is the preferred way to do this).  The top level slate onChange
// event will then fire and the model update will be reflected in the complete
// slate data model.

export interface EditorProps<T extends ContentModel.ModelElement> {
  model: T;            // The model (like an image, or youtube)
  editor: ReactEditor; // The slate instance containing this editor component
  attributes: any;     // Slate attributes that must be rendering as part of the
                       // top level dom element that the component renders.
  children: any;       // The child elements that the component must render.

  showPopup: (e: JSX.Element) => void;  // Displays an element in the singleton popup state
}
