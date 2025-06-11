import React, { CSSProperties, useEffect } from 'react';
import { AuthorPartComponentProps } from 'components/parts/types/parts';
import { NavButtonModel } from './schema';

const NavButtonAuthor: React.FC<AuthorPartComponentProps<NavButtonModel>> = (props) => {
  const { model } = props;

  const {
    title,
    width,
    height,
    textColor,
    buttonColor,
    visible = true,
    enabled = true,
    ariaLabel,
    transparent,
    imageSource,
    imagePosition,
  } = model;

  const styles: CSSProperties = {
    width,
    height,
    cursor: 'move',
  };

  if (transparent || !visible || !enabled) {
    // TODO: some kind of strike through style?
    styles.opacity = 0.5;
  }

  if (textColor) {
    styles.color = textColor;
  }

  if (buttonColor) {
    styles.backgroundColor = buttonColor;
  }
  const isVertical = imagePosition === 'Top' || imagePosition === 'Bottom';

  //Apply these style only if button have image
  if (imageSource?.length) {
    styles.display = 'flex';
    styles.flexDirection = isVertical
      ? imagePosition === 'Top'
        ? 'column'
        : 'column-reverse'
      : imagePosition === 'Left'
      ? 'row'
      : 'row-reverse';

    styles.alignItems = 'center';
    styles.gap = isVertical ? '1px' : '4px';
  }

  const handleStylingChanges = () => {
    const styleChanges: any = {};
    if (width !== undefined) {
      styleChanges.width = { value: width as number };
    }
    if (height != undefined) {
      styleChanges.height = { value: height as number };
    }
    props.onResize({ id: `${props.id}`, settings: styleChanges });
  };
  useEffect(() => {
    // all activities *must* emit onReady
    props.onReady({ id: `${props.id}` });
    handleStylingChanges();
  }, []);

  const buttonProps = {
    title,
    'aria-label': ariaLabel,
    disabled: false,
  };
  return (
    <div className={`navigation-button`}>
      <button data-janus-type={tagName} {...buttonProps} style={styles}>
        {imageSource?.length > 0 && (
          <img
            draggable="false"
            src={imageSource}
            style={{
              height: isVertical && title ? '60%' : '100%',
              width: title ? '50%' : '100%',
            }}
          />
        )}
        {title && <span>{title}</span>}
      </button>
    </div>
  );
};

export const tagName = 'janus-navigation-button';

export default NavButtonAuthor;
