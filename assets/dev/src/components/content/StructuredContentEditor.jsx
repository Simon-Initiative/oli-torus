import React from 'react';
import { Editor } from 'components/editing/editor/Editor';
import { ErrorBoundary } from 'components/common/ErrorBoundary';
// The resource editor for content
export const StructuredContentEditor = (props) => {
    const onEdit = React.useCallback((children) => {
        props.onEdit(Object.assign({}, props.content, { children }));
    }, [props.content, props.onEdit]);
    return (<ErrorBoundary>
      <Editor className="structured-content" commandContext={{ projectSlug: props.projectSlug }} editMode={props.editMode} value={props.content.children} onEdit={onEdit} toolbarItems={props.toolbarItems}/>
    </ErrorBoundary>);
};
//# sourceMappingURL=StructuredContentEditor.jsx.map