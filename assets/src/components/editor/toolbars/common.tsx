import React from 'react';
import { useSlate } from 'slate-react';
import { Command, CommandContext } from '../commands/interfaces';
import Popover from 'react-tiny-popover';

export function hideToolbar(el: HTMLElement) {
  el.style.display = 'none';
}

export function isToolbarHidden(el: HTMLElement) {
  return el.style.display === 'none';
}

export function showToolbar(el: HTMLElement) {
  el.style.display = 'block';
}

interface ToolbarButtonProps {
  icon: string;
  command: Command;
  context: CommandContext;
  description?: string;
  tooltip?: string;
  style?: string;
  active?: boolean;
  disabled?: boolean;
}
export const ToolbarButton = ({ icon, command, style, context, tooltip, active,
  description, disabled }: ToolbarButtonProps) => {
  const editor = useSlate();

  return (
    <button
      data-toggle="tooltip"
      data-placement="top"
      title={tooltip}
      disabled={disabled || false}
      className={`btn btn-sm btn-light ${style} ${active && 'active'}`}
      onMouseDown={e => e.preventDefault()}
      onMouseUp={(event) => {
        event.preventDefault();
        command.execute(context, editor);
      }}
    >
      {icon
        ? <span className="material-icons" data-icon={description}>{icon}</span>
        : <span className="toolbar-button-text">{description}</span>}
    </button>
  );
};

export const DropdownToolbarButton = ({ icon, command, style, context, tooltip }: any) => {

  const editor = useSlate();
  const [isPopoverOpen, setIsPopoverOpen] = React.useState(false);

  const onDone = (params: any) => {
    setIsPopoverOpen(false);
    command.execute(context, editor, params);
  };
  const onCancel = () => setIsPopoverOpen(false);

  return (
    <Popover
      onClickOutside={() => setIsPopoverOpen(false)}
      isOpen={isPopoverOpen}
      padding={5}
      position={['bottom', 'top', 'left', 'right']}
      content={() => (command as any).obtainParameters(editor, onDone, onCancel)}>
      {ref => <button
        ref={ref}
        data-toggle="tooltip" data-placement="top" title={tooltip}
        className={`btn btn-sm btn-light ${style}`}
        onClick={() => setIsPopoverOpen(!isPopoverOpen)}
        type="button">
        <i className="material-icons">{icon}</i>
      </button>}
    </Popover>
  );
};
