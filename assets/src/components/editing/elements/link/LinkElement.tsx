import { EditorProps } from 'components/editing/elements/interfaces';
import { InlineChromiumBugfix, useEditModelCallback } from 'components/editing/elements/utils';
import { HoverContainer } from 'components/editing/toolbar/HoverContainer';
import { Toolbar } from 'components/editing/toolbar/Toolbar';
import * as ContentModel from 'data/content/model/elements/types';
import React from 'react';
import { useSelected } from 'slate-react';

import { CommandContext } from 'components/editing/elements/commands/interfaces';
import { DescriptiveButton } from 'components/editing/toolbar/buttons/DescriptiveButton';
import { LinkModal } from './LinkModal';
import { modalActions } from 'actions/modal';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';

import './LinkElement.scss';

export interface Props extends EditorProps<ContentModel.Hyperlink> {}
export const LinkEditor = (props: Props) => {
  const selected = useSelected();
  const isOpen = React.useCallback(() => selected, [selected]);
  const onEdit = useEditModelCallback(props.model);

  return (
    <a
      {...props.attributes}
      id={props.model.id}
      href="#"
      className="inline-link"
      style={selected ? { boxShadow: '0 0 0 3px #ddd' } : {}}
    >
      <HoverContainer
        isOpen={isOpen}
        position="bottom"
        align="start"
        content={
          <Settings model={props.model} onEdit={onEdit} commandContext={props.commandContext} />
        }
      ></HoverContainer>
      <InlineChromiumBugfix />
      {props.children}
      <InlineChromiumBugfix />
    </a>
  );
};

interface SettingsProps {
  commandContext: CommandContext;
  model: ContentModel.Hyperlink;
  onEdit: (attrs: Partial<ContentModel.Hyperlink>) => void;
}
const Settings = (props: SettingsProps) => {
  return (
    <Toolbar context={props.commandContext} orientation="horizontal">
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
  model: ContentModel.Hyperlink;
  onEdit: (attrs: Partial<ContentModel.Hyperlink>) => void;
}
const SettingsButton = (props: SettingsButtonProps) => (
  <DescriptiveButton
    description={createButtonCommandDesc({
      icon: '',
      description: 'Settings',
      execute: (_context, _editor, _params) =>
        window.oliDispatch(
          modalActions.display(
            <LinkModal
              model={props.model}
              commandContext={props.commandContext}
              onDone={({ href }: Partial<ContentModel.Hyperlink>) => {
                window.oliDispatch(modalActions.dismiss());
                props.onEdit({ href });
              }}
              onCancel={() => window.oliDispatch(modalActions.dismiss())}
            />,
          ),
        ),
    })}
  />
);
