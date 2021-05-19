/* eslint-disable react/prop-types */
import React, { CSSProperties, useEffect, useState } from 'react';
import { parseBool } from 'utils/helpers';
import { StateVariable } from '../types/parts';

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
    props.onSubmit({
      id: `${id}`,
      partResponses: [
        {
          id: `${id}.Selected`,
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
    props.onSave({
      id: `${id}`,
      partResponses: [
        {
          id: `${id}.Selected`,
          key: 'Selected',
          type: 4,
          value: false,
        },
      ],
    });
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
    handleStateChange(state);
  }, [state]);

  const handleStateChange = (stateData: StateVariable[]) => {
    // override various things from state
    const stateVariables: any = {
      btnTitle: title,
      btnBackgroundColor: buttonColor,
      btnEnabled: enabled,
      btnSelected: selected,
      btnTextColor: textColor,
      btnTransparent: transparent,
      btnVisible: visible,
      btnaccessibilityText: '',
    };
    const interested = stateData.filter((stateVar) => stateVar.id.indexOf(`stage.${id}.`) === 0);
    let isTitleSet = false;
    interested.forEach((stateVar) => {
      if (stateVar.key === 'title') {
        setButtonTitle(stateVar.value as string);
        stateVariables.btnTitle = stateVar.value as string;
        isTitleSet = true;
      }
      if (stateVar.key === 'buttonTitles') {
        setButtonTitle(stateVar.value[0]);
        stateVariables.btnTitle = stateVar.value[0];
        isTitleSet = true;
      }
      if (stateVar.key === 'Selected') {
        const boolSelected: boolean = parseBool(stateVar.value);
        setButtonSelected(boolSelected);
        stateVariables.btnSelected = boolSelected;
      }
      if (stateVar.key === 'visible') {
        setButtonVisible(stateVar.value);
        stateVariables.btnVisible = stateVar.value;
      }
      if (stateVar.key === 'enabled') {
        const boolEnabled: boolean = parseBool(stateVar.value);
        setbuttonEnabled(boolEnabled);
        stateVariables.btnEnabled = boolEnabled;
      }
      if (stateVar.key === 'textColor') {
        setButtonTextColor(stateVar.value);
        stateVariables.btnTextColor = stateVar.value;
      }
      if (stateVar.key === 'accessibilityText') {
        setAccessibilityText(stateVar.value as string);
        stateVariables.btnaccessibilityText = stateVar.value as string;
      }
      if (stateVar.key === 'backgroundColor') {
        console.log({ backgroundColor: stateVar.value });

        setBackgroundColor(stateVar.value);
        stateVariables.btnBackgroundColor = stateVar.value;
      }
      if (stateVar.key === 'transparent') {
        setButtonTransparent(stateVar.value);
        stateVariables.btnTransparent = stateVar.value;
      }
    });
    if (!isTitleSet) {
      setButtonTitle(title);
      stateVariables.btnTitle = title;
    }
  };

  useEffect(() => {
    props.onReady({
      id: `${id}`,
      partResponses: [
        {
          id: `${id}.Selected`,
          key: 'Selected',
          type: 4,
          value: false,
        },
        {
          id: `${id}.visible`,
          key: 'visible',
          type: 4,
          value: visible,
        },
        {
          id: `${id}.enabled`,
          key: 'enabled',
          type: 4,
          value: enabled,
        },
        {
          id: `${id}.title`,
          key: 'title',
          type: 2,
          value: title,
        },
        {
          id: `${id}.textColor`,
          key: 'textColor',
          type: 2,
          value: textColor,
        },
        {
          id: `${id}.backgroundColor`,
          key: 'backgroundColor',
          type: 2,
          value: buttonColor,
        },
        {
          id: `${id}.transparent`,
          key: 'transparent',
          type: 4,
          value: transparent,
        },
        {
          id: `${id}.accessibilityText`,
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
