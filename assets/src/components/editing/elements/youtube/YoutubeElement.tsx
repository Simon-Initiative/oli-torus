import React from 'react';
import { useSelected, useFocused } from 'slate-react';
import { useEditModelCallback } from 'components/editing/elements/utils';
import * as ContentModel from 'data/content/model/elements/types';
import { EditorProps } from 'components/editing/elements/interfaces';
import { CaptionEditor } from 'components/editing/elements/common/settings/CaptionEditor';
import { CommandContext } from 'components/editing/elements/commands/interfaces';
import { Transforms } from 'slate';
import { getQueryVariableFromString } from 'utils/params';
import { Model } from 'data/content/model/elements/factories';
import { HoverContainer } from 'components/editing/toolbar/HoverContainer';
import { Toolbar } from 'components/editing/toolbar/Toolbar';
import { DescriptiveButton } from 'components/editing/toolbar/buttons/DescriptiveButton';
import { YouTubeModal } from './YoutubeModal';
import { modalActions } from 'actions/modal';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { CommandButton } from 'components/editing/toolbar/buttons/CommandButton';

const toLink = (src = '') => 'https://www.youtube.com/embed/' + (src === '' ? CUTE_OTTERS : src);

export const ytCmdDesc = createButtonCommandDesc({
  icon: 'play_circle_filled',
  description: 'YouTube',
  execute: (_context, editor, src: string) => {
    const at = editor.selection;
    if (!at) return;

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

  const parameters = 'disablekb=1&modestbranding=1&showinfo=0&rel=0&controls=0';
  const fullSrc =
    'https://www.youtube.com/embed/' + (props.model.src || CUTE_OTTERS) + '?' + parameters;

  const onEdit = useEditModelCallback(props.model);

  const borderStyle =
    focused && selected
      ? { border: 'solid 3px lightblue', borderRadius: 0 }
      : { border: 'solid 3px transparent' };

  return (
    <div {...props.attributes} className="youtube-editor" contentEditable={false}>
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
        <div className="embed-responsive embed-responsive-16by9 img-thumbnail" style={borderStyle}>
          <iframe
            width={props.model.width ?? '100%'}
            className="embed-responsive-item"
            src={fullSrc}
            allowFullScreen
            aria-label="Youtube video"
            frameBorder={0}
          />
        </div>
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
    <Toolbar context={props.commandContext} orientation="horizontal">
      <Toolbar.Group>
        <CommandButton
          description={createButtonCommandDesc({
            icon: 'open_in_new',
            description: 'Open Video',
            execute: () => window.open(toLink(props.model.src), '_blank'),
          })}
        />
        <CommandButton
          description={createButtonCommandDesc({
            icon: 'content_copy',
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
      icon: '',
      description: 'Settings',
      execute: (_context, _editor, _params) =>
        window.oliDispatch(
          modalActions.display(
            <YouTubeModal
              model={props.model}
              onDone={({ alt, width, src }: Partial<ContentModel.YouTube>) => {
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
