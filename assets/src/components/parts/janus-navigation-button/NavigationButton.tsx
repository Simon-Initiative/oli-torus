/* eslint-disable react/prop-types */
import { CapiVariableTypes } from '../../../adaptivity/capi';
import React, { CSSProperties, useEffect, useState } from 'react';
import { parseBool } from 'utils/common';
import { CapiVariable } from '../types/parts';

const NavigationButton: React.FC<any> = (props) => {
  const [state, setState] = useState<any[]>(Array.isArray(props.state) ? props.state : []);
  const [model, setModel] = useState<any>(Array.isArray(props.model) ? props.model : {});
  const [ready, setReady] = useState<boolean>(false);
  const id: string = props.id;
  useEffect(() => {
    let pModel;
    let pState;
    if (typeof props?.model === 'string') {
      try {
        pModel = JSON.parse(props.model);
        setModel(pModel);
      } catch (err) {
        // bad json, what do?
      }
    }
    if (typeof props?.state === 'string') {
      try {
        pState = JSON.parse(props.state);
        setState(pState);
      } catch (err) {
        // bad json, what do?
      }
    }
    if (!pModel) {
      return;
    }
    props.onInit({
      id,
      responses: [
        {
          id: `Selected`,
          key: 'Selected',
          type: CapiVariableTypes.BOOLEAN,
          value: false,
        },
        {
          id: `visible`,
          key: 'visible',
          type: CapiVariableTypes.BOOLEAN,
          value: visible,
        },
        {
          id: `enabled`,
          key: 'enabled',
          type: CapiVariableTypes.BOOLEAN,
          value: enabled,
        },
        {
          id: `title`,
          key: 'title',
          type: CapiVariableTypes.STRING,
          value: title,
        },
        {
          id: `textColor`,
          key: 'textColor',
          type: CapiVariableTypes.STRING,
          value: textColor,
        },
        {
          id: `backgroundColor`,
          key: 'backgroundColor',
          type: CapiVariableTypes.STRING,
          value: buttonColor,
        },
        {
          id: `transparent`,
          key: 'transparent',
          type: CapiVariableTypes.STRING,
          value: transparent,
        },
        {
          id: `accessibilityText`,
          key: 'accessibilityText',
          type: CapiVariableTypes.STRING,
          value: '',
        },
      ],
    });
    setReady(true);
  }, [props]);

  useEffect(() => {
    if (!ready) {
      return;
    }
    props.onReady({ id, responses: [] });
  }, [ready]);
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
          id: `Selected`,
          key: 'Selected',
          type: CapiVariableTypes.BOOLEAN,
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
          id: `Selected`,
          key: 'Selected',
          type: CapiVariableTypes.BOOLEAN,
          value: false,
        },
      ],
    });
  }

  useEffect(() => {
    //TODO commenting for now. Need to revisit once state structure logic is in place
    //handleStateChange(state);
  }, [state]);

  const handleStateChange = (stateData: CapiVariable[]) => {
    // override various things from state
    const CapiVariables: any = {
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
        CapiVariables.btnTitle = stateVar.value as string;
        isTitleSet = true;
      }
      if (stateVar.key === 'buttonTitles') {
        setButtonTitle(stateVar.value[0]);
        CapiVariables.btnTitle = stateVar.value[0];
        isTitleSet = true;
      }
      if (stateVar.key === 'Selected') {
        const boolSelected: boolean = parseBool(stateVar.value);
        setButtonSelected(boolSelected);
        CapiVariables.btnSelected = boolSelected;
      }
      if (stateVar.key === 'visible') {
        setButtonVisible(stateVar.value);
        CapiVariables.btnVisible = stateVar.value;
      }
      if (stateVar.key === 'enabled') {
        const boolEnabled: boolean = parseBool(stateVar.value);
        setbuttonEnabled(boolEnabled);
        CapiVariables.btnEnabled = boolEnabled;
      }
      if (stateVar.key === 'textColor') {
        setButtonTextColor(stateVar.value);
        CapiVariables.btnTextColor = stateVar.value;
      }
      if (stateVar.key === 'accessibilityText') {
        setAccessibilityText(stateVar.value as string);
        CapiVariables.btnaccessibilityText = stateVar.value as string;
      }
      if (stateVar.key === 'backgroundColor') {
        console.log({ backgroundColor: stateVar.value });

        setBackgroundColor(stateVar.value);
        CapiVariables.btnBackgroundColor = stateVar.value;
      }
      if (stateVar.key === 'transparent') {
        setButtonTransparent(stateVar.value);
        CapiVariables.btnTransparent = stateVar.value;
      }
    });
    if (!isTitleSet) {
      setButtonTitle(title);
      CapiVariables.btnTitle = title;
    }
  };

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
