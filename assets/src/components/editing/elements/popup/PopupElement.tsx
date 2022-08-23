import { modalActions } from 'actions/modal';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { EditorProps } from 'components/editing/elements/interfaces';
import { PopupContentModal } from 'components/editing/elements/popup/PopupContentModal';
import { InlineChromiumBugfix, updateModel } from 'components/editing/elements/utils';
import { Toolbar } from 'components/editing/toolbar/Toolbar';
import { HoverContainer } from 'components/editing/toolbar/HoverContainer';
import * as ContentModel from 'data/content/model/elements/types';
import React from 'react';
import { CommandButton } from 'components/editing/toolbar/buttons/CommandButton';
import { useCollapsedSelection } from 'data/content/utils';
import { useSlate } from 'slate-react';

const dismiss = () => window.oliDispatch(modalActions.dismiss());
const display = (c: any) => window.oliDispatch(modalActions.display(c));

import './PopupElement.scss';

interface Props extends EditorProps<ContentModel.Popup> {}
export const PopupEditor = (props: Props) => {
  const editor = useSlate();

  const collapsedSelection = useCollapsedSelection();
  const isOpen = React.useCallback(() => collapsedSelection, [collapsedSelection]);

  const onEdit = React.useCallback(
    (changes: Partial<ContentModel.Popup>) => updateModel(editor, props.model, changes),
    [props.model, editor],
  );

  const onDone = React.useCallback(
    (changes: Partial<ContentModel.Popup>) => {
      dismiss();
      onEdit(changes);
    },
    [onEdit],
  );

  const onCancel = React.useCallback(() => {
    dismiss();
  }, []);

  const execute = React.useCallback(
    (_context, _editor, _params) => {
      display(
        <PopupContentModal
          commandContext={props.commandContext}
          model={props.model}
          onDone={onDone}
          onCancel={onCancel}
        />,
      );
    },
    [props.commandContext, props.model, onDone, onCancel],
  );

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
                execute,
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
