import React from 'react';
import * as ContentModel from 'data/content/model/elements/types';
import { CommandContext } from 'components/editing/elements/commands/interfaces';
import { Toolbar } from 'components/editing/toolbar/Toolbar';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { CommandButton } from 'components/editing/toolbar/buttons/CommandButton';
import { DescriptiveButton } from 'components/editing/toolbar/buttons/DescriptiveButton';
import { WebpageModal } from 'components/editing/elements/webpage/WebpageModal';
import { modalActions } from 'actions/modal';

interface SettingsProps {
  commandContext: CommandContext;
  model: ContentModel.Webpage;
  onEdit: (attrs: Partial<ContentModel.Webpage>) => void;
}
export const WebpageSettings = (props: SettingsProps) => {
  return (
    <Toolbar context={props.commandContext}>
      <Toolbar.Group>
        <CommandButton
          description={createButtonCommandDesc({
            icon: <i className="fa-solid fa-arrow-up-right-from-square"></i>,
            description: 'Open Webpage',
            execute: () => window.open(props.model.src, '_blank'),
          })}
        />
        <CommandButton
          description={createButtonCommandDesc({
            icon: <i className="fa-regular fa-copy"></i>,
            description: 'Copy Webpage Link',
            execute: () => navigator.clipboard.writeText(props.model.src ?? ''),
          })}
        />
      </Toolbar.Group>
      <Toolbar.Group>
        <SettingsButton model={props.model} onEdit={props.onEdit} />
      </Toolbar.Group>
    </Toolbar>
  );
};
interface SettingsButtonProps {
  model: ContentModel.Webpage;
  onEdit: (attrs: Partial<ContentModel.Webpage>) => void;
}
const SettingsButton = (props: SettingsButtonProps) => (
  <DescriptiveButton
    description={createButtonCommandDesc({
      icon: <i className="fa-solid fa-globe"></i>,
      description: 'Settings',
      execute: (_context, _editor, _params) =>
        window.oliDispatch(
          modalActions.display(
            <WebpageModal
              model={props.model}
              onDone={({ alt, width, src }: Partial<ContentModel.Webpage>) => {
                console.log('width', width, alt, src);
                window.oliDispatch(modalActions.dismiss());
                props.onEdit({ alt, width, src });
              }}
              onCancel={() => window.oliDispatch(modalActions.dismiss())}
            />,
          ),
        ),
    })}
  />
);
