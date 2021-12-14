import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { createEditor } from 'slate';
import { withHistory } from 'slate-history';
import { Editable, Slate, withReact } from 'slate-react';
import guid from 'utils/guid';
import { formatMenuCommands } from '../toolbars/formatting/items';
import { FormattingToolbar } from '../toolbars/formatting/Toolbar';
import { shouldShowFormattingToolbar } from '../toolbars/formatting/utils';
import { HoveringToolbar } from '../toolbars/HoveringToolbar';
import { InsertionToolbar } from '../toolbars/insertion/Toolbar';
import { hotkeyHandler } from './handlers/hotkey';
import { onKeyDown as listOnKeyDown } from './handlers/lists';
import { onKeyDown as quoteOnKeyDown } from './handlers/quote';
import { onKeyDown as titleOnKeyDown } from './handlers/title';
import { onKeyDown as voidOnKeyDown } from './handlers/void';
import { editorFor, markFor } from './modelEditorDispatch';
import { installNormalizer } from './normalizers/normalizer';
import { withInlines } from './overrides/inlines';
import { withMarkdown } from './overrides/markdown';
import { withTables } from './overrides/tables';
import { withVoids } from './overrides/voids';
// Necessary to work around FireFox focus and selection issues with Slate
// https://github.com/ianstormtaylor/slate/issues/1984
function emptyOnFocus() {
    return;
}
function areEqual(prevProps, nextProps) {
    return (prevProps.editMode === nextProps.editMode &&
        prevProps.toolbarItems === nextProps.toolbarItems &&
        prevProps.value === nextProps.value &&
        prevProps.placeholder === nextProps.placeholder);
}
export const Editor = React.memo((props) => {
    const [isPerformingAsyncAction, setIsPerformingAsyncAction] = useState(false);
    const [installed, setInstalled] = useState(false);
    const commandContext = props.commandContext;
    const editor = useMemo(() => withMarkdown(commandContext)(withReact(withHistory(withTables(withInlines(withVoids(createEditor())))))), []);
    // Install the custom normalizer, only once
    useEffect(() => {
        if (!installed) {
            installNormalizer(editor, props.normalizerContext);
            setInstalled(true);
        }
    }, [installed]);
    const renderElement = useCallback((props) => {
        const model = props.element;
        return editorFor(model, props, editor, commandContext);
    }, [commandContext]);
    const onKeyDown = useCallback((e) => {
        voidOnKeyDown(editor, e);
        listOnKeyDown(editor, e);
        quoteOnKeyDown(editor, e);
        titleOnKeyDown(editor, e);
        hotkeyHandler(editor, e.nativeEvent, commandContext);
    }, []);
    const renderLeaf = useCallback(({ attributes, children, leaf }) => {
        const markup = Object.keys(leaf).reduce((m, k) => (k !== 'text' ? markFor(k, m) : m), children);
        return <span {...attributes}>{markup}</span>;
    }, []);
    const onChange = (value) => {
        const { operations } = editor;
        // Determine if this onChange was due to an actual content change.
        // Otherwise, undo/redo will save pure selection changes.
        if (operations.filter(({ type }) => type !== 'set_selection').length) {
            props.onEdit(value, editor, operations);
        }
    };
    const normalizedValue = props.value.length === 0 ? [{ type: 'p', id: guid(), children: [{ text: '' }] }] : props.value;
    return (<React.Fragment>
      <Slate editor={editor} value={normalizedValue} onChange={onChange}>
        {props.children}
        <InsertionToolbar isPerformingAsyncAction={isPerformingAsyncAction} toolbarItems={props.toolbarItems} commandContext={props.commandContext}/>

        <HoveringToolbar isOpen={shouldShowFormattingToolbar}>
          <FormattingToolbar commandDescs={formatMenuCommands} commandContext={props.commandContext}/>
        </HoveringToolbar>

        <Editable style={props.style} className={'slate-editor overflow-auto' + (props.className ? ' ' + props.className : '')} readOnly={!props.editMode} renderElement={renderElement} renderLeaf={renderLeaf} placeholder={props.placeholder === undefined ? 'Enter some content here...' : props.placeholder} onKeyDown={onKeyDown} onFocus={emptyOnFocus} onPaste={() => { }
        //   async (
        //   e: React.ClipboardEvent<HTMLDivElement>,
        //   editor: SlateEditor,
        //   // eslint-disable-next-line
        //   next: Function,
        // ) => {
        //   setIsPerformingAsyncAction(true);
        //   await onPaste(editor, e, props.commandContext.projectSlug);
        //   setIsPerformingAsyncAction(false);
        //   next();
        // }
        }/>
      </Slate>
    </React.Fragment>);
}, areEqual);
Editor.displayName = 'Editor';
//# sourceMappingURL=Editor.jsx.map