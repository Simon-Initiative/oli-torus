import { modalActions } from 'actions/modal';
import { createButtonCommandDesc } from 'components/editing/commands/commands';
import { EditorProps } from 'components/editing/models/interfaces';
import { PopupContentModal } from 'components/editing/models/popup/PopupContentModal';
import { updateModel } from 'components/editing/models/utils';
import { FormattingToolbar } from 'components/editing/toolbars/formatting/Toolbar';
import { HoveringToolbar } from 'components/editing/toolbars/HoveringToolbar';
import * as ContentModel from 'data/content/model';
import { centeredAbove } from 'data/content/utils';
import React, { useState } from 'react';
import { Range } from 'slate';
import { useFocused, useSelected } from 'slate-react';
import './Editor.scss';

interface Props extends EditorProps<ContentModel.Popup> {}
export const PopupEditor = (props: Props) => {
  const focused = useFocused();
  const selected = useSelected();
  const [isPopoverOpen, setIsPopoverOpen] = useState(false);

  const { attributes, children, editor, model } = props;

  const onEdit = (changes: Partial<ContentModel.Popup>) => {
    updateModel<ContentModel.Popup>(editor, model, changes);
    // setIsPopoverOpen(false);
  };

  const commands = [
    [
      createButtonCommandDesc({
        icon: 'edit',
        description: 'Edit content',
        execute: (_context, _editor, _params) => {
          const dismiss = () => (window as any).oliDispatch(modalActions.dismiss());
          const display = (c: any) => (window as any).oliDispatch(modalActions.display(c));

          display(
            <PopupContentModal
              commandContext={props.commandContext}
              model={props.model}
              onDone={(changes) => {
                dismiss();
                onEdit(changes);
              }}
              onCancel={() => {
                dismiss();
              }}
            />,
          );
        },
      }),
    ],
  ];

  return (
    <HoveringToolbar
      isOpen={() =>
        focused && selected && !!editor.selection && Range.isCollapsed(editor.selection)
      }
      showArrow
      target={
        <span
          {...attributes}
          id={props.model.id}
          className="popup-link"
          onClick={() => {
            setIsPopoverOpen(true);
          }}
        >
          {children}
        </span>
      }
      contentLocation={centeredAbove}
    >
      <FormattingToolbar commandDescs={commands} commandContext={props.commandContext} />
    </HoveringToolbar>
  );
};
