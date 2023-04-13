import React, { PropsWithChildren } from 'react';
import { ToolbarContext, ToolbarContextT } from 'components/editing/toolbar/hooks/useToolbar';
import { CommandContext } from '../elements/commands/interfaces';
import styles from './Toolbar.modules.scss';

interface Props {
  context: CommandContext;
  fixed?: boolean;
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

  const cssClasses = props.fixed ? `${styles.toolbar} ${styles.fixedToolbar}` : styles.toolbar;

  return (
    <ToolbarContext.Provider value={context}>
      <div className={cssClasses}>{props.children}</div>
    </ToolbarContext.Provider>
  );
};

interface GroupProps {}
const Group = (props: PropsWithChildren<GroupProps>) => (
  <div className={styles.toolbarGroup}>{props.children}</div>
);
Toolbar.Group = Group;

interface ButtonGroupProps {}
const ButtonGroup = (props: PropsWithChildren<ButtonGroupProps>) => (
  <div className={styles.toolbarButtonGroup}>{props.children}</div>
);
Toolbar.ButtonGroup = ButtonGroup;
