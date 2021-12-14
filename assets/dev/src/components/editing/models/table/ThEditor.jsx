import React from 'react';
import { useFocused, useSelected, useSlate } from 'slate-react';
import { DropdownMenu } from './DropdownMenu';
export const ThEditor = (props) => {
    const editor = useSlate();
    const selected = useSelected();
    const focused = useFocused();
    const maybeMenu = selected && focused ? <DropdownMenu editor={editor} model={props.model}/> : null;
    return (<th {...props.attributes}>
      {maybeMenu}
      {props.children}
    </th>);
};
//# sourceMappingURL=ThEditor.jsx.map