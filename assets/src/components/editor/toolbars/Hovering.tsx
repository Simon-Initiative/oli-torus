import React, { useRef, useEffect } from 'react';
import * as ReactDOM from 'react-dom';
import { useSlate } from 'slate-react';
import { hoverMenuCommands } from '../editors';
import { CommandContext } from '../interfaces';
import { showToolbar, isToolbarHidden, shouldHideToolbar, hideToolbar, ToolbarButton } from './common';
import { textNodesInSelection, marksInSelection, marksInEntireSelection } from '../utils';

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
      isToolbarHidden(el) && positionHovering(el);
      showToolbar(el);
    }
  });

  const style = {
    position: 'absolute',
    zIndex: 1,
    top: '0px',
    left: '0px',
    marginTop: '-18px',
    borderRadius: '4px',
    transition: 'opacity 0.75s',
    backgroundImage: 'linear-gradient(to bottom,rgba(49,49,47,.99),#262625)',
  } as any;

  const isLastInList = (array: any[], index: number) => index === array.length - 1;

  return ReactDOM.createPortal(
    <div ref={(ref as any)} className="hovering-toolbar" style={{ display: 'none', position: 'relative' }}>
      <div style={style} className="btn-group btn-group-sm" role="group" ref={(ref as any)}>
        {hoverMenuCommands.map((buttonGroup, buttonGroupIndex) => {
          const buttons = buttonGroup.map(button =>
            <ToolbarButton
              style="btn-dark"
              active={button.active ? button.active(marksInEntireSelection(editor)) : false}
              key={button.icon}
              icon={button.icon}
              command={button.command}
              context={props.commandContext}
            />);

          const buttonSeparator = <div className="button-separator"></div>;

          return isLastInList(hoverMenuCommands, buttonGroupIndex)
            ? buttons
            : buttons.concat(buttonSeparator);
        })}
      </div>
    </div>, document.body,
  );
}, hoveringAreEqual);
