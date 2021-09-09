import { AuthorPartComponentProps } from 'components/parts/types/parts';
import React, { CSSProperties, useEffect } from 'react';
import { NavButtonModel } from './schema';

const NavButtonAuthor: React.FC<AuthorPartComponentProps<NavButtonModel>> = (props) => {
  const { model } = props;

  const { x, y, z, width, ariaLabel, title } = model;
  const styles: CSSProperties = {
    width,
    zIndex: z,
    backgroundColor: 'magenta',
    overflow: 'hidden',
    fontWeight: 'bold',
  };

  useEffect(() => {
    // all activities *must* emit onReady
    props.onReady({ id: `${props.id}` });
  }, []);

  const buttonProps = {
    title: title,
    'aria-label': ariaLabel,
    disabled: false,
  };

  return (
    <div className={`navigation-button`}>
      <button data-janus-type={tagName} {...buttonProps} style={styles}>
        {title}
      </button>
    </div>
  );
};

export const tagName = 'janus-navigation-button';

export default NavButtonAuthor;
