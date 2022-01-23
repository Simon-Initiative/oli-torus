import { modalActions } from 'actions/modal';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commands';
import { EditorProps } from 'components/editing/elements/interfaces';
import { PopupContentModal } from 'components/editing/elements/popup/PopupContentModal';
import { updateModel } from 'components/editing/elements/utils';
import { Toolbar } from 'components/editing/toolbar/Toolbar';
import { HoverContainer } from 'components/editing/toolbar/HoverContainer';
import * as ContentModel from 'data/content/model/elements/types';
import { centeredAbove } from 'data/content/utils';
import React from 'react';
import { Range } from 'slate';
import { useFocused, useSelected } from 'slate-react';
import './Editor.scss';

interface Props extends EditorProps<ContentModel.Popup> {}
export const PopupEditor = (props: Props) => {
  const focused = useFocused();
  const selected = useSelected();

  const { attributes, children, editor, model } = props;

  const onEdit = (changes: Partial<ContentModel.Popup>) => {
    updateModel<ContentModel.Popup>(editor, model, changes);
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
    <HoverContainer
      isOpen={() =>
        focused && selected && !!editor.selection && Range.isCollapsed(editor.selection)
      }
      showArrow
      target={
        <span
          {...attributes}
          style={{ paddingRight: 2 }}
          id={props.model.id}
          className="popup__anchorText"
        >
          {children}
        </span>
      }
      contentLocation={centeredAbove}
    >
      <Toolbar context={props.commandContext}>{/* {commands} */}</Toolbar>
    </HoverContainer>
  );
};
