import { modalActions } from 'actions/modal';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commands';
import { EditorProps } from 'components/editing/elements/interfaces';
import { PopupContentModal } from 'components/editing/elements/popup/PopupContentModal';
import { InlineChromiumBugfix, updateModel } from 'components/editing/elements/utils';
import { Toolbar } from 'components/editing/toolbar/Toolbar';
import { HoverContainer } from 'components/editing/toolbar/HoverContainer';
import * as ContentModel from 'data/content/model/elements/types';
import { alignedLeftBelow } from 'data/content/utils';
import React from 'react';
import { Range } from 'slate';
import { useFocused, useSelected, useSlate } from 'slate-react';
import './Editor.scss';
import { CommandButton } from 'components/editing/toolbar/buttons/CommandButton';

interface Props extends EditorProps<ContentModel.Popup> {}
export const PopupEditor = (props: Props) => {
  const focused = useFocused();
  const selected = useSelected();
  const editor = useSlate();
  const ref = React.useRef<HTMLSpanElement | null>(null);

  const onEdit = (changes: Partial<ContentModel.Popup>) =>
    updateModel<ContentModel.Popup>(editor, props.model, changes);

  return (
    <span {...props.attributes} ref={ref}>
      <HoverContainer
        contentLocation={alignedLeftBelow}
        parentNode={ref.current || undefined}
        isOpen={() =>
          focused && selected && !!editor.selection && Range.isCollapsed(editor.selection)
        }
        target={
          <span className="popup__anchorText">
            <InlineChromiumBugfix />
            {props.children}
            <InlineChromiumBugfix />
          </span>
        }
      >
        <Toolbar context={props.commandContext}>
          <Toolbar.Group>
            <CommandButton
              description={createButtonCommandDesc({
                icon: 'edit',
                description: 'Edit content',
                execute: (_context, _editor, _params) => {
                  const dismiss = () => window.oliDispatch(modalActions.dismiss());
                  const display = (c: any) => window.oliDispatch(modalActions.display(c));

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
              })}
            />
          </Toolbar.Group>
        </Toolbar>
      </HoverContainer>
    </span>
  );
};
