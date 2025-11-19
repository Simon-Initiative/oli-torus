/* eslint-disable react/prop-types */
import React, { CSSProperties, useCallback, useEffect, useMemo, useRef, useState } from 'react';
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
  const buttonRef = useRef<HTMLButtonElement | null>(null);
  const listboxRef = useRef<HTMLDivElement | null>(null);
  const [isOpen, setIsOpen] = useState(false);
  const [highlightedIndex, setHighlightedIndex] = useState(-1);
  const [liveMessage, setLiveMessage] = useState('');

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

  useEffect(() => {
    //TODO commenting for now. Need to revisit once state structure logic is in place
    //handleStateChange(state);
  }, [state]);

  const totalOptions = Array.isArray(optionLabels) ? optionLabels.length : 0;
  const hasOptions = totalOptions > 0;
  const buttonId = `${id}-dropdown-button`;
  const listboxId = `${id}-dropdown-listbox`;
  const labelId = `${id}-label`;
  const hasVisibleLabel = Boolean(showLabel && label);
  const fallbackLabel = label || prompt || 'Dropdown';
  const activeDescendantId =
    highlightedIndex >= 0 ? `${id}-option-${highlightedIndex}` : undefined;

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

  const closeDropdown = useCallback(
    (focusButton = true) => {
      setIsOpen(false);
      setHighlightedIndex(-1);
      if (focusButton) {
        requestAnimationFrame(() => buttonRef.current?.focus());
      }
    },
    [buttonRef],
  );

  const handleSelect = useCallback(
    (optionIdx: number) => {
      if (!optionLabels || optionIdx < 0 || optionIdx >= optionLabels.length) {
        return;
      }
      const optionLabel = optionLabels[optionIdx];
      const newIndex = optionIdx + 1;
      setSelectedIndex(newIndex);
      setSelectedItem(optionLabel);
      setLiveMessage(`${optionLabel}, option ${newIndex} of ${totalOptions} selected`);
      saveState({
        selectedIndex: newIndex,
        selectedItem: optionLabel,
        value: optionLabel,
        enabled,
      });
      closeDropdown();
    },
    [optionLabels, closeDropdown, enabled, saveState, totalOptions],
  );

  const openDropdown = useCallback(() => {
    if (!enabled || !hasOptions) {
      return;
    }
    setIsOpen(true);
  }, [enabled, hasOptions]);

  const toggleDropdown = useCallback(() => {
    if (isOpen) {
      closeDropdown();
    } else {
      openDropdown();
    }
  }, [closeDropdown, openDropdown, isOpen]);

  const handleButtonKeyDown = (event: React.KeyboardEvent<HTMLButtonElement>) => {
    switch (event.key) {
      case 'ArrowDown':
      case 'ArrowUp':
        event.preventDefault();
        if (!isOpen) {
          openDropdown();
        }
        break;
      case 'Enter':
      case ' ':
        event.preventDefault();
        toggleDropdown();
        break;
      case 'Escape':
        if (isOpen) {
          event.preventDefault();
          closeDropdown();
        }
        break;
      default:
        break;
    }
  };

  const handleListboxKeyDown = (event: React.KeyboardEvent<HTMLDivElement>) => {
    if (!optionLabels || !optionLabels.length) {
      return;
    }
    switch (event.key) {
      case 'ArrowDown':
        event.preventDefault();
        setHighlightedIndex((prev) => {
          if (prev < 0) {
            return 0;
          }
          return (prev + 1) % optionLabels.length;
        });
        break;
      case 'ArrowUp':
        event.preventDefault();
        setHighlightedIndex((prev) => {
          if (prev < 0) {
            return optionLabels.length - 1;
          }
          return (prev - 1 + optionLabels.length) % optionLabels.length;
        });
        break;
      case 'Home':
        event.preventDefault();
        setHighlightedIndex(0);
        break;
      case 'End':
        event.preventDefault();
        setHighlightedIndex(optionLabels.length - 1);
        break;
      case 'Enter':
      case ' ':
        event.preventDefault();
        if (highlightedIndex >= 0) {
          handleSelect(highlightedIndex);
        }
        break;
      case 'Escape':
        event.preventDefault();
        closeDropdown();
        break;
      case 'Tab':
        closeDropdown(false);
        break;
      default:
        break;
    }
  };

  useEffect(() => {
    if (!isOpen) {
      return;
    }
    const initialIndex =
      selectedIndex > 0 && totalOptions > 0
        ? Math.min(selectedIndex - 1, totalOptions - 1)
        : totalOptions > 0
        ? 0
        : -1;
    setHighlightedIndex(initialIndex);
    const focusTimer = requestAnimationFrame(() => {
      listboxRef.current?.focus();
    });
    return () => cancelAnimationFrame(focusTimer);
  }, [isOpen, selectedIndex, totalOptions]);

  useEffect(() => {
    if (!isOpen || highlightedIndex < 0 || !optionLabels || !optionLabels.length) {
      return;
    }
    const optionLabel = optionLabels[highlightedIndex];
    setLiveMessage(`${optionLabel}, option ${highlightedIndex + 1} of ${totalOptions}`);
  }, [isOpen, highlightedIndex, optionLabels, totalOptions]);

  useEffect(() => {
    if (!isOpen) {
      return;
    }
    const handleClickOutside = (event: MouseEvent) => {
      if (
        buttonRef.current &&
        !buttonRef.current.contains(event.target as Node) &&
        listboxRef.current &&
        !listboxRef.current.contains(event.target as Node)
      ) {
        closeDropdown(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, [isOpen, closeDropdown]);

  const displayText = useMemo(() => {
    if (selectedIndex > 0 && optionLabels && optionLabels[selectedIndex - 1]) {
      return optionLabels[selectedIndex - 1];
    }
    if (selectedItem) {
      return selectedItem;
    }
    if (prompt) {
      return prompt;
    }
    return 'Select an option';
  }, [selectedIndex, optionLabels, selectedItem, prompt]);

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

  // Generate a list of options using optionLabels
  const optionList = useMemo(() => {
    if (!optionLabels || !optionLabels.length) {
      return null;
    }

    return optionLabels.map((optionLabel: string, index: number) => {
      const optionId = `${id}-option-${index}`;
      const isSelected = selectedIndex === index + 1;
      const isActive = highlightedIndex === index;
      const optionClassNames = ['dropdown-option'];
      if (isSelected) {
        optionClassNames.push('dropdown-option--selected');
      }
      if (isActive) {
        optionClassNames.push('dropdown-option--active');
      }
      const optionStyles: CSSProperties = {
        padding: '6px 8px',
        cursor: 'pointer',
        backgroundColor: isActive
          ? 'var(--dropdown-option-active-bg, #e6f0ff)'
          : isSelected
          ? 'var(--dropdown-option-selected-bg, #f5f5f5)'
          : 'transparent',
      };

      return (
        <div
          key={optionId}
          id={optionId}
          role="option"
          aria-selected={isSelected ? 'true' : undefined}
          aria-posinset={index + 1}
          aria-setsize={totalOptions}
          className={optionClassNames.join(' ')}
          onMouseDown={(event) => event.preventDefault()}
          onClick={() => handleSelect(index)}
          onMouseEnter={() => setHighlightedIndex(index)}
          style={optionStyles}
        >
          {optionLabel}
        </div>
      );
    });
  }, [optionLabels, selectedIndex, highlightedIndex, totalOptions, handleSelect, id]);

  const triggerStyle: CSSProperties = {
    ...dropDownStyle,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    border: '1px solid var(--dropdown-border, #ced4da)',
    borderRadius: 4,
    backgroundColor: '#fff',
    padding: '6px 12px',
    paddingRight: '36px',
    fontSize: 'inherit',
    lineHeight: 1.4,
    textAlign: 'left',
    cursor: enabled ? 'pointer' : 'not-allowed',
    appearance: 'none',
    position: 'relative',
    boxSizing: 'border-box',
  };

  const listboxStyle: CSSProperties = {
    position: 'absolute',
    top: '100%',
    left: 0,
    width: dropDownStyle.width && dropDownStyle.width !== 'auto' ? dropDownStyle.width : '100%',
    maxHeight: 200,
    overflowY: 'auto',
    backgroundColor: '#fff',
    border: '1px solid var(--color-border, #ccc)',
    marginTop: 4,
    zIndex: 5,
    boxShadow: '0 2px 6px rgba(0, 0, 0, 0.15)',
  };

  const containerStyle: CSSProperties = {
    ...dropdownContainerStyles,
    position: 'relative',
  };

  return ready ? (
    <div data-janus-type={tagName} className="dropdown-input" style={containerStyle}>
      <div aria-live="polite" className="screenreader-text" style={srOnlyStyle}>
        {liveMessage}
      </div>
      {showLabel && label ? (
        <label id={labelId} htmlFor={buttonId}>
          {label}
        </label>
      ) : null}
      <button
        type="button"
        id={buttonId}
        ref={buttonRef}
        className="dropdown"
        style={triggerStyle}
        aria-haspopup="listbox"
        aria-expanded={isOpen}
        aria-controls={isOpen ? listboxId : undefined}
        aria-labelledby={hasVisibleLabel ? labelId : undefined}
        aria-label={!hasVisibleLabel ? fallbackLabel : undefined}
        disabled={!enabled}
        onClick={toggleDropdown}
        onKeyDown={handleButtonKeyDown}
      >
        <span>{displayText}</span>
      </button>
      {isOpen && hasOptions ? (
        <div
          id={listboxId}
          role="listbox"
          ref={listboxRef}
          tabIndex={-1}
          aria-activedescendant={activeDescendantId}
          aria-labelledby={hasVisibleLabel ? labelId : undefined}
          className="dropdown-listbox"
          style={listboxStyle}
          onKeyDown={handleListboxKeyDown}
        >
          {optionList}
        </div>
      ) : null}
    </div>
  ) : null;
};

export const tagName = 'janus-dropdown';

export default Dropdown;
