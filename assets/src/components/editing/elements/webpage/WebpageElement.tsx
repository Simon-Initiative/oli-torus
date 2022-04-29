import React from 'react';
import { useSelected, useFocused } from 'slate-react';
import { onEditModel } from 'components/editing/elements/utils';
import * as ContentModel from 'data/content/model/elements/types';
import { EditorProps } from 'components/editing/elements/interfaces';
import { CaptionEditor } from 'components/editing/elements/common/settings/CaptionEditor';
import { CommandContext } from 'components/editing/elements/commands/interfaces';
import { Toolbar } from 'components/editing/toolbar/Toolbar';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { HoverContainer } from 'components/editing/toolbar/HoverContainer';
import { CommandButton } from 'components/editing/toolbar/buttons/CommandButton';
import { DescriptiveButton } from 'components/editing/toolbar/buttons/DescriptiveButton';
import { WebpageModal } from 'components/editing/elements/webpage/WebpageModal';
import { modalActions } from 'actions/modal';

export interface Props extends EditorProps<ContentModel.Webpage> {}
export const WebpageEditor = (props: Props) => {
  const focused = useFocused();
  const selected = useSelected();

  const onEdit = onEditModel(props.model);

  const borderStyle =
    focused && selected
      ? { border: 'solid 3px lightblue', borderRadius: 0 }
      : { border: 'solid 3px transparent' };

  return (
    <div {...props.attributes} className="webpage-editor" contentEditable={false}>
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
        <div style={borderStyle} className="embed-responsive embed-responsive-16by9 img-thumbnail">
          <iframe
            width={props.model.width ?? '100%'}
            className="embed-responsive-item"
            src={props.model.src}
            allowFullScreen
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
  model: ContentModel.Webpage;
  onEdit: (attrs: Partial<ContentModel.Webpage>) => void;
}
const Settings = (props: SettingsProps) => {
  return (
    <Toolbar context={props.commandContext}>
      <Toolbar.Group>
        <CommandButton
          description={createButtonCommandDesc({
            icon: 'open_in_new',
            description: 'Open Video',
            execute: () => window.open(props.model.src, '_blank'),
          })}
        />
        <CommandButton
          description={createButtonCommandDesc({
            icon: 'content_copy',
            description: 'Copy Video Link',
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
      icon: '',
      description: 'Settings',
      execute: (_context, _editor, _params) =>
        window.oliDispatch(
          modalActions.display(
            <WebpageModal
              model={props.model}
              onDone={({ alt, width, src }: Partial<ContentModel.Webpage>) => {
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
