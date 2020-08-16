import React, { useRef, useEffect } from 'react';
import { ReactEditor, useSlate } from 'slate-react';
import { ToolbarItem, CommandContext } from '../../commands/interfaces';
import Popover from 'react-tiny-popover';
import { hideToolbar, showToolbar, ToolbarButton } from '../common';
import { Editor, Range, Text } from 'slate';

function shouldShowFixedToolbar(editor: ReactEditor) {
  const { selection } = editor;

  if (!selection) return false;

  // True if the cursor is in a paragraph at the toplevel with no content
  const isCursorAtEmptyLine = () => {
    const nodes = Array.from(Editor.nodes(editor, { at: selection }));
    if (nodes.length !== 3) {
      return false;
    }
    const [[first], [second], [third]] = nodes;
    return Editor.isEditor(first) &&
      second.type === 'p' &&
      Text.isText(third) && third.text === '';
  };

  return ReactEditor.isFocused(editor) &&
    Range.isCollapsed(selection);
    // isCursorAtEmptyLine();
}

export type ToolbarPosition = {
  top?: number,
  bottom?: number,
  left?: number,
  right?: number,
};

type FixedToolbarProps = {
  toolbarItems: ToolbarItem[];
  commandContext: CommandContext;
  position?: ToolbarPosition;
};

function fixedAreEqual(prevProps: FixedToolbarProps, nextProps: FixedToolbarProps) {
  return prevProps.commandContext === nextProps.commandContext
    && prevProps.toolbarItems === nextProps.toolbarItems;
}

export const FixedToolbar = React.memo((props: FixedToolbarProps) => {
  const { toolbarItems } = props;
  const ref = useRef();
  const editor = useSlate();

  useEffect(() => {
    const el = ref.current as any;

    if (!el) {
      return;
    }

    if (shouldShowFixedToolbar(editor)) {
      showToolbar(el);
    } else {
      hideToolbar(el);
    }
  });

  const buttons = [
    ...toolbarItems.map((t, i) => {
      if (t.type === 'CommandDesc' && t.command.obtainParameters === undefined) {
        return <ToolbarButton
          tooltip={t.description}
          style="mr-1" key={t.icon} icon={t.icon}
          command={t.command} context={props.commandContext} />;
      }
      if (t.type === 'CommandDesc' && t.command.obtainParameters !== undefined) {
        return <DropdownToolbarButton style="mr-1" key={t.icon} icon={t.icon}
          tooltip={t.description}
          command={t.command} context={props.commandContext} />;
      }
      return <Spacer key={'spacer-' + i} />;
    }),
  ];

  const style = props.position !== undefined
    ? {
      display: 'none',
      top: props.position.top,
      bottom: props.position.bottom,
      left: props.position.left,
      right: props.position.right,
    }
    : {
      display: 'none',
    };

  return (
    <div ref={(ref as any)} className="toolbar fixed-toolbar" style={style}>
      <div className="toolbar-buttons btn-group btn-group-sm" role="group" ref={(ref as any)}>
        {buttons}
      </div>
    </div>
  );
}, fixedAreEqual);

const DropdownToolbarButton = ({ icon, command, style, context, tooltip }: any) => {

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

const Spacer = () => {
  return (
    <span style={{ minWidth: '5px', maxWidth: '5px' }} />
  );
};
