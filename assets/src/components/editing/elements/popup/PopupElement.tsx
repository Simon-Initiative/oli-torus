import { modalActions } from 'actions/modal';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { EditorProps } from 'components/editing/elements/interfaces';
import { PopupContentModal } from 'components/editing/elements/popup/PopupContentModal';
import { InlineChromiumBugfix, onEditModel } from 'components/editing/elements/utils';
import { Toolbar } from 'components/editing/toolbar/Toolbar';
import { HoverContainer } from 'components/editing/toolbar/HoverContainer';
import * as ContentModel from 'data/content/model/elements/types';
import React from 'react';
import { CommandButton } from 'components/editing/toolbar/buttons/CommandButton';
import { useCollapsedSelection } from 'data/content/utils';

interface Props extends EditorProps<ContentModel.Popup> {}
export const PopupEditor = (props: Props) => {
  const collapsedSelection = useCollapsedSelection();
  const isOpen = React.useCallback(() => collapsedSelection, [collapsedSelection]);

  const onEdit = (changes: Partial<ContentModel.Popup>) => onEditModel(props.model)(changes);

  return (
    <HoverContainer
      position="bottom"
      align="start"
      isOpen={isOpen}
      content={
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
      }
    >
      <span {...props.attributes} className="popup__anchorText">
        <InlineChromiumBugfix />
        {props.children}
        <InlineChromiumBugfix />
      </span>
    </HoverContainer>
  );
};
