import { useAuthoringElementContext } from 'components/activities/AuthoringElement';
import { ErrorBoundary } from 'components/common/ErrorBoundary';
import { Editor } from 'components/editing/editor/Editor';
import { getToolbarForContentType } from 'components/editing/toolbars/insertion/items';
import React from 'react';
import { classNames } from 'utils/classNames';
export const RichTextEditor = (props) => {
    // Support content persisted when RichText had a `model` property.
    const value = props.value.model ? props.value.model : props.value;
    return (<div className={classNames(['rich-text-editor', props.className])}>
      <ErrorBoundary>
        <Editor normalizerContext={props.normalizerContext} commandContext={props.commandContext || { projectSlug: props.projectSlug }} editMode={props.editMode} value={value} onEdit={(value, editor, operations) => props.onEdit(value, editor, operations)} toolbarItems={getToolbarForContentType(props.onRequestMedia, props.preventLargeContent ? 'small' : undefined)} placeholder={props.placeholder} style={props.style}>
          {props.children}
        </Editor>
      </ErrorBoundary>
    </div>);
};
export const RichTextEditorConnected = (props) => {
    const { editMode, projectSlug, onRequestMedia } = useAuthoringElementContext();
    return (<RichTextEditor {...props} editMode={editMode} projectSlug={projectSlug} onRequestMedia={onRequestMedia}/>);
};
//# sourceMappingURL=RichTextEditor.jsx.map