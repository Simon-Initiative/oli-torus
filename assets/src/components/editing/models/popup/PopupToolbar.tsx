import { modalActions } from 'actions/modal';
import { createButtonCommandDesc } from 'components/editing/commands/commands';
import { CommandContext } from 'components/editing/commands/interfaces';
import { PopupContentModal } from 'components/editing/models/popup/PopupContentModal';
import { FormattingToolbar } from 'components/editing/toolbars/formatting/Toolbar';
import * as ContentModel from 'data/content/model';
import React from 'react';

interface Props {
  model: ContentModel.Popup;
  onEdit: (popup: ContentModel.Popup) => void;
  commandContext: CommandContext;
}
export const PopupToolbar = (props: Props) => {
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
              onDone={(newModel) => {
                dismiss();
                props.onEdit(newModel);
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
      isOpen={() => focused && selected}
      showArrow
      target={
        <div>
          {ReactEditor.isFocused(editor) && selected && imageRef.current && (
            <Resizer
              element={imageRef.current}
              onResize={({ width, height }) => onEdit(update({ width, height }))}
            />
          )}
          <img
            width={model.width}
            height={model.height}
            ref={imageRef}
            onClick={() => {
              ReactEditor.focus(editor);
              Transforms.select(editor, ReactEditor.findPath(editor, model));
            }}
            className={displayModelToClassName(model.display)}
            src={model.src}
          />
        </div>
      }
      contentLocation={centeredAbove}
    >
      <FormattingToolbar commandDescs={commands} commandContext={props.commandContext} />
    </HoveringToolbar>
    // <div className="hovering-toolbar">
    //   <div className="btn-group btn-group-sm" role="group">
    //     <FormattingToolbar commandDescs={commands} commandContext={props.commandContext} />
    //   </div>
    // </div>
  );
};
