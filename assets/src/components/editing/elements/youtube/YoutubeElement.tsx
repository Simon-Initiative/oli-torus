import React from 'react';
import { Transforms } from 'slate';
import { useFocused, useSelected } from 'slate-react';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { CommandContext } from 'components/editing/elements/commands/interfaces';
import { CaptionEditor } from 'components/editing/elements/common/settings/CaptionEditor';
import { EditorProps } from 'components/editing/elements/interfaces';
import { useEditModelCallback } from 'components/editing/elements/utils';
import { HoverContainer } from 'components/editing/toolbar/HoverContainer';
import { Toolbar } from 'components/editing/toolbar/Toolbar';
import { CommandButton } from 'components/editing/toolbar/buttons/CommandButton';
import { DescriptiveButton } from 'components/editing/toolbar/buttons/DescriptiveButton';
import { YoutubePlayer } from 'components/youtube_player/YoutubePlayer';
import { modalActions } from 'actions/modal';
import { Model } from 'data/content/model/elements/factories';
import * as ContentModel from 'data/content/model/elements/types';
import { getQueryVariableFromString } from 'utils/params';
import { useCommandTargetable } from '../command_button/useCommandTargetable';
import { VideoCommandEditor } from '../video/VideoCommandEditor';
import { YouTubeModal } from './YoutubeModal';
import { youtubeUrlToId } from './youtubeActions';

const toLink = (src = '') => 'https://www.youtube.com/embed/' + (src === '' ? CUTE_OTTERS : src);

export const ytCmdDesc = createButtonCommandDesc({
  icon: <i className="fa-brands fa-youtube"></i>,
  description: 'Insert YouTube',
  execute: (_context, editor, src: string) => {
    const at = editor.selection;
    if (!at) return;
    src = src || '';

    const hasParams = src.includes('?');

    if (hasParams) {
      const queryString = src.substr(src.indexOf('?') + 1);
      src = getQueryVariableFromString('v', queryString);
    } else if (src.indexOf('/youtu.be/') !== -1) {
      src = src.substr(src.lastIndexOf('/') + 1);
    }

    Transforms.insertNodes(editor, Model.youtube(), { at });
  },
});

export const CUTE_OTTERS = 'zHIIzcWqsP0';

export type YouTubeProps = EditorProps<ContentModel.YouTube>;

export const YouTubeEditor = (props: YouTubeProps) => {
  const focused = useFocused();
  const selected = useSelected();
  const { model } = props;

  useCommandTargetable(
    model.id,
    'YouTube Player',
    model?.src || 'No video file selected',
    VideoCommandEditor,
  );

  const onEdit = useEditModelCallback(props.model);

  const borderStyle =
    focused && selected
      ? { border: 'solid 3px lightblue', borderRadius: 0 }
      : { border: 'solid 3px transparent' };

  return (
    <div
      style={borderStyle}
      {...props.attributes}
      className="youtube-editor"
      contentEditable={false}
    >
      {props.children}

      <HoverContainer
        style={{ margin: '0 auto', display: 'block' }}
        isOpen={selected}
        align="start"
        position="top"
        content={
          <Settings model={props.model} onEdit={onEdit} commandContext={props.commandContext} />
        }
      >
        <YoutubePlayer video={model} authorMode={true} pageAttemptGuid="" />
      </HoverContainer>

      <CaptionEditor
        onEdit={(caption) => onEdit({ caption })}
        model={props.model}
        commandContext={props.commandContext}
      />
    </div>
  );
};

interface SettingsProps {
  commandContext: CommandContext;
  model: ContentModel.YouTube;
  onEdit: (attrs: Partial<ContentModel.YouTube>) => void;
}
const Settings = (props: SettingsProps) => {
  return (
    <Toolbar context={props.commandContext}>
      <Toolbar.Group>
        <CommandButton
          description={createButtonCommandDesc({
            icon: <i className="fa-solid fa-arrow-up-right-from-square"></i>,
            description: 'Open Video',
            execute: () => window.open(toLink(props.model.src), '_blank'),
          })}
        />
        <CommandButton
          description={createButtonCommandDesc({
            icon: <i className="fa-regular fa-copy"></i>,
            description: 'Copy Video Link',
            execute: () => navigator.clipboard.writeText(toLink(props.model.src)),
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
  model: ContentModel.YouTube;
  onEdit: (attrs: Partial<ContentModel.YouTube>) => void;
}
const SettingsButton = (props: SettingsButtonProps) => (
  <DescriptiveButton
    description={createButtonCommandDesc({
      icon: <i className="fa-brands fa-youtube"></i>,
      description: 'Settings',
      execute: (_context, _editor, _params) =>
        window.oliDispatch(
          modalActions.display(
            <YouTubeModal
              model={props.model}
              onDone={({ alt, width, src, startTime, endTime }: Partial<ContentModel.YouTube>) => {
                window.oliDispatch(modalActions.dismiss());
                props.onEdit({ alt, width, src: youtubeUrlToId(src) || '', startTime, endTime });
              }}
              onCancel={() => window.oliDispatch(modalActions.dismiss())}
            />,
          ),
        ),
    })}
  />
);
