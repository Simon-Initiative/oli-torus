import React from 'react';
import * as ContentModel from '../../../../data/content/model/elements/types';
import { EditorProps } from 'components/editing/elements/interfaces';
import { CommandButton } from '../../../common/CommandButton';
import { HoverContainer } from '../../toolbar/HoverContainer';
import { useSelected } from 'slate-react';
import { CommandButtonSettingsModal } from './CommandButtonSettingsModal';
import { InlineChromiumBugfix, useEditModelCallback } from '../utils';
import { CommandContext } from '../commands/interfaces';
import { Toolbar } from '../../toolbar/Toolbar';
import { DescriptiveButton } from '../../toolbar/buttons/DescriptiveButton';
import { createButtonCommandDesc } from '../commands/commandFactories';
import { modalActions } from '../../../../actions/modal';

interface Props extends EditorProps<ContentModel.CommandButton> {}

export const CommandButtonEditor: React.FC<Props> = ({
  model,
  attributes,
  children,
  commandContext,
}) => {
  const selected = useSelected();
  const onEdit = useEditModelCallback(model);

  return (
    <CommandButton commandButton={model} editorAttributes={attributes} disableCommand={true}>
      <HoverContainer
        isOpen={selected}
        position="bottom"
        align="start"
        content={<Settings model={model} onEdit={onEdit} commandContext={commandContext} />}
      ></HoverContainer>
      <InlineChromiumBugfix />
      {children}
      <InlineChromiumBugfix />
    </CommandButton>
  );
};

interface SettingsProps {
  commandContext: CommandContext;
  model: ContentModel.CommandButton;
  onEdit: (attrs: Partial<ContentModel.CommandButton>) => void;
}
const Settings = (props: SettingsProps) => {
  return (
    <Toolbar context={props.commandContext}>
      <Toolbar.Group>
        <SettingsButton
          model={props.model}
          onEdit={props.onEdit}
          commandContext={props.commandContext}
        />
      </Toolbar.Group>
    </Toolbar>
  );
};

interface SettingsButtonProps {
  commandContext: CommandContext;
  model: ContentModel.CommandButton;
  onEdit: (attrs: Partial<ContentModel.CommandButton>) => void;
}
const SettingsButton = (props: SettingsButtonProps) => (
  <DescriptiveButton
    description={createButtonCommandDesc({
      icon: <i className="fa-solid fa-gear"></i>,
      description: 'Settings',
      execute: (_context, _editor, _params) =>
        window.oliDispatch(
          modalActions.display(
            <CommandButtonSettingsModal
              model={props.model}
              commandContext={props.commandContext}
              onEdit={props.onEdit}
              onDone={() => window.oliDispatch(modalActions.dismiss())}
              onCancel={() => window.oliDispatch(modalActions.dismiss())}
            />,
          ),
        ),
    })}
  />
);
