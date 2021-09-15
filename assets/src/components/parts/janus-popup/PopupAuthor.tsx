import { AuthorPartComponentProps } from 'components/parts/types/parts';
import React, { CSSProperties, useEffect } from 'react';
import { getIconSrc } from './GetIcon';
import { PopupModel } from './schema';

const PopupAuthor: React.FC<AuthorPartComponentProps<PopupModel>> = (props) => {
  const { id, model } = props;

  const {
    x,
    y,
    z,
    width,
    height,
    customCssClass,
    openByDefault,
    visible = true,
    defaultURL,
    iconURL,
    useToggleBehavior,
    popup,
    description,
  } = model;

  const iconSrc = getIconSrc(iconURL, defaultURL);

  const styles: CSSProperties = {
    width,
    height,
  };

  // for authoring we don't actually want to hide it
  if (!visible) {
    styles.opacity = 0.5;
  }

  useEffect(() => {
    // all activities *must* emit onReady
    props.onReady({ id: `${props.id}` });
  }, []);

  return (
    <input
      role="button"
      draggable="false"
      {...(iconSrc
        ? {
            src: iconSrc,
            type: 'image',
            alt: description,
          }
        : {
            type: 'button',
          })}
      className={`info-icon`}
      aria-controls={id}
      aria-haspopup="true"
      aria-label={description}
      style={styles}
    />
  );
};

export const tagName = 'janus-popup';

export default PopupAuthor;
