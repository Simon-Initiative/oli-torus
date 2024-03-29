import React from 'react';
import * as Popover from 'react-tiny-popover';
import { Editor } from 'slate';
import { useSlate } from 'slate-react';
import { classNames } from 'utils/classNames';
import { Command, CommandContext } from '../elements/commands/interfaces';

const buttonContent = (icon: JSX.Element, description: string | undefined) =>
  icon ? icon : <span className="toolbar-button-text">{description}</span>;

export interface ToolbarButtonProps {
  icon: (editor: Editor) => JSX.Element;
  command: Command;
  context: CommandContext;
  description?: (editor: Editor) => string;
  tooltip?: string;
  style?: string;
  active?: boolean;
  disabled?: boolean;
  position?: 'left' | 'right' | 'top' | 'bottom';
  setParentPopoverOpen?: (b: boolean) => void;
  parentRef?: React.RefObject<HTMLElement>;
  setContent?: React.Dispatch<React.SetStateAction<JSX.Element>>;
}

export const DropdownToolbarButton = (props: ToolbarButtonProps) => {
  const editor = useSlate();
  const [isPopoverOpen, setIsPopoverOpen] = React.useState(false);
  const [content, _setContent] = React.useState(<span></span>);

  const _onDone = (params: any) => {
    props.setParentPopoverOpen?.(false);
    props.command.execute(props.context, editor, params);
  };
  const _onCancel = () => {
    props.setParentPopoverOpen?.(false);
  };

  return (
    <Popover.Popover
      parentElement={props.parentRef?.current || undefined}
      onClickOutside={(_e) => setIsPopoverOpen(false)}
      isOpen={isPopoverOpen}
      padding={12}
      positions={['top', 'bottom']}
      reposition={false}
      content={content}
      align="start"
    >
      <button
        data-bs-container={`#${props.parentRef?.current?.id}`}
        data-bs-toggle="tooltip"
        ref={(r) => ($(r as any) as any).tooltip()}
        data-bs-placement="top"
        title={props.tooltip}
        className={classNames('btn', props.style, props.active && 'active')}
        onClick={(_e) => {
          setIsPopoverOpen(!isPopoverOpen);
          _e.stopPropagation();
        }}
      >
        {buttonContent(props.icon(editor), props.description?.(editor))}
      </button>
    </Popover.Popover>
  );
};
