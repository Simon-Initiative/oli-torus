import React, { useState, useRef, useEffect } from 'react';
import * as ReactDOM from 'react-dom';
import { ReactEditor, useSlate } from 'slate-react';
import { Editor as SlateEditor, Node, Range, Transforms } from 'slate';
import { hoverMenuCommands } from './editors';
import { ToolbarItem, gutterWidth } from './interfaces';
import { getRootOfText } from './utils';

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
  el.style.visibility = 'hidden';
}

function shouldHideToolbar(editor: ReactEditor) {
  const { selection } = editor;
  return !selection ||
    !ReactEditor.isFocused(editor) ||
    Range.isCollapsed(selection) ||
    SlateEditor.string(editor, selection) === '';
}


export const HoveringToolbar = () => {
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
    <div ref={(ref as any)} style={{ visibility: 'hidden', position: 'relative' }}>
      <div style={style} className="btn-group btn-group-sm" role="group" ref={(ref as any)}>
        {hoverMenuCommands.map(b =>
          <ToolbarButton key={b.icon} icon={b.icon} command={b.command} />)}
      </div>
    </div>, document.body,
  );
};

function showToolbar(el: HTMLElement) {
  el.style.visibility = 'visible';
}

function shouldHideFixedToolbar(editor: ReactEditor) {
  return !ReactEditor.isFocused(editor);
}

type FixedToolbarProps = {
  toolbarItems: ToolbarItem[];
};

export const FixedToolbar = (props: FixedToolbarProps) => {
  const { toolbarItems } = props;
  const [collapsed, setCollapsed] = useState(false);
  const ref = useRef();
  const editor = useSlate();

  const icon = collapsed ? 'fas fa-angle-left' : 'fas fa-angle-right';

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

  const style = {
    position: 'absolute',
    zIndex: 1,
    top: '0px',
    right: -gutterWidth + 'px',
    borderRadius: '4px',
    transition: 'opacity 0.75s',
  } as any;

  const buttons = collapsed
    ? []
    : [<TextFormatter key="text"/>, ...toolbarItems.map((t, i) => {
      if (t.type === 'CommandDesc' && t.command.obtainParameters === undefined) {
        return <ToolbarButton key={t.icon} icon={t.icon} command={t.command} />;
      }
      if (t.type === 'CommandDesc' && t.command.obtainParameters !== undefined) {
        return <DropdownToolbarButton key={t.icon} icon={t.icon} command={t.command} />;
      }
      return <Spacer key={'spacer-' + i} />;
    })];


  return (
    <div ref={(ref as any)} style={{ visibility: 'hidden', position: 'sticky', top: '0px' }}>
      <div style={style} className="btn-group btn-group-sm" role="group" ref={(ref as any)}>
        {buttons}
        <button
          className="btn btn-secondary btn-sm"
          style={{ width: '10px' }}
          onMouseDown={(event) => {
            event.preventDefault();
            setCollapsed(!collapsed);
          }}
        >
          <i className={icon}></i>
        </button>
      </div>
    </div>
  );
};

const Spacer = () => {
  return (
    <span style={{ minWidth: '5px', maxWidth: '5px' }} />
  );
};

const textOptions = [
  { value: 'p', text: 'Normal text' },
  { value: 'h1', text: 'Title' },
  { value: 'h2', text: 'Subtitle' },
  { value: 'h3', text: 'Heading 1' },
  { value: 'h4', text: 'Heading 2' },
  { value: 'h5', text: 'Heading 3' },
  { value: 'h6', text: 'Heading 4' },
];

const TextFormatter = () => {
  const editor = useSlate();
  const selected = getRootOfText(editor).caseOf({
    just: n => (parentTextTypes as any)[n.type] ? n.type : 'p',
    nothing: () => 'p',
  });

  const onChange = (e: any) => {
    getRootOfText(editor).lift((n: Node) => {
      if ((parentTextTypes as any)[n.type]) {
        const path = ReactEditor.findPath(editor, n);
        const type = e.target.value;
        Transforms.setNodes(editor, { type }, { at: path });
      }
    });

  };

  return (
    <select
      onChange={onChange}
      value={selected}
      className="custom-select custom-select-sm">
      {textOptions.map(o =>
        <option key={o.value} value={o.value}>{o.text}</option>)}
    </select>
  );
};

const ToolbarButton = ({ icon, command }: any) => {
  const editor = useSlate();
  return (
    <button
      className="btn btn-secondary btn-sm"
      onMouseDown={(event) => {
        event.preventDefault();
        command.execute(editor);
      }}
    >
      <i className={icon}></i>
    </button>
  );
};

const DropdownToolbarButton = ({ icon, command }: any) => {
  const editor = useSlate();

  const ref = useRef();

  useEffect(() => {
    if (ref !== null && ref.current !== null) {
      ((window as any).$('.dropdown-toggle') as any).dropdown();
    }
  });

  const onDone = (params: any) => command.execute(editor, params);
  const onCancel = () => {};

  return (
    <div ref={ref as any} className="dropdown">
      <button
          className="btn btn-secondary btn-sm dropdown-toggle"
          data-toggle={'dropdown'}
          type="button">
        <i className={icon}></i>
      </button>
      <div className="dropdown-menu dropdown-menu-right">
        {(command as any).obtainParameters(editor, onDone, onCancel)}
      </div>
    </div>
  );
};
