/* eslint-disable react/prop-types */
import {
  NotificationType,
  subscribeToNotification,
} from '../../../apps/delivery/components/NotificationContext';
import React, { CSSProperties, useCallback, useEffect, useState } from 'react';
import { parseBool } from 'utils/common';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import { CapiVariable } from '../types/parts';

const Dropdown: React.FC<any> = (props) => {
  const [state, setState] = useState<any[]>(Array.isArray(props.state) ? props.state : []);
  const [model, setModel] = useState<any>(Array.isArray(props.model) ? props.model : {});
  const [ready, setReady] = useState<boolean>(false);
  const id: string = props.id;

  const [enabled, setEnabled] = useState(true);
  const [selection, setSelection] = useState<number>(-1);
  const [selectedItem, setSelectedItem] = useState<string>('');
  const [cssClass, setCssClass] = useState('');

  const initialize = useCallback(async (pModel) => {
    // set defaults
    const dEnabled = typeof pModel.enabled === 'boolean' ? pModel.enabled : enabled;
    setEnabled(dEnabled);

    const dCssClass = pModel.customCssClass || '';
    setCssClass(dCssClass);

    const initResult = await props.onInit({
      id,
      responses: [
        {
          key: 'enabled',
          type: CapiVariableTypes.BOOLEAN,
          value: dEnabled,
        },
        {
          key: 'customCssClass',
          type: CapiVariableTypes.STRING,
          value: dCssClass,
        },
        {
          id: `selectedIndex`,
          key: 'selectedIndex',
          type: CapiVariableTypes.STRING,
          value: -1,
        },
        {
          id: `selectedItem`,
          key: 'selectedItem',
          type: CapiVariableTypes.STRING,
          value: '',
        },
        {
          id: `value`,
          key: 'value',
          type: CapiVariableTypes.STRING,
          value: 'NULL',
        },
      ],
    });

    // result of init has a state snapshot with latest (init state applied)
    const currentStateSnapshot = initResult.snapshot;

    const sEnabled = currentStateSnapshot[`stage.${id}.enabled`];
    if (sEnabled !== undefined) {
      setEnabled(sEnabled);
    }

    const sCssClass = currentStateSnapshot[`stage.${id}.customCssClass`];
    if (sCssClass !== undefined) {
      setCssClass(sCssClass);
    }

    // TODO: value ??

    const sSelectedIndex = currentStateSnapshot[`stage.${id}.selectedIndex`];
    if (sSelectedIndex !== undefined) {
      const stateSelection = Number(sSelectedIndex);
      setSelection(stateSelection);
      if (optionLabels) setSelectedItem(optionLabels[stateSelection - 1]);
    }

    const sSelectedItem = currentStateSnapshot[`stage.${id}.selectedItem`];
    if (sSelectedItem !== undefined) {
      const selectionIndex: number = optionLabels?.findIndex((str: string) =>
        sSelectedItem.includes(str),
      );
      setSelectedItem(sSelectedItem);
      setSelection(selectionIndex + 1);
    }
    if (initResult.historyMode) {
      setEnabled(false);
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

  const {
    x,
    y,
    z,
    width,
    height,
    customCssClass,
    showLabel,
    label,
    prompt,
    optionLabels,
    palette,
  } = model;

  const dropdownContainerStyles: CSSProperties = {
    position: 'absolute',
    top: y,
    left: x,
    width,
    // height,
    zIndex: z,
  };
  if (palette) {
    dropdownContainerStyles.borderWidth = `${
      palette?.lineThickness ? palette?.lineThickness + 'px' : '1px'
    }`;
    (dropdownContainerStyles.borderStyle = 'solid'),
      (dropdownContainerStyles.borderColor = 'transparent'),
      (dropdownContainerStyles.backgroundColor = 'transparent');
  }

  const dropDownStyle: CSSProperties = {
    width: 'auto',
    height: 'auto',
  };
  if (!(showLabel && label)) {
    dropDownStyle.width = `${Number(width) - 10}px`;
  }
  if (showLabel && label && width) {
    //is this the best way to handle?
    //if lable is visible then need to set the maxWidth otherwise it gets out of the container
    dropDownStyle.maxWidth = `${Number(width * 0.63)}px`;
  }

  useEffect(() => {
    //TODO commenting for now. Need to revisit once state structure logic is in place
    //handleStateChange(state);
  }, [state]);

  const saveState = ({
    selectedIndex,
    selectedItem,
    value,
    enabled,
  }: {
    selectedIndex: number;
    selectedItem: string;
    value: string;
    enabled: boolean;
  }) => {
    props.onSave({
      id: `${id}`,
      responses: [
        {
          key: 'enabled',
          type: CapiVariableTypes.BOOLEAN,
          value: enabled,
        },
        {
          key: 'selectedIndex',
          type: CapiVariableTypes.NUMBER,
          value: selectedIndex,
        },
        {
          key: 'selectedItem',
          type: CapiVariableTypes.STRING,
          value: selectedItem,
        },
        {
          key: 'value',
          type: CapiVariableTypes.STRING,
          value: value,
        },
      ],
    });
  };

  const handleChange = (event: any) => {
    const val = Number(event.target.value);
    // Update/set the value
    setSelection(val);
    saveState({
      selectedIndex: val,
      selectedItem: event.target.options[event.target.selectedIndex].text,
      value: event.target.options[event.target.selectedIndex].text,
      enabled,
    });
  };

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
        /* console.log(`${notificationType.toString()} notification handled [Dropdown]`, payload); */
        switch (notificationType) {
          case NotificationType.CHECK_STARTED:
            // nothing to do
            break;
          case NotificationType.CHECK_COMPLETE:
            // nothing to do
            // TODO: highlight incorrect?
            break;
          case NotificationType.STATE_CHANGED:
            {
              const { mutateChanges: changes } = payload;
              const sSelectedIndex = changes[`stage.${id}.selectedIndex`];
              if (sSelectedIndex !== undefined) {
                const stateSelection = Number(sSelectedIndex);
                if (selection !== stateSelection) {
                  setSelection(stateSelection);
                  setSelectedItem(optionLabels[stateSelection - 1]);
                }
                props.onSave({
                  id: `${id}`,
                  responses: [
                    {
                      key: 'selectedIndex',
                      type: CapiVariableTypes.NUMBER,
                      value: sSelectedIndex,
                    },
                  ],
                });
              }

              const sSelectedItem = changes[`stage.${id}.selectedItem`];
              if (sSelectedItem !== undefined) {
                if (selectedItem !== sSelectedItem) {
                  const selectionIndex: number = optionLabels.findIndex((str: any) =>
                    sSelectedItem.includes(str),
                  );
                  setSelectedItem(sSelectedItem);
                  setSelection(selectionIndex + 1);
                }
              }

              const sEnabled = changes[`stage.${id}.enabled`];
              if (sEnabled !== undefined) {
                setEnabled(parseBool(sEnabled));
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
  }, [props.notify, optionLabels]);

  // Generate a list of options using optionLabels
  const dropdownOptions = () => {
    // use explicit Array() since we're using Elements
    const options = [];

    if (prompt) {
      // If a prompt exists and the selectedIndex is not set or is set to -1, set prompt as disabled first option
      options.push(
        <option key="-1" value="-1" disabled>
          {prompt}
        </option>,
      );
    } else {
      // If a prompt is blank and the selectedIndex is not set or is set to -1, set empty first option
      options.push(<option key="-1" value="-1"></option>);
    }
    if (optionLabels) {
      for (let i = 0; i < optionLabels.length; i++) {
        // Set selected if selectedIndex equals current index
        options.push(
          <option key={i + 1} value={i + 1} selected={i + 1 === selection}>
            {optionLabels[i]}
          </option>,
        );
      }
    }
    return options;
  };

  return ready ? (
    <div data-janus-type={props.type} className="dropdown-input" style={dropdownContainerStyles}>
      <label htmlFor={id}>{showLabel && label ? label : ''}</label>
      <select
        style={dropDownStyle}
        id={id}
        value={selection}
        className={'dropdown ' + cssClass}
        onChange={handleChange}
        disabled={!enabled}
      >
        {dropdownOptions()}
      </select>
    </div>
  ) : null;
};

export const tagName = 'janus-dropdown';

export default Dropdown;
