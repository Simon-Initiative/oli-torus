import React, { PropsWithChildren } from 'react';
import { CommandContext } from '../elements/commands/interfaces';
import { ToolbarContext, ToolbarContextT } from 'components/editing/toolbar/hooks/useToolbar';
import styles from './Toolbar.modules.scss';

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
      <div className={styles.toolbar}>{props.children}</div>
    </ToolbarContext.Provider>
  );
};

interface GroupProps {}
const Group = (props: PropsWithChildren<GroupProps>) => (
  <div className={styles.toolbarGroup}>{props.children}</div>
);
Toolbar.Group = Group;
