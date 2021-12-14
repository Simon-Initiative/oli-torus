import React from 'react';
import { updateModel, getEditMode } from '../utils';
import * as Settings from 'components/editing/models/settings/Settings';
export const AudioEditor = (props) => {
    const { attributes, children, editor, model } = props;
    const editMode = getEditMode(editor);
    const onEdit = (updated) => {
        updateModel(editor, model, updated);
    };
    const update = (attrs) => Object.assign({}, model, attrs);
    const setCaption = (caption) => {
        onEdit(update({ caption }));
    };
    // Note that it is important that any interactive portions of a void editor
    // must be enclosed inside of a "contentEditable=false" container. Otherwise,
    // slate does some weird things that non-deterministically interface with click
    // events.
    const { src } = model;
    return (<div {...attributes} className="ml-4 mr-4">
      <div style={{ overflow: 'auto', userSelect: 'none' }}>
        <div className="ml-4 mr-4 text-center">
          <figure contentEditable={false}>
            <audio style={{ margin: 'auto' }} src={src} controls/>
            <figcaption contentEditable={false} style={{ userSelect: 'none' }}>
              <Settings.Input editMode={editMode} value={model.caption} onChange={(value) => setCaption(value)} editor={editor} model={model} placeholder="Set a caption for this audio file"/>
            </figcaption>
          </figure>
        </div>
      </div>
      {children}
    </div>);
};
//# sourceMappingURL=Editor.jsx.map