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

const buttonContent = (icon: string, description: string | undefined) =>
  icon
    ? <span className="material-icons">{icon}</span>
    : <span className="toolbar-button-text">{description}</span>;

interface ToolbarButtonProps {
  icon: string;
  command: Command;
  context: CommandContext;
  description?: string;
  tooltip?: string;
  style?: string;
  active?: boolean;
  disabled?: boolean;
  position?: 'left' | 'right' | 'top' | 'bottom';
}

export const ToolbarButton = ({ icon, command, style, context, active,
  description }: ToolbarButtonProps) => {
  const editor = useSlate();

  return (
    <button
      data-toggle="tooltip"
      data-placement="top"
      className={`btn btn-sm btn-light ${style} ${!!active && 'active'}`}
      onMouseDown={e => e.preventDefault()}
      onMouseUp={(event) => {
        event.preventDefault();
        command.execute(context, editor);
      }}>
      {buttonContent(icon, description)}
    </button>
  );
};

export const DropdownToolbarButton = ({ icon, command, style, context, active, description,
  position }: ToolbarButtonProps) => {

  const editor = useSlate();
  const [isPopoverOpen, setIsPopoverOpen] = React.useState(false);

  const onDone = (params: any) => {
    setIsPopoverOpen(false);
    command.execute(context, editor, params);
  };
  const onCancel = () => setIsPopoverOpen(false);

  return (
    <Popover
      onClickOutside={() => {
        if ((command as any).obtainParameters) {
          return;
        }
        setIsPopoverOpen(false);
      }}
      isOpen={isPopoverOpen}
      padding={5}
      position={position || 'right'}
      content={() => (command as any).obtainParameters(context, editor, onDone, onCancel)}
    // contentLocation={{ left: 20, top: 0 }}
    >
      {ref => <button
        ref={ref}
        data-toggle="tooltip"
        data-placement="top"
        className={`btn btn-sm btn-light ${style} ${!!active && 'active'}`}
        onClick={() => setIsPopoverOpen(!isPopoverOpen)}
        type="button">
        {buttonContent(icon, description)}
      </button>}
    </Popover>
  );
};

export const Spacer = () => {
  return <span style={{ minWidth: '5px', maxWidth: '5px' }} />;
};
