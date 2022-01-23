import React, { useCallback } from 'react';
import { useFocused, useSelected, useSlate } from 'slate-react';
import { updateModel } from 'components/editing/elements/utils';
import * as ContentModel from 'data/content/model/elements/types';
import { EditorProps } from 'components/editing/elements/interfaces';
import { HoverContainer } from 'components/editing/toolbar/HoverContainer';
import { initCommands } from './commands';
import { alignedLeftAbove } from 'data/content/utils';
import { Resizable } from 'components/misc/resizable/Resizable';
import { Toolbar } from 'components/editing/toolbar/Toolbar';
import { Placeholder } from 'components/editing/elements/editors/Placeholder';
import { CommandButton } from 'components/editing/toolbar/buttons/CommandButton';
import { CaptionEditor } from 'components/editing/elements/settings/CaptionEditor';

interface Props extends EditorProps<ContentModel.Image> {}
export const ImageEditor = (props: Props) => {
  const focused = useFocused();
  const selected = useSelected();
  const editor = useSlate();

  const commands = initCommands(props.model, (img) => onEdit(img));

  const onEdit = (attrs: Partial<ContentModel.Image>) =>
    updateModel<ContentModel.Image>(editor, props.model, attrs);

  const isSelected = useCallback(() => focused && selected, [focused, selected]);

  if (props.model.src === undefined)
    return <Placeholder attributes={props.attributes}>{props.children}</Placeholder>;

  return (
    <div {...props.attributes} contentEditable={false}>
      {props.children}
      <HoverContainer
        isOpen={isSelected}
        contentLocation={alignedLeftAbove}
        target={
          <Resizable onResize={({ width, height }) => onEdit({ width, height })}>
            <img
              style={{ margin: '0 auto', display: 'block' }}
              width={props.model.width}
              height={props.model.height}
              src={props.model.src}
            />
          </Resizable>
        }
      >
        <Toolbar context={props.commandContext}>
          <Toolbar.Group>
            {commands.map((command, i) => (
              <CommandButton description={command} key={i} />
            ))}
          </Toolbar.Group>
        </Toolbar>
      </HoverContainer>

      <CaptionEditor onEdit={(caption: string) => onEdit({ caption })} model={props.model} />
    </div>
  );
};
