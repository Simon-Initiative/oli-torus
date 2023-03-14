import { modalActions } from 'actions/modal';
import { createButtonCommandDesc } from 'components/editing/elements/commands/commandFactories';
import { CommandContext } from 'components/editing/elements/commands/interfaces';
import { selectImage } from 'components/editing/elements/image/imageActions';
import { ImageModal } from 'components/editing/elements/image/ImageModal';
import { CommandButton } from 'components/editing/toolbar/buttons/CommandButton';
import { DescriptiveButton } from 'components/editing/toolbar/buttons/DescriptiveButton';
import { Toolbar } from 'components/editing/toolbar/Toolbar';
import React from 'react';
import { Maybe } from 'tsmonad';
import * as ContentModel from 'data/content/model/elements/types';

interface SettingsProps {
  commandContext: CommandContext;
  model: ContentModel.ImageBlock | ContentModel.ImageInline;
  onEdit: (attrs: Partial<ContentModel.ImageBlock | ContentModel.ImageInline>) => void;
}
export const ImageSettings = (props: SettingsProps) => {
  return (
    <Toolbar context={props.commandContext}>
      <Toolbar.Group>
        <SelectImageButton model={props.model} onEdit={props.onEdit} />
      </Toolbar.Group>
      <Toolbar.Group>
        <SettingsButton model={props.model} onEdit={props.onEdit} />
      </Toolbar.Group>
    </Toolbar>
  );
};
interface SelectImageProps {
  model: ContentModel.ImageBlock | ContentModel.ImageInline;
  onEdit: (attrs: Partial<ContentModel.ImageBlock | ContentModel.ImageInline>) => void;
}
const SelectImageButton = (props: SelectImageProps) => (
  <CommandButton
    description={createButtonCommandDesc({
      icon: <i className="fa-solid fa-image"></i>,
      description: 'Select Image',
      execute: (context, _editor) =>
        selectImage(context.projectSlug, props.model.src).then((selection) =>
          Maybe.maybe(selection).map((src) => props.onEdit({ src })),
        ),
    })}
  />
);

interface SettingsButtonProps {
  model: ContentModel.ImageBlock | ContentModel.ImageInline;
  onEdit: (attrs: Partial<ContentModel.ImageBlock | ContentModel.ImageInline>) => void;
}
const SettingsButton = (props: SettingsButtonProps) => (
  <DescriptiveButton
    description={createButtonCommandDesc({
      icon: <i className="fa-solid fa-image"></i>,
      description: 'Settings',
      execute: (_context, _editor, _params) =>
        window.oliDispatch(
          modalActions.display(
            <ImageModal
              model={props.model}
              onDone={({ alt, width }: Partial<ContentModel.ImageBlock>) => {
                window.oliDispatch(modalActions.dismiss());
                props.onEdit({ alt, width });
              }}
              onCancel={() => window.oliDispatch(modalActions.dismiss())}
            />,
          ),
        ),
    })}
  />
);
