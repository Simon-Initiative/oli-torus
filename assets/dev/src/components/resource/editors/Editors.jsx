import React, { useState } from 'react';
import isHotkey from 'is-hotkey';
import { ActivityPurposes, ContentPurposes, } from 'data/content/resource';
import { classNames } from 'utils/classNames';
import { AddResourceOrDropTarget } from './AddResourceOrDropTarget';
import { createEditor } from './createEditor';
import { focusHandler } from './dragndrop/handlers/focus';
import { moveHandler } from './dragndrop/handlers/move';
import { dragEndHandler } from './dragndrop/handlers/dragEnd';
import { dropHandler } from './dragndrop/handlers/drop';
import { getDragPayload } from './dragndrop/utils';
import { dragStartHandler } from './dragndrop/handlers/dragStart';
import { EditorErrorBoundary } from './editor_error_boundary';
// The list of editors
export const Editors = (props) => {
    const objectivesMap = props.resourceContext.allObjectives.reduce((m, o) => {
        m[o.id] = o.title;
        return m;
    }, {});
    const { editMode, graded, content, activityContexts, projectSlug, resourceSlug, editorMap, onEditContentList, onAddItem, onActivityEdit, onPostUndoable, onRegisterNewObjective, } = props;
    const [assistive, setAssistive] = useState('');
    const [activeDragId, setActiveDragId] = useState(null);
    const isReorderMode = activeDragId !== null;
    const onFocus = focusHandler(setAssistive, content, editorMap, activityContexts);
    const onMove = moveHandler(content, onEditContentList, editorMap, activityContexts, setAssistive);
    const onDragEnd = dragEndHandler(setActiveDragId);
    const onDrop = dropHandler(content, onEditContentList, projectSlug, onDragEnd, editMode);
    const allObjectives = props.objectives.toArray();
    const allTags = props.allTags.toArray();
    const editors = content.entrySeq().map(([contentKey, contentValue], index) => {
        const onEdit = (u) => props.onEdit(u, contentKey);
        const onRemove = () => props.onRemove(contentKey);
        const onEditPurpose = (purpose) => {
            props.onEdit(Object.assign(contentValue, { purpose }), contentKey);
        };
        const purposes = contentValue.type === 'content' ? ContentPurposes : ActivityPurposes;
        const dragPayload = getDragPayload(contentValue, activityContexts, projectSlug);
        const onDragStart = dragStartHandler(dragPayload, contentValue, setActiveDragId);
        // register keydown handlers
        const isShiftArrowDown = isHotkey('shift+down');
        const isShiftArrowUp = isHotkey('shift+up');
        const handleKeyDown = (e) => {
            if (isShiftArrowDown(e.nativeEvent)) {
                onMove(contentKey, false);
            }
            else if (isShiftArrowUp(e.nativeEvent)) {
                onMove(contentKey, true);
            }
        };
        const editorProps = {
            purposes,
            onDragStart,
            onDragEnd,
            editMode,
            onEditPurpose,
            content,
            onRemove,
        };
        const editor = createEditor(props.resourceContext, contentValue, index, activityContexts, editMode, resourceSlug, projectSlug, graded, objectivesMap, editorProps, allObjectives, allTags, editorMap, onEdit, onActivityEdit, onPostUndoable, onRegisterNewObjective, props.onRegisterNewTag);
        return (<div key={'control-container-' + contentKey} id={`re${contentKey}`} className={classNames([
                'resource-block-editor-and-controls',
                contentKey,
                contentKey === activeDragId ? 'is-dragging' : '',
            ])}>
        <AddResourceOrDropTarget id={contentKey} objectives={props.objectives} childrenObjectives={props.childrenObjectives} onRegisterNewObjective={props.onRegisterNewObjective} index={index} editMode={editMode} isReorderMode={isReorderMode} editorMap={editorMap} resourceContext={props.resourceContext} onAddItem={onAddItem} onDrop={onDrop}/>

        <div className={classNames(['resource-block-editor', isReorderMode ? 'reorder-mode' : ''])} onKeyDown={handleKeyDown} onFocus={(_e) => onFocus(contentKey)} role="option" aria-describedby="content-list-operation" tabIndex={index + 1}>
          <EditorErrorBoundary id={contentKey}>{editor}</EditorErrorBoundary>
        </div>
      </div>);
    });
    return (<div className="editors d-flex flex-column flex-grow-1">
      {editors}

      <AddResourceOrDropTarget {...props} onRegisterNewObjective={props.onRegisterNewObjective} id="last" index={editors.size || 0} editMode={editMode} isReorderMode={isReorderMode} editorMap={editorMap} resourceContext={props.resourceContext} onAddItem={onAddItem} onDrop={onDrop}/>
    </div>);
};
//# sourceMappingURL=Editors.jsx.map