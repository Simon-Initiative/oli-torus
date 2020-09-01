import React from 'react';
import { useSlate, ReactEditor } from 'slate-react';
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
  setParentPopoverOpen?: (b: boolean) => void;
}

export const ToolbarButton = ({ icon, command, style, context, active,
  description, setParentPopoverOpen }: ToolbarButtonProps) => {
  const editor = useSlate();

  return (
    <button
      data-toggle="tooltip"
      data-placement="top"
      className={`btn btn-sm btn-light ${style || ''} ${active && 'active' || ''}`}
      onMouseDown={(e) => {
        e.preventDefault();
        e.stopPropagation();
      }}
      onClick={(event) => {
        event.preventDefault();
        event.stopPropagation();
        setParentPopoverOpen && setParentPopoverOpen(false);
        command.execute(context, editor);
      }}>
      {buttonContent(icon, description)}
    </button>
  );
};

export const DropdownToolbarButton = ({ icon, command, style, context, active, description,
  position, setParentPopoverOpen }: ToolbarButtonProps) => {

  const editor = useSlate();
  const [isPopoverOpen, setIsPopoverOpen] = React.useState(false);

  const onDone = (params: any) => {
    setParentPopoverOpen && setParentPopoverOpen(false);
    setIsPopoverOpen(false);
    command.execute(context, editor, params);
  };
  const onCancel = () => {
    setParentPopoverOpen && setParentPopoverOpen(false);
    setIsPopoverOpen(false);
  };

  return (
    <Popover
      onClickOutside={e => setIsPopoverOpen(false)}
      disableReposition={true}
      transitionDuration={0}
      isOpen={isPopoverOpen}
      padding={5}
      position={position || 'right'}
      content={() => <div>
        {(command as any).obtainParameters(context, editor, onDone, onCancel)}
      </div>
      }>
      {ref => <button
        ref={ref}
        data-toggle="tooltip"
        data-placement="top"
        className={`btn btn-sm btn-light ${style || ''} ${active && 'active' || ''}`}
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
