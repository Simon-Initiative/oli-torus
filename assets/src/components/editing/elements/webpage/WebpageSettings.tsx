import React from 'react';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { CommandContext } from 'components/editing/elements/commands/interfaces';
import { WebpageModal } from 'components/editing/elements/webpage/WebpageModal';
import { Toolbar } from 'components/editing/toolbar/Toolbar';
import { CommandButton } from 'components/editing/toolbar/buttons/CommandButton';
import { DescriptiveButton } from 'components/editing/toolbar/buttons/DescriptiveButton';
import { modalActions } from 'actions/modal';
import * as ContentModel from 'data/content/model/elements/types';

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
        <SettingsButton
          model={props.model}
          onEdit={props.onEdit}
          projectSlug={props.commandContext.projectSlug}
        />
      </Toolbar.Group>
    </Toolbar>
  );
};
interface SettingsButtonProps {
  model: ContentModel.Webpage;
  onEdit: (attrs: Partial<ContentModel.Webpage>) => void;
  projectSlug: string;
}

const SettingsButton = (props: SettingsButtonProps) => (
  <DescriptiveButton
    description={createButtonCommandDesc({
      icon: <i className="fa-solid fa-globe"></i>,
      category: 'Media',
      description: 'Settings',
      execute: (_context, _editor, _params) =>
        window.oliDispatch(
          modalActions.display(
            <WebpageModal
              projectSlug={props.projectSlug}
              model={props.model}
              onDone={({
                targetId,
                alt,
                width,
                height,
                src,
                srcType,
              }: Partial<ContentModel.Webpage>) => {
                window.oliDispatch(modalActions.dismiss());
                props.onEdit({ targetId, alt, width, src, srcType, height });
              }}
              onCancel={() => window.oliDispatch(modalActions.dismiss())}
            />,
          ),
        ),
    })}
  />
);
