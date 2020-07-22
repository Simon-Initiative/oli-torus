import React, { useState, useRef, useEffect } from 'react';
import * as ReactDOM from 'react-dom';
import { ReactEditor, useSlate } from 'slate-react';
import { Editor as SlateEditor, Node, Range, Transforms } from 'slate';
import { hoverMenuCommands } from './editors';
import { ToolbarItem, gutterWidth, CommandContext } from './interfaces';
import { getRootOfText } from './utils';
import Popover from 'react-tiny-popover';

const parentTextTypes = {
  p: true,
  h1: true,
  h2: true,
  h3: true,
  h4: true,
  h5: true,
  h6: true,
};


function positionHovering(el: HTMLElement) {
  const menu = el;
  const native = window.getSelection() as any;
  const range = native.getRangeAt(0);
  const rect = (range as any).getBoundingClientRect();

  (menu as any).style.position = 'absolute';
  (menu as any).style.top =
    ((rect as any).top + (window as any).pageYOffset) - 30 + 'px';

  const left = ((rect as any).left +
    window.pageXOffset -
    (menu as any).offsetWidth / 2 +
    (rect as any).width / 2) - 50;

  (menu as any).style.left = `${left}px`;
}

function hideToolbar(el: HTMLElement) {
  el.style.display = 'none';
}

function shouldHideToolbar(editor: ReactEditor) {
  const { selection } = editor;

  // Hide the toolbar where there is either:
  // 1. No selection
  // 2. The editor is not currently in focus
  // 3. The selection range is collapsed
  // 4. The selection range spans more than one block
  // 5. The selection current text is only whitespace or
  //    is the empty string

  const spansMultipleBlocks = (selection: Range) => {
    if (selection.anchor.path.length === selection.focus.path.length) {
      for (let i = 0; i < selection.anchor.path.length; i += 1) {
        if (selection.anchor.path[i] !== selection.focus.path[i]) {
          return true;
        }
      }
      return false;
    }
    return true;
  };

  return !selection ||
    !ReactEditor.isFocused(editor) ||
    Range.isCollapsed(selection) ||
    spansMultipleBlocks(selection) ||
    SlateEditor.string(editor, selection).trim() === '';
}


type HoveringToolbarProps = {
  commandContext: CommandContext;
};

function hoveringAreEqual(prevProps: HoveringToolbarProps, nextProps: HoveringToolbarProps) {
  return prevProps.commandContext === nextProps.commandContext;
}

export const HoveringToolbar = React.memo((props: HoveringToolbarProps) => {
  const ref = useRef();
  const editor = useSlate();

  useEffect(() => {
    const el = ref.current as any;
    if (!el) {
      return;
    }

    if (shouldHideToolbar(editor)) {
      hideToolbar(el);
    } else {
      positionHovering(el);
      showToolbar(el);
    }
  });

  const style = {
    position: 'absolute',
    zIndex: 1,
    top: '0px',
    left: '0px',
    marginTop: '-6px',
    borderRadius: '4px',
    transition: 'opacity 0.75s',
  } as any;

  return ReactDOM.createPortal(
    <div ref={(ref as any)} className="hovering-toolbar" style={{ display: 'none', position: 'relative' }}>
      <div style={style} className="btn-group btn-group-sm" role="group" ref={(ref as any)}>
        {hoverMenuCommands.map(b =>
          <ToolbarButton style="btn-dark" key={b.icon}
          icon={b.icon} command={b.command} context={props.commandContext} />)}
      </div>
    </div>, document.body,
  );
}, hoveringAreEqual);

function showToolbar(el: HTMLElement) {
  el.style.display = 'block';
}

function shouldHideFixedToolbar(editor: ReactEditor) {
  return !ReactEditor.isFocused(editor);
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

    if (shouldHideFixedToolbar(editor)) {
      hideToolbar(el);
    } else {
      showToolbar(el);
    }
  });

  const buttons = [
    <TextFormatter key="text" />,
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
          command={t.command} context={props.commandContext}/>;
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

const Spacer = () => {
  return (
    <span style={{ minWidth: '5px', maxWidth: '5px' }} />
  );
};

const textOptions = [
  { value: 'p', text: 'Normal text' },
  { value: 'h1', text: 'Subtitle' },
  { value: 'h2', text: 'Heading 1' },
  { value: 'h3', text: 'Heading 2' },
  { value: 'h4', text: 'Heading 3' },
  { value: 'h5', text: 'Heading 4' },
  { value: 'h6', text: 'Heading 5' },
];

const TextFormatter = () => {
  const editor = useSlate();
  const selected = getRootOfText(editor).caseOf({
    just: n => (parentTextTypes as any)[n.type as string] ? n.type : 'p',
    nothing: () => 'p',
  });

  const onChange = (e: any) => {
    getRootOfText(editor).lift((n: Node) => {
      if ((parentTextTypes as any)[n.type as string]) {
        const path = ReactEditor.findPath(editor, n);
        const type = e.target.value;
        Transforms.setNodes(editor, { type }, { at: path });
      }
    });

  };

  return (
    <select
      onChange={onChange}
      value={selected  as string}
      className="text-formatter custom-select custom-select-sm mr-3">
      {textOptions.map(o =>
        <option key={o.value} value={o.value}>{o.text}</option>)}
    </select>
  );
};

const ToolbarButton = ({ icon, command, style, context, tooltip }: any) => {
  const editor = useSlate();
  return (
    <button
      data-toggle="tooltip" data-placement="top" title={tooltip}
      className={`btn btn-sm btn-light ${style}`}
      onMouseDown={(event) => {
        event.preventDefault();
        command.execute(context, editor);
      }}
    >
      <i className={icon}></i>
    </button>
  );
};


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
      onClickOutside={() => {
        setIsPopoverOpen(false);
      }}
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
        <i className={icon}></i>
      </button>}
    </Popover>
  );

};

