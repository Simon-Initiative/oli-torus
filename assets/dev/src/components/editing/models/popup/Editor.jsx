import { modalActions } from 'actions/modal';
import { createButtonCommandDesc } from 'components/editing/commands/commands';
import { PopupContentModal } from 'components/editing/models/popup/PopupContentModal';
import { updateModel } from 'components/editing/models/utils';
import { FormattingToolbar } from 'components/editing/toolbars/formatting/Toolbar';
import { HoveringToolbar } from 'components/editing/toolbars/HoveringToolbar';
import { centeredAbove } from 'data/content/utils';
import React from 'react';
import { Range } from 'slate';
import { useFocused, useSelected } from 'slate-react';
import './Editor.scss';
export const PopupEditor = (props) => {
    const focused = useFocused();
    const selected = useSelected();
    const { attributes, children, editor, model } = props;
    const onEdit = (changes) => {
        updateModel(editor, model, changes);
    };
    const commands = [
        [
            createButtonCommandDesc({
                icon: 'edit',
                description: 'Edit content',
                execute: (_context, _editor, _params) => {
                    const dismiss = () => window.oliDispatch(modalActions.dismiss());
                    const display = (c) => window.oliDispatch(modalActions.display(c));
                    display(<PopupContentModal commandContext={props.commandContext} model={props.model} onDone={(changes) => {
                            dismiss();
                            onEdit(changes);
                        }} onCancel={() => {
                            dismiss();
                        }}/>);
                },
            }),
        ],
    ];
    return (<HoveringToolbar isOpen={() => focused && selected && !!editor.selection && Range.isCollapsed(editor.selection)} showArrow target={<span {...attributes} style={{ paddingRight: 2 }} id={props.model.id} className="popup__anchorText">
          {children}
        </span>} contentLocation={centeredAbove}>
      <FormattingToolbar commandDescs={commands} commandContext={props.commandContext}/>
    </HoveringToolbar>);
};
//# sourceMappingURL=Editor.jsx.map