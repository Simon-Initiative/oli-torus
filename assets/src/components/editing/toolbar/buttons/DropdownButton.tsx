import { CommandDescription } from 'components/editing/elements/commands/interfaces';
import { ButtonContent } from 'components/editing/toolbar/buttons/ButtonContent';
import { useToolbar } from 'components/editing/toolbar/hooks/useToolbar';
import React, { PropsWithChildren } from 'react';
import { Popover } from 'react-tiny-popover';
import { useSlate } from 'slate-react';
import { classNames } from 'utils/classNames';
import { valueOr } from 'utils/common';
import styles from '../Toolbar.modules.scss';

interface Props {
  description: CommandDescription;
  showDropdownArrow?: boolean;
}

export const DropdownButton = (props: PropsWithChildren<Props>) => {
  const thisDropdown = React.useRef<HTMLButtonElement | null>(null);
  const toolbar = useToolbar();
  const editor = useSlate();

  const showDropdownArrow = valueOr(props.showDropdownArrow, true);

  const isOpen = !!thisDropdown.current && toolbar.submenu?.current === thisDropdown.current;

  const onClick = React.useCallback(
    (e) => {
      isOpen ? toolbar.closeSubmenus() : toolbar.openSubmenu(thisDropdown as any);
      e.stopPropagation();
    },
    [toolbar, thisDropdown],
  );

  return (
    <Popover
      ref={thisDropdown}
      onClickOutside={toolbar.closeSubmenus}
      isOpen={isOpen}
      padding={8}
      positions={['bottom']}
      reposition={true}
      align={'start'}
      containerStyle={{ zIndex: '100000' }}
      content={<div className={styles.dropdownGroup}>{props.children}</div>}
    >
      <button
        className={classNames(
          styles.toolbarButton,
          styles.dropdownButton,
          props.description.active?.(editor) && styles.active,
        )}
        onClick={onClick}
      >
        <ButtonContent {...props} />
        {showDropdownArrow && <i className="fa-solid fa-angle-down"></i>}
      </button>
    </Popover>
  );
};
