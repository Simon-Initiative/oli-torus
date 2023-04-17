import React from 'react';
import { useDispatch } from 'react-redux';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { CommandContext } from 'components/editing/elements/commands/interfaces';
import { Toolbar } from 'components/editing/toolbar/Toolbar';
import { DescriptiveButton } from 'components/editing/toolbar/buttons/DescriptiveButton';
import { modalActions } from 'actions/modal';
import * as ContentModel from 'data/content/model/elements/types';
import { VideoModal } from './VideoModal';

interface SettingsProps {
  commandContext: CommandContext;
  model: ContentModel.Video;
  onEdit: (attrs: Partial<ContentModel.Video>) => void;
}
export const VideoSettings = (props: SettingsProps) => {
  return (
    <div className="video-settings">
      <Toolbar context={props.commandContext}>
        <Toolbar.Group>
          <SettingsButton
            projectSlug={props.commandContext.projectSlug}
            model={props.model}
            onEdit={props.onEdit}
          />
        </Toolbar.Group>
      </Toolbar>
    </div>
  );
};

interface SettingsButtonProps {
  model: ContentModel.Video;
  projectSlug: string;
  onEdit: (attrs: Partial<ContentModel.Video>) => void;
}

const SettingsButton = (props: SettingsButtonProps) => {
  const dispatch = useDispatch();
  return (
    <DescriptiveButton
      description={createButtonCommandDesc({
        icon: <i className="fa-solid fa-video"></i>,
        description: 'Settings',
        execute: (_context, _editor, _params) =>
          dispatch(
            modalActions.display(
              <VideoModal
                projectSlug={props.projectSlug}
                model={props.model}
                onDone={(video: Partial<ContentModel.Video>) => {
                  dispatch(modalActions.dismiss());
                  props.onEdit(video);
                }}
                onCancel={() => window.oliDispatch(modalActions.dismiss())}
              />,
            ),
          ),
      })}
    />
  );
};
