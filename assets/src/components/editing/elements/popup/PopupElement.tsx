import React from 'react';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { EditorProps } from 'components/editing/elements/interfaces';
import { PopupContentEditor } from 'components/editing/elements/popup/PopupContentEditor';
import { InlineChromiumBugfix, updateModel } from 'components/editing/elements/utils';
import { Toolbar } from 'components/editing/toolbar/Toolbar';
import { HoverContainer } from 'components/editing/toolbar/HoverContainer';
import * as ContentModel from 'data/content/model/elements/types';
import { CommandButton } from 'components/editing/toolbar/buttons/CommandButton';
import { useCollapsedSelection } from 'data/content/utils';
import { useSlate } from 'slate-react';
import { useToggle } from '../../../hooks/useToggle';

interface Props extends EditorProps<ContentModel.Popup> {}
export const PopupEditor = (props: Props) => {
  const editor = useSlate();
  const [popupEditorOpen, , openEditor, closeEditor] = useToggle(false);

  const collapsedSelection = useCollapsedSelection();
  const isOpen = React.useCallback(() => collapsedSelection, [collapsedSelection]);

  const onEdit = React.useCallback(
    (changes: Partial<ContentModel.Popup>) => updateModel(editor, props.model, changes),
    [props.model, editor],
  );

  const onDone = React.useCallback(
    (changes: Partial<ContentModel.Popup>) => {
      closeEditor();
      onEdit(changes);
    },
    [closeEditor, onEdit],
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
                icon: <i className="fa-solid fa-window-restore"></i>,
                description: 'Edit Popup Content',
                execute: openEditor,
              })}
            />
          </Toolbar.Group>
        </Toolbar>
      }
    >
      <span>
        <span {...props.attributes} className="popup-anchor">
          <InlineChromiumBugfix />
          {props.children}
          <InlineChromiumBugfix />
        </span>
        {popupEditorOpen && (
          <PopupContentEditor
            commandContext={props.commandContext}
            model={props.model}
            onDone={onDone}
          />
        )}
      </span>
    </HoverContainer>
  );
};
