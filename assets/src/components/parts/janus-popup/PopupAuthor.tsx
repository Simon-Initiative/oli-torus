import { AnyPartComponent, AuthorPartComponentProps } from 'components/parts/types/parts';
import React, { CSSProperties, useEffect, useState } from 'react';
import ReactDOM from 'react-dom';
import { parseBoolean } from 'utils/common';
import { getIconSrc } from './GetIcon';
import PopupWindow from './PopupWindow';
import PopupWindowDesigner from './PopupWindowDesigner';
import { PopupModel } from './schema';
import { ContextProps } from './types';

const PopupAuthor: React.FC<AuthorPartComponentProps<PopupModel>> = (props) => {
  const { id, model, configuremode, onConfigure, onCancelConfigure, onSaveConfigure } = props;

  const [inConfigureMode, setInConfigureMode] = useState<boolean>(parseBoolean(configuremode));
  useEffect(() => {
    // console.log('PopupAuthor configuremode changed!!', configuremode);
    setInConfigureMode(parseBoolean(configuremode));
  }, [configuremode]);

  const [context, setContext] = useState<ContextProps>({ currentActivity: '', mode: '' });
  const [showWindow, setShowWindow] = useState(false);

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

  // need to offset the window position by the position of the parent element
  // since it's a child of the parent element and not the activity (screen) directly
  const offsetWindowConfig = {
    ...popup.custom,
    x: popup.custom.x - (x || 0),
    y: popup.custom.y - (y || 0),
    z: Math.max(z || 0, popup.custom.z || 0),
  };

  const [windowConfig, setWindowConfig] = useState<any>(offsetWindowConfig);
  const [windowParts, setWindowParts] = useState<any[]>(popup.partsLayout || []);

  useEffect(() => {
    setWindowConfig(offsetWindowConfig);
    setWindowParts(popup.partsLayout || []);
  }, [props.model.popup]);

  const handleWindowClose = () => {
    setShowWindow(false);
  };

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

  const handleDesignerSave = (parts: AnyPartComponent[]) => {
    console.log('POPUP AUTHOR DESIGNER SAVE', parts);
  };

  const handleDesignerCancel = () => {
    onConfigure({ id: `${props.id}`, configure: false });
    setInConfigureMode(false);
  };

  const Designer = () => {
    // console.log('PopupAuthor: Designer', props.portal);
    return ReactDOM.createPortal(
      <PopupWindowDesigner
        config={windowConfig}
        parts={windowParts}
        onSave={handleDesignerSave}
        onCancel={handleDesignerCancel}
      />,
      document.getElementById(props.portal) as Element,
    );
  };

  return (
    <React.Fragment>
      {inConfigureMode && <Designer />}
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
        onDoubleClick={() => {
          setShowWindow(true);
        }}
        aria-controls={id}
        aria-haspopup="true"
        aria-label={description}
        style={styles}
      />
      {showWindow && (
        <PopupWindow
          config={windowConfig}
          parts={windowParts}
          context={context}
          onClose={handleWindowClose}
        />
      )}
    </React.Fragment>
  );
};

export const tagName = 'janus-popup';

export default PopupAuthor;
