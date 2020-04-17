import React, { useRef, useEffect } from 'react';
import * as ReactDOM from 'react-dom';
import { useSlate } from 'slate-react';

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

export const Popover = (props: any) => {
  const ref = useRef();
  const editor = useSlate();

  useEffect(() => {
    const el = ref.current as any;

    if (!el) {
      return;
    }
    position(el, props.source.current);

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
    <div ref={(ref as any)} style={{ position: 'relative' }}>
      <div style={style}>
        {props.children}
      </div>
    </div>, document.body,
  );
};
