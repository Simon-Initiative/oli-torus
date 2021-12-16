import React from 'react';
import { ReactEditor, useSlate } from 'slate-react';
import { ButtonContext, ToolbarItem } from 'components/editing/toolbar/interfaces';
import { DropdownButton, SimpleButton } from 'components/editing/toolbar/common';
import './toolbar.scss';
import { Editor } from 'slate';

export type Props = {
  context: ButtonContext;
  items: ToolbarItem[];
};
export const Toolbar = (props: Props) => {
  const editor = useSlate();

  console.log('updating');

  if (
    !ReactEditor.isFocused(editor) ||
    ReactEditor.toDOMNode(editor, editor) !== document.activeElement
  )
    return null;

  return (
    <div className="editor__toolbar">
      {props.items.map((item, i) => {
        if (item.type === 'GroupDivider') return <VerticalSeparator key={`spacer-${i}`} />;

        const { icon, command, description, active, renderMode } = item;

        const btnProps = {
          active: active && active(editor),
          icon: icon(editor),
          command: command,
          context: props.context,
          description: description(editor),
          key: i,
        };

        if (!command.precondition(editor)) return null;
        if (renderMode === 'Simple') return <SimpleButton {...btnProps} />;
        return <DropdownButton {...btnProps} key={i} />;
      })}
    </div>
  );
};

interface VSProps {
  key: string;
}
const VerticalSeparator = ({ key }: VSProps) => <div key={key} className="button-separator"></div>;
