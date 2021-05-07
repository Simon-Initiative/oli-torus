/* eslint-disable react/prop-types */
import React, { CSSProperties, useEffect, useState } from 'react';

const NavigationButton: React.FC<any> = (props) => {
  const [state, setState] = useState<any[]>(Array.isArray(props.state) ? props.state : []);
  const [model, setModel] = useState<any>(Array.isArray(props.model) ? props.model : {});
  const id: string = props.id;
  const {
    title,
    x = 0,
    y = 0,
    z = 0,
    width,
    height,
    customCssClass,
    textColor,
    buttonColor,
    visible = true,
    enabled = true,
    ariaLabel,
    transparent,
    selected,
  } = model;
  const styles: CSSProperties = {
    position: 'absolute',
    top: y,
    left: x,
    width,
    height,
    display: visible ? 'block' : 'none',
    zIndex: z,
  };
  const [buttonSelected, setButtonSelected] = useState(selected || false);
  const [buttonTextColor, setButtonTextColor] = useState(textColor);
  const [accessibilityText, setAccessibilityText] = useState('');
  const [backgroundColor, setBackgroundColor] = useState(buttonColor);
  const [buttonVisible, setButtonVisible] = useState(visible);
  const [buttonTransparent, setButtonTransparent] = useState(transparent);
  const [buttonEnabled, setbuttonEnabled] = useState(enabled);
  const [buttonTitle, setButtonTitle] = useState(title);
  const janusButtonStyle: CSSProperties = {
    width: width,
  };
  if (buttonTransparent) styles.opacity = 0;
  if (buttonTextColor) {
    styles.color = buttonTextColor;
    janusButtonStyle.color = buttonTextColor;
  }
  // TODO: figure out how to handle custom colors on hover
  if (backgroundColor) {
    styles.backgroundColor = backgroundColor;
    janusButtonStyle.backgroundColor = backgroundColor;
  }

  const handleButtonPress = () => {
    return;
    //TODO onSubmitActivity not yet implemented
    props.onSubmitActivity({
      activityId: `${id}`,
      partResponses: [
        {
          id: `stage.${id}.Selected`,
          key: 'Selected',
          type: 4,
          value: true,
        },
      ],
    });
  };
  if (buttonSelected) {
    setButtonSelected(false);
    handleButtonPress();
    //TODO onSubmitActivity not yet implemented
    /*  props.onSaveActivity({
      activityId: `${id}`,
      partResponses: [
        {
          id: `stage.${id}.Selected`,
          key: 'Selected',
          type: 4,
          value: false,
        },
      ],
    }); */
  }
  useEffect(() => {
    if (typeof props?.model === 'string') {
      setModel(JSON.parse(props.model));
    }
    if (typeof props?.state === 'string') {
      setState(JSON.parse(props.state));
    }
  }, [props]);

  useEffect(() => {
    //TODO handle value changes on state updates
    console.log({ state });
  }, [state]);

  useEffect(() => {
    props.onReady({
      activityId: `${id}`,
      partResponses: [
        {
          id: `stage.${id}.Selected`,
          key: 'Selected',
          type: 4,
          value: false,
        },
        {
          id: `stage.${id}.visible`,
          key: 'visible',
          type: 4,
          value: visible,
        },
        {
          id: `stage.${id}.enabled`,
          key: 'enabled',
          type: 4,
          value: enabled,
        },
        {
          id: `stage.${id}.title`,
          key: 'title',
          type: 2,
          value: title,
        },
        {
          id: `stage.${id}.textColor`,
          key: 'textColor',
          type: 2,
          value: textColor,
        },
        {
          id: `stage.${id}.backgroundColor`,
          key: 'backgroundColor',
          type: 2,
          value: buttonColor,
        },
        {
          id: `stage.${id}.transparent`,
          key: 'transparent',
          type: 4,
          value: transparent,
        },
        {
          id: `stage.${id}.accessibilityText`,
          key: 'accessibilityText',
          type: 2,
          value: '',
        },
      ],
    });
  }, []);
  const buttonProps = {
    title: buttonTitle,
    onClick: handleButtonPress,
    'aria-label': ariaLabel,
    disabled: !buttonEnabled,
    className: `${customCssClass}`,
  };
  return buttonVisible ? (
    <button data-janus-type={props.type} {...buttonProps} style={styles}>
      {title}
    </button>
  ) : null;
};

export const tagName = 'janus-navigation-button';

export default NavigationButton;
