import React, { PropsWithChildren } from 'react';
import { CommandContext } from '../elements/commands/interfaces';
import { ToolbarContext, ToolbarContextT } from 'components/editing/toolbar/useToolbar';

interface Props {
  context: CommandContext;
}
export const Toolbar = (props: PropsWithChildren<Props>) => {
  const [submenu, setSubmenu] = React.useState<React.MutableRefObject<HTMLButtonElement> | null>(
    null,
  );

  const context = React.useMemo<ToolbarContextT>(
    () => ({
      context: props.context,
      submenu,
      openSubmenu: setSubmenu,
      closeSubmenus: () => setSubmenu(null),
    }),
    [props.context, submenu, setSubmenu],
  );

  return (
    <ToolbarContext.Provider value={context}>
      <div className="editorToolbar">{props.children}</div>
    </ToolbarContext.Provider>
  );
};

interface GroupProps {}
const Group = (props: PropsWithChildren<GroupProps>) => (
  <div className="editorToolbar__group">{props.children}</div>
);
Toolbar.Group = Group;
