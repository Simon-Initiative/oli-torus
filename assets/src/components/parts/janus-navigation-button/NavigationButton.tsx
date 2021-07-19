/* eslint-disable react/prop-types */
import React, { CSSProperties, useCallback, useEffect, useState } from 'react';
import { contexts, parseBoolean } from '../../../utils/common';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import {
  NotificationType,
  subscribeToNotification,
} from '../../../apps/delivery/components/NotificationContext';
import { JanusAbsolutePositioned, JanusCustomCss, PartComponentProps } from '../types/parts';

interface NavigationButtonModel extends JanusAbsolutePositioned, JanusCustomCss {
  textColor?: string;
  buttonColor?: string;
  visible?: boolean;
  enabled?: boolean;
  ariaLabel?: string;
  transparent?: boolean;
  selected?: boolean;
}

const NavigationButton: React.FC<PartComponentProps<NavigationButtonModel>> = (props) => {
  const [state, setState] = useState<any[]>(Array.isArray(props.state) ? props.state : []);
  const [model, setModel] = useState<any>(Array.isArray(props.model) ? props.model : {});
  const [ready, setReady] = useState<boolean>(false);
  const id: string = props.id;

  const [buttonSelected, setButtonSelected] = useState(false);
  const [buttonTextColor, setButtonTextColor] = useState('');
  const [accessibilityText, setAccessibilityText] = useState('');
  const [backgroundColor, setBackgroundColor] = useState('');
  const [buttonVisible, setButtonVisible] = useState(true);
  // BS: why isn't transparent a bool?
  const [buttonTransparent, setButtonTransparent] = useState('');
  const [buttonEnabled, setButtonEnabled] = useState(true);
  const [buttonTitle, setButtonTitle] = useState('');
  const [cssClass, setCssClass] = useState('');

  const initialize = useCallback(async (pModel) => {
    // set defaults
    const dEnabled = typeof pModel.enabled === 'boolean' ? pModel.enabled : enabled;
    setButtonEnabled(dEnabled);

    const dVisible = typeof pModel.visible === 'boolean' ? pModel.visible : buttonVisible;
    setButtonVisible(dVisible);

    const dCssClass = pModel.customCssClass || '';
    setCssClass(dCssClass);

    const dTitle = pModel.title || '';
    setButtonTitle(dTitle);

    const dAccessibilityText = pModel.ariaLabel || accessibilityText;
    setAccessibilityText(dAccessibilityText);

    const dSelected = parseBoolean(pModel.selected);
    setButtonSelected(dSelected);

    const dBackgroundColor = pModel.buttonColor || '';
    setBackgroundColor(dBackgroundColor);

    const dButtonTextColor = pModel.textColor || '';
    setButtonTextColor(dButtonTextColor);

    const dTransparent = pModel.transparent || '';
    setButtonTransparent(dTransparent);

    const initResult = await props.onInit({
      id,
      responses: [
        {
          key: 'Selected',
          type: CapiVariableTypes.BOOLEAN,
          value: dSelected,
        },
        {
          key: 'selected',
          type: CapiVariableTypes.BOOLEAN,
          value: dSelected,
        },
        {
          key: 'visible',
          type: CapiVariableTypes.BOOLEAN,
          value: dVisible,
        },
        {
          key: 'enabled',
          type: CapiVariableTypes.BOOLEAN,
          value: dEnabled,
        },
        {
          key: 'title',
          type: CapiVariableTypes.STRING,
          value: dTitle,
        },
        {
          key: 'textColor',
          type: CapiVariableTypes.STRING,
          value: dButtonTextColor,
        },
        {
          key: 'backgroundColor',
          type: CapiVariableTypes.STRING,
          value: dBackgroundColor,
        },
        {
          key: 'transparent',
          type: CapiVariableTypes.STRING,
          value: dTransparent,
        },
        {
          key: 'accessibilityText',
          type: CapiVariableTypes.STRING,
          value: dAccessibilityText,
        },
        {
          key: 'customCssClass',
          type: CapiVariableTypes.STRING,
          value: dCssClass,
        },
      ],
    });

    // result of init has a state snapshot with latest (init state applied)
    const currentStateSnapshot = initResult.snapshot;
    const sEnabled = currentStateSnapshot[`stage.${id}.enabled`];
    if (sEnabled !== undefined) {
      setButtonEnabled(sEnabled);
    }
    const sCssClass = currentStateSnapshot[`stage.${id}.customCssClass`];
    if (sCssClass !== undefined) {
      setCssClass(sCssClass);
    }
    const sVisible = currentStateSnapshot[`stage.${id}.visible`];
    if (sVisible !== undefined) {
      setButtonVisible(sVisible);
    }

    const sTitle = currentStateSnapshot[`stage.${id}.title`];
    if (sTitle !== undefined) {
      setButtonTitle(sTitle);
    }

    const sAccessibilityText = currentStateSnapshot[`stage.${id}.ariaLabel`];
    if (sAccessibilityText !== undefined) {
      setAccessibilityText(sAccessibilityText);
    }

    let sSelected = currentStateSnapshot[`stage.${id}.Selected`];
    if (sSelected === undefined) {
      sSelected = currentStateSnapshot[`stage.${id}.selected`];
    }
    if (sSelected !== undefined) {
      setButtonSelected(parseBoolean(sSelected));
    }

    const sBackgroundColor = currentStateSnapshot[`stage.${id}.buttonColor`];
    if (sBackgroundColor !== undefined) {
      setBackgroundColor(sBackgroundColor);
    }

    const sButtonTextColor = currentStateSnapshot[`stage.${id}.textColor`];
    if (sButtonTextColor !== undefined) {
      setButtonTextColor(sButtonTextColor);
    }

    const sTransparent = currentStateSnapshot[`stage.${id}.transparent`];
    if (sTransparent !== undefined) {
      setButtonTransparent(sTransparent);
    }
    //Instead of hardcoding REVIEW, we can make it an global interface and then importa that here.
    if (initResult.context.mode === contexts.REVIEW) {
      setButtonEnabled(false);
    }
    setReady(true);
  }, []);

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
    initialize(pModel);
  }, [props]);

  useEffect(() => {
    if (!ready) {
      return;
    }
    props.onReady({ id, responses: [] });
  }, [ready]);

  useEffect(() => {
    if (!props.notify) {
      return;
    }
    const notificationsHandled = [
      NotificationType.CHECK_STARTED,
      NotificationType.CHECK_COMPLETE,
      NotificationType.CONTEXT_CHANGED,
      NotificationType.STATE_CHANGED,
    ];
    const notifications = notificationsHandled.map((notificationType: NotificationType) => {
      const handler = (payload: any) => {
        /* console.log(`${notificationType.toString()} notification handled [Nav Button]`, payload); */
        switch (notificationType) {
          case NotificationType.CHECK_STARTED:
            // nothing to do
            break;
          case NotificationType.CHECK_COMPLETE:
            // nothing to do
            break;
          case NotificationType.STATE_CHANGED:
            {
              const { mutateChanges: changes } = payload;
              const sTitle = changes[`stage.${id}.title`];
              if (sTitle !== undefined) {
                setButtonTitle(sTitle);
              }

              const sTitles = changes[`stage.${id}.buttonTitles`];
              if (sTitles !== undefined) {
                setButtonTitle(sTitles[0]);
              }

              let sSelected = changes[`stage.${id}.Selected`];
              if (sSelected === undefined) {
                sSelected = changes[`stage.${id}.selected`];
              }
              if (sSelected !== undefined) {
                setButtonSelected(parseBoolean(sSelected));
              }

              const sVisible = changes[`stage.${id}.visible`];
              if (sVisible !== undefined) {
                setButtonVisible(sVisible);
              }

              const sEnabled = changes[`stage.${id}.enabled`];
              if (sEnabled !== undefined) {
                setButtonEnabled(sEnabled);
              }

              const sButtonTextColor = changes[`stage.${id}.textColor`];
              if (sButtonTextColor !== undefined) {
                setButtonTextColor(sButtonTextColor);
              }

              const sAccessibilityText = changes[`stage.${id}.accessibilityText`];
              if (sAccessibilityText !== undefined) {
                setAccessibilityText(sAccessibilityText);
              }

              const sBackgroundColor = changes[`stage.${id}.backgroundColor`];
              if (sBackgroundColor !== undefined) {
                setBackgroundColor(sBackgroundColor);
              }

              const sTransparent = changes[`stage.${id}.transparent`];
              if (sTransparent !== undefined) {
                setButtonTransparent(sTransparent);
              }
            }
            break;
          case NotificationType.CONTEXT_CHANGED:
            // nothing to do
            break;
        }
      };
      const unsub = subscribeToNotification(props.notify, notificationType, handler);
      return unsub;
    });
    return () => {
      notifications.forEach((unsub) => {
        unsub();
      });
    };
  }, [props.notify]);

  const {
    title,
    x = 0,
    y = 0,
    z = 0,
    width,
    height,
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
      responses: [
        {
          key: 'Selected',
          type: CapiVariableTypes.BOOLEAN,
          value: true,
        },
        {
          key: 'selected',
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
      responses: [
        {
          key: 'Selected',
          type: CapiVariableTypes.BOOLEAN,
          value: false,
        },
        {
          key: 'selected',
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

  const buttonProps = {
    title: buttonTitle,
    onClick: handleButtonPress,
    'aria-label': ariaLabel,
    disabled: !buttonEnabled,
    className: `${cssClass}`,
  };

  return ready && buttonVisible ? (
    <button data-janus-type={props.type} {...buttonProps} style={styles}>
      {title}
    </button>
  ) : null;
};

export const tagName = 'janus-navigation-button';

export default NavigationButton;
