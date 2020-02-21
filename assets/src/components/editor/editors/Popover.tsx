import React, { useRef, useEffect } from 'react';
import * as ReactDOM from 'react-dom';
import { ReactEditor, useSlate } from 'slate-react';

function position(el: HTMLElement, source: HTMLElement) {

  const rect = source.getBoundingClientRect();

  el.style.position = 'absolute';
  el.style.top =
    ((rect as any).top + (window as any).pageYOffset) - 30 + 'px';

  const left = ((rect as any).left +
    window.pageXOffset -
    el.offsetWidth / 2 +
    (rect as any).width / 2) - 50;

  el.style.left = `${left}px`;
}

function hide(el: HTMLElement) {
  el.style.visibility = 'hidden';
}


function show(el: HTMLElement) {
  el.style.visibility = 'visible';
}


function shouldHide(editor: ReactEditor) {
  return !ReactEditor.isFocused(editor);
}


export const Popover = (props: any) => {
  const ref = useRef();
  const editor = useSlate();

  useEffect(() => {
    const el = ref.current as any;

    if (!el) {
      return;
    }

    if (shouldHide(editor)) {
      hide(el);
    } else {
      position(el, props.source.current);
      show(el);
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
      <div style={style}>
        {props.children}
      </div>
    </div>, document.body,
  );
};