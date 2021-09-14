import React from 'react';
import * as ContentModel from 'data/content/model';
import { EditorProps } from 'components/editing/models/interfaces';
import { useFocused, useSelected } from 'slate-react';
import { initCommands } from 'components/editing/models/inputref/commands';
import { HoveringToolbar } from 'components/editing/toolbars/HoveringToolbar';
import { FormattingToolbar } from 'components/editing/toolbars/formatting/Toolbar';
import { centeredAbove } from 'data/content/utils';
import { friendlyType } from 'components/activities/multi_input/utils';

export interface InputRefProps extends EditorProps<ContentModel.InputRef> {}
export const InputRefEditor = (props: InputRefProps) => {
  const { inputRefContext } = props.commandContext;

  const focused = useFocused();
  const selected = useSelected();

  const input = inputRefContext?.inputs.get(props.model.id);
  React.useEffect(() => {
    if (focused && selected && inputRefContext?.selectedInputRef?.id !== props.model.id) {
      inputRefContext?.setSelectedInputRef(props.model);
    }
  }, [selected, focused]);

  if (!inputRefContext || !input) {
    return props.children;
  }

  const commands = initCommands(input, inputRefContext.onEditInput);

  const borderStyle =
    focused && selected
      ? { border: 'solid 3px lightblue', borderRadius: '0.25rem' }
      : { border: 'solid 3px transparent' };

  const backgroundStyle =
    inputRefContext.selectedInputRef?.id === props.model.id ? { backgroundColor: 'lightblue' } : {};

  const withToolbar = (target: React.ReactElement) => (
    <HoveringToolbar
      isOpen={() => focused && selected}
      showArrow
      target={target}
      contentLocation={centeredAbove}
    >
      <FormattingToolbar commandDescs={commands} commandContext={props.commandContext} />
    </HoveringToolbar>
  );

  return (
    <span
      {...props.attributes}
      contentEditable={false}
      style={Object.assign(borderStyle, { display: 'inline-block' })}
    >
      {withToolbar(
        <span
          style={Object.assign(backgroundStyle, {
            width: '160px',
            display: 'inline-block',
            userSelect: 'none',
          } as React.CSSProperties)}
          className="form-control"
        >
          {friendlyType(input.inputType)}
        </span>,
      )}
      {props.children}
    </span>
  );
};
