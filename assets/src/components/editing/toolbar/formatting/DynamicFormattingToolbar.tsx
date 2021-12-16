import { DropdownButton, SimpleButton } from 'components/editing/toolbar/common';
import { ButtonContext, ToolbarButtonDesc } from 'components/editing/toolbar/interfaces';
import React from 'react';
import { useSlate } from 'slate-react';

export type HoveringToolbarProps = {
  commandContext: ButtonContext;
  commandDescs: ToolbarButtonDesc[][];
};
export const DynamicFormattingToolbar = (props: HoveringToolbarProps) => {
  const editor = useSlate();

  const buttonGroups = props.commandDescs.reduce((acc: JSX.Element[][], cmdDescs) => {
    const buttons = cmdDescs.reduce((acc: JSX.Element[], cmdDesc) => {
      if (!cmdDesc.command.precondition(editor)) {
        return acc;
      }
      const description = cmdDesc.description(editor);

      const shared = {
        style: 'btn-dark',
        active: cmdDesc.active && cmdDesc.active(editor),
        key: description,
        description,
        icon: cmdDesc.icon(editor),
        command: cmdDesc.command,
        context: props.commandContext,
        tooltip: description,
        position: 'top' as any,
      };

      return acc.concat([
        cmdDesc.command.obtainParameters === undefined ? (
          <SimpleButton {...shared} />
        ) : (
          <DropdownButton {...shared} />
        ),
      ]);
    }, []);

    return buttons.length > 0 ? acc.concat([buttons]) : acc;
  }, []);

  return (
    <React.Fragment>
      {buttonGroups.reduce((acc, buttons, i, buttonGroups) => {
        if (i === buttonGroups.length - 1) {
          return acc.concat(buttons);
        }
        return acc
          .concat(buttons)
          .concat([<div key={'spacer-' + i} className="button-separator"></div>]);
      }, [])}
    </React.Fragment>
  );
};
