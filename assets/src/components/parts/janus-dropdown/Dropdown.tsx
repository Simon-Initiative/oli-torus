/* eslint-disable react/prop-types */
import React, { CSSProperties, useCallback, useEffect, useState } from 'react';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import {
  NotificationType,
  subscribeToNotification,
} from '../../../apps/delivery/components/NotificationContext';
import { contexts } from '../../../types/applicationContext';
import { parseBool } from '../../../utils/common';
import { PartComponentProps } from '../types/parts';
import { DropdownModel } from './schema';

const Dropdown: React.FC<PartComponentProps<DropdownModel>> = (props) => {
  const [state, setState] = useState<any[]>(Array.isArray(props.state) ? props.state : []);
  const [model, setModel] = useState<any>(Array.isArray(props.model) ? props.model : {});
  const [ready, setReady] = useState<boolean>(false);
  const id: string = props.id;

  const [enabled, setEnabled] = useState(true);
  const [selectedIndex, setSelectedIndex] = useState<number>(-1);
  const [selectedItem, setSelectedItem] = useState<string>('');
  const [_cssClass, setCssClass] = useState('');
  const [liveAnnouncement, setLiveAnnouncement] = useState('');

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
          type: CapiVariableTypes.NUMBER,
          value: selectedIndex,
        },
        {
          id: `selectedItem`,
          key: 'selectedItem',
          type: CapiVariableTypes.STRING,
          value: selectedItem,
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
    if (sSelectedIndex !== undefined && Number(sSelectedIndex) !== -1) {
      const stateSelection = Number(sSelectedIndex);
      setSelectedIndex(stateSelection);
      if (pModel.optionLabels) {
        setSelectedItem(pModel.optionLabels[stateSelection - 1]);
        setTimeout(() => {
          saveState({
            selectedIndex: stateSelection,
            selectedItem: pModel.optionLabels[stateSelection - 1],
            value: pModel.optionLabels[stateSelection - 1],
            enabled,
          });
        });
      }
    }

    const sSelectedItem = currentStateSnapshot[`stage.${id}.selectedItem`];
    if (sSelectedItem !== undefined && sSelectedItem !== '') {
      const selectionIndex: number = pModel.optionLabels?.findIndex((str: string) =>
        sSelectedItem.includes(str),
      );
      setSelectedItem(sSelectedItem);
      setSelectedIndex(selectionIndex + 1);
      setTimeout(() => {
        saveState({
          selectedIndex: selectionIndex + 1,
          selectedItem: sSelectedItem,
          value: sSelectedItem,
          enabled,
        });
      });
    }
    //Instead of hardcoding REVIEW, we can make it an global interface and then importa that here.
    if (initResult.context.mode === contexts.REVIEW) {
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

  const { width, height, showLabel, label, prompt, optionLabels } = model;

  useEffect(() => {
    const styleChanges: any = {};
    if (width !== undefined) {
      styleChanges.width = { value: width as number };
    }
    if (height != undefined) {
      styleChanges.height = { value: height as number };
    }

    props.onResize({ id: `${id}`, settings: styleChanges });
  }, [width, height]);

  const resolvedWidth =
    typeof width === 'number'
      ? width
      : typeof width === 'string' && width.trim() !== ''
      ? Number(width)
      : undefined;

  const dropdownContainerStyles: CSSProperties = {
    width: resolvedWidth ? `${resolvedWidth}px` : 'auto',
    position: 'relative',
    display: 'inline-flex',
    flexDirection: 'column',
    gap: '4px',
  };

  const dropDownStyle: CSSProperties = {
    width: '100%',
    height: 'auto',
    minHeight: '42px',
  };

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

  const totalOptions = Array.isArray(optionLabels) ? optionLabels.length : 0;

  const handleSelectChange = (event: React.ChangeEvent<HTMLSelectElement>) => {
    const value = event.target.value;
    const newIndex = Number(value);

    if (newIndex === -1) {
      // Prompt option selected, don't update state
      return;
    }

    if (!optionLabels || newIndex < 1 || newIndex > optionLabels.length) {
      return;
    }

    const optionLabel = optionLabels[newIndex - 1];
    setSelectedIndex(newIndex);
    setSelectedItem(optionLabel);
    setLiveAnnouncement(`${optionLabel} selected ${newIndex} of ${totalOptions}`);
    saveState({
      selectedIndex: newIndex,
      selectedItem: optionLabel,
      value: optionLabel,
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
                if (selectedIndex !== stateSelection) {
                  setSelectedIndex(stateSelection);
                  setSelectedItem(optionLabels[stateSelection - 1]);
                  setTimeout(() => {
                    saveState({
                      selectedIndex: stateSelection,
                      selectedItem: optionLabels[stateSelection - 1],
                      value: optionLabels[stateSelection - 1],
                      enabled,
                    });
                  });
                }
              }

              const sSelectedItem = changes[`stage.${id}.selectedItem`];
              if (sSelectedItem !== undefined) {
                if (selectedItem !== sSelectedItem) {
                  const selectionIndex: number = optionLabels.findIndex((str: any) =>
                    sSelectedItem.includes(str),
                  );
                  setSelectedItem(sSelectedItem);
                  setSelectedIndex(selectionIndex + 1);
                  setTimeout(() => {
                    saveState({
                      selectedIndex: selectionIndex + 1,
                      selectedItem: sSelectedItem,
                      value: sSelectedItem,
                      enabled,
                    });
                  });
                }
              }

              const sEnabled = changes[`stage.${id}.enabled`];
              if (sEnabled !== undefined) {
                setEnabled(parseBool(sEnabled));
              }
            }
            break;
          case NotificationType.CONTEXT_CHANGED:
            {
              const { initStateFacts: changes } = payload;

              const sSelectedIndex = changes[`stage.${id}.selectedIndex`];
              if (sSelectedIndex !== undefined) {
                const stateSelection = Number(sSelectedIndex);
                if (selectedIndex !== stateSelection || stateSelection === -1) {
                  setSelectedIndex(stateSelection);
                  setSelectedItem(optionLabels[stateSelection - 1]);
                  setTimeout(() => {
                    saveState({
                      selectedIndex: stateSelection,
                      selectedItem: optionLabels[stateSelection - 1],
                      value: optionLabels[stateSelection - 1],
                      enabled,
                    });
                  });
                }
              }

              const sSelectedItem = changes[`stage.${id}.selectedItem`];
              if (sSelectedItem !== undefined) {
                if (selectedItem !== sSelectedItem) {
                  const selectionIndex: number = optionLabels.findIndex((str: any) =>
                    sSelectedItem.includes(str),
                  );
                  setSelectedItem(sSelectedItem);
                  setSelectedIndex(selectionIndex + 1);
                  setTimeout(() => {
                    saveState({
                      selectedIndex: selectionIndex + 1,
                      selectedItem: sSelectedItem,
                      value: sSelectedItem,
                      enabled,
                    });
                  });
                }
              }

              const sEnabled = changes[`stage.${id}.enabled`];
              if (sEnabled !== undefined) {
                setEnabled(parseBool(sEnabled));
              }
              if (payload.mode === contexts.REVIEW) {
                setEnabled(false);
              }
            }
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

  const containerStyle: CSSProperties = {
    ...dropdownContainerStyles,
    position: 'relative',
  };

  const srOnlyStyle: CSSProperties = {
    position: 'absolute',
    width: '1px',
    height: '1px',
    padding: 0,
    margin: '-1px',
    overflow: 'hidden',
    clip: 'rect(0, 0, 0, 0)',
    border: 0,
  };

  return ready ? (
    <div data-janus-type={tagName} className="dropdown-input" style={containerStyle}>
      <span className="sr-only" style={srOnlyStyle} role="status" aria-live="polite">
        {liveAnnouncement}
      </span>
      {showLabel && label ? <label htmlFor={`${id}-select`}>{label}</label> : null}
      <select
        id={`${id}-select`}
        className="dropdown"
        style={dropDownStyle}
        value={selectedIndex > 0 ? selectedIndex : -1}
        disabled={!enabled}
        onChange={handleSelectChange}
      >
        {prompt ? (
          <option value="-1" style={{ display: 'none' }}>
            {prompt}
          </option>
        ) : null}
        {optionLabels?.map((optionLabel: string, index: number) => (
          <option key={index + 1} value={index + 1}>
            {optionLabel}
          </option>
        ))}
      </select>
    </div>
  ) : null;
};

export const tagName = 'janus-dropdown';

export default Dropdown;
