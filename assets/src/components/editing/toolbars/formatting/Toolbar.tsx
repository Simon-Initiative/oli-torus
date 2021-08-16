import React from 'react';
import { useSlate } from 'slate-react';
import { CommandContext } from '../../models/interfaces';
import { CommandDesc } from '../../commands/interfaces';
import { ToolbarButton, DropdownToolbarButton } from 'components/editing/toolbars/common';

export type HoveringToolbarProps = {
  commandContext: CommandContext;
  commandDescs: CommandDesc[][];
};
export const FormattingToolbar = (props: HoveringToolbarProps) => {
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
      };

      return acc.concat([
        cmdDesc.command.obtainParameters === undefined ? (
          <ToolbarButton {...shared} />
        ) : (
          <DropdownToolbarButton {...shared} position="bottom" />
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
