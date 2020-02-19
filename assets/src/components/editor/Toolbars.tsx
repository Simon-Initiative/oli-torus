import React, { useState, useRef, useEffect } from 'react';
import * as ReactDOM from 'react-dom';
import { ReactEditor, useSlate } from 'slate-react';
import { Editor as SlateEditor, Range } from 'slate';
import { hoverMenuButtons } from './editors';
import { ToolbarItem, gutterWidth } from './interfaces';

function positionHovering(el : HTMLElement) {
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

function shouldHideToolbar(editor : ReactEditor) {
  const { selection } = editor;
  return  !selection ||
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
        {hoverMenuButtons.map(b => <FormatButton key={b.icon} icon={b.icon} command={b.command} />)}
      </div>
    </div>, document.body,
  );
};

function showToolbar(el: HTMLElement) {
  el.style.visibility = 'visible';
}

function shouldHideFixedToolbar(editor : ReactEditor) {
  return  !ReactEditor.isFocused(editor);
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
    : toolbarItems.map((t, i) => {
      if (t.type === 'CommandDesc') {
        return <ToolbarButton key={t.icon} icon={t.icon} command={t.command}/>;
      }
      return <Spacer key={'spacer-' + i}/>;
    });


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
    <span style={{ minWidth: '5px', maxWidth: '5px' }}/>
  );
};

const FormatButton = ({ icon, command }: any) => {
  const editor = useSlate();
  return (
    <button
      className="btn btn-secondary btn-sm"
      onMouseDown={(event) => {
        event.preventDefault();
        command(editor);
      }}
    >
      <i className={icon}></i>
    </button>
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
