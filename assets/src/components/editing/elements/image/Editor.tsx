import React from 'react';
import { onEditModel } from 'components/editing/elements/utils';
import * as ContentModel from 'data/content/model/elements/types';
import { EditorProps } from 'components/editing/elements/interfaces';
import { HoverContainer } from 'components/editing/toolbar/HoverContainer';
import { initCommands } from './commands';
import { Resizable } from 'components/misc/resizable/Resizable';
import { Toolbar } from 'components/editing/toolbar/Toolbar';
import { Placeholder } from 'components/editing/elements/editors/Placeholder';
import { CommandButton } from 'components/editing/toolbar/buttons/CommandButton';
import { CaptionEditor } from 'components/editing/elements/settings/CaptionEditor';
import { useElementSelected } from 'data/content/utils';

interface Props extends EditorProps<ContentModel.Image> {}
export const ImageEditor = (props: Props) => {
  const selected = useElementSelected();
  const onEdit = onEditModel(props.model);

  if (props.model.src === undefined)
    return <Placeholder attributes={props.attributes}>{props.children}</Placeholder>;

  return (
    <div {...props.attributes} contentEditable={false}>
      {props.children}
      <HoverContainer
        style={{ margin: '0 auto', width: 'fit-content', display: 'block' }}
        isOpen={selected}
        align="start"
        position="top"
        content={
          <Toolbar context={props.commandContext}>
            <Toolbar.Group>
              {initCommands(props.model, onEdit).map((command, i) => (
                <CommandButton description={command} key={i} />
              ))}
            </Toolbar.Group>
          </Toolbar>
        }
      >
        <div>
          <Resizable show={selected} onResize={({ width, height }) => onEdit({ width, height })}>
            <img width={props.model.width} height={props.model.height} src={props.model.src} />
          </Resizable>
        </div>
      </HoverContainer>

      <CaptionEditor onEdit={(caption: string) => onEdit({ caption })} model={props.model} />
    </div>
  );
};
