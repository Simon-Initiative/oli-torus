import React from 'react';
import { useSlate } from 'slate-react';
import { ButtonContext, ToolbarItem } from 'components/editing/toolbar/interfaces';
import { VerticalSpacer } from 'components/editing/toolbar/buttons/spacers';
import { SimpleButton } from 'components/editing/toolbar/buttons/SimpleButton';
import { ToolbarDropdown } from 'components/editing/toolbar/buttons/ToolbarDropdown';

export type Props = {
  isFocused: boolean;
  context: ButtonContext;
  items: ToolbarItem[];
};
export const Toolbar = (props: Props) => {
  const editor = useSlate();

  if (!props.isFocused) return null;

  return (
    <div className="editor__toolbar" onMouseDown={(e) => e.preventDefault()}>
      {props.items.map((item, i) => {
        if (item.type === 'GroupDivider') return <VerticalSpacer key={`spacer-${i}`} />;

        const { icon, command, description, active, renderMode } = item;

        const btnProps = {
          active: active?.(editor),
          icon: icon(editor),
          command: command,
          context: props.context,
          description: description(editor),
          key: i,
        };

        if (renderMode === 'Simple') return <SimpleButton {...btnProps} />;
        return <ToolbarDropdown {...btnProps} key={i} />;
      })}
    </div>
  );
};
