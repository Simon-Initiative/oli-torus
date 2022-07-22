import React from 'react';

import { modalActions } from 'actions/modal';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { CommandContext } from 'components/editing/elements/commands/interfaces';
import { DescriptiveButton } from 'components/editing/toolbar/buttons/DescriptiveButton';
import { Toolbar } from 'components/editing/toolbar/Toolbar';

import * as ContentModel from 'data/content/model/elements/types';
import { VideoModal } from './VideoModal';

interface SettingsProps {
  commandContext: CommandContext;
  model: ContentModel.Video;
  onEdit: (attrs: Partial<ContentModel.Video>) => void;
}
export const VideoSettings = (props: SettingsProps) => {
  return (
    <Toolbar context={props.commandContext} orientation="horizontal">
      <Toolbar.Group>
        <SettingsButton
          projectSlug={props.commandContext.projectSlug}
          model={props.model}
          onEdit={props.onEdit}
        />
      </Toolbar.Group>
    </Toolbar>
  );
};

interface SettingsButtonProps {
  model: ContentModel.Video;
  projectSlug: string;
  onEdit: (attrs: Partial<ContentModel.Video>) => void;
}

const SettingsButton = (props: SettingsButtonProps) => (
  <DescriptiveButton
    description={createButtonCommandDesc({
      icon: 'smart_display',
      description: 'Settings',
      execute: (_context, _editor, _params) =>
        window.oliDispatch(
          modalActions.display(
            <VideoModal
              projectSlug={props.projectSlug}
              model={props.model}
              onDone={({ poster, src, width, height }: Partial<ContentModel.Video>) => {
                window.oliDispatch(modalActions.dismiss());
                props.onEdit({ poster, src, width, height });
              }}
              onCancel={() => window.oliDispatch(modalActions.dismiss())}
            />,
          ),
        ),
    })}
  />
);
