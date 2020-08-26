import React, { useRef, useEffect } from 'react';
import * as ReactDOM from 'react-dom';
import { useSlate, ReactEditor } from 'slate-react';
import { CommandContext } from 'components/editor/editors/interfaces';
import { CommandDesc } from 'components/editor/commands/interfaces';
import { showToolbar, hideToolbar } from 'components/editor/toolbars/common';
import { positionFormatting } from 'components/editor/toolbars/formatting/utils';
import { HoveringToolbar } from 'components/editor/toolbars/HoveringToolbar';

function formattingAreEqual(prevProps: FormattingToolbarProps, nextProps: FormattingToolbarProps) {
  return prevProps.commandContext === nextProps.commandContext;
}

export type FormattingToolbarProps = {
  commandContext: CommandContext;
  commandDescs: CommandDesc[][];
  shouldHideToolbar: (editor: ReactEditor) => boolean;
};
export const FormattingToolbar = React.memo((props: FormattingToolbarProps) => {
  const ref = useRef();
  const editor = useSlate();

  useEffect(() => {
    const el = ref.current as any;
    if (!el) {
      return;
    }

    if (props.shouldHideToolbar(editor)) {
      hideToolbar(el);
    } else {
      positionFormatting(el);
      showToolbar(el);
    }
  });

  return ReactDOM.createPortal(
    <div ref={(ref as any)} className="formatting-toolbar">
      <HoveringToolbar
        commandDescs={props.commandDescs}
        commandContext={props.commandContext}
      />
    </div>,
    document.body,
  );
}, formattingAreEqual);
