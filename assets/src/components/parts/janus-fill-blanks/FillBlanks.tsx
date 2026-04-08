import React, { CSSProperties, useCallback, useEffect, useRef, useState } from 'react';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import {
  NotificationType,
  subscribeToNotification,
} from '../../../apps/delivery/components/NotificationContext';
import { contexts } from '../../../types/applicationContext';
import { usePrevious } from '../../hooks/usePrevious';
import { PartComponentProps } from '../types/parts';
import './FillBlanks.scss';
import { FIBModel } from './schema';

export const parseBool = (val: any) => {
  // cast value to number
  const num: number = +val;
  return !isNaN(num) ? !!num : !!String(val).toLowerCase().replace('false', '');
};
interface SelectOption {
  key: string;
  value: string;
}

interface FibDropdownOption {
  id: string;
  text: string;
}

interface FibDropdownProps {
  name: string;
  value: string;
  options: FibDropdownOption[];
  disabled: boolean;
  ariaLabel: string;
  displayClass: string;
  onSelect: (name: string, value: string, displayText: string) => void;
}

const FibDropdown: React.FC<FibDropdownProps> = ({
  name,
  value,
  options,
  disabled,
  ariaLabel,
  displayClass,
  onSelect,
}) => {
  const [isOpen, setIsOpen] = useState(false);
  const containerRef = useRef<HTMLSpanElement>(null);
  const responsiveItemRef = useRef<HTMLElement | null>(null);
  const previousResponsiveItemZIndexRef = useRef<string>('');
  const selectedIndex = options.findIndex((o) => o.id === value);
  const [highlightedIndex, setHighlightedIndex] = useState<number>(
    selectedIndex >= 0 ? selectedIndex : 0,
  );

  // Stable IDs for ARIA relationships
  const listboxId = `fib-listbox-${name}`;
  const getOptionId = (optId: string) => `${listboxId}-opt-${optId}`;
  const activeDescendant =
    isOpen && options[highlightedIndex]
      ? getOptionId(options[highlightedIndex].id)
      : value
      ? getOptionId(value)
      : undefined;

  const selectedOption = options.find((o) => o.id === value);
  const displayText = selectedOption ? selectedOption.text.replace(/<[^>]*>/g, '') : '';

  const open = () => {
    if (!disabled) {
      setHighlightedIndex(selectedIndex >= 0 ? selectedIndex : 0);
      setIsOpen(true);
    }
  };
  const close = () => setIsOpen(false);
  const toggle = () => {
    if (disabled) return;
    if (isOpen) {
      close();
    } else {
      open();
    }
  };

  useEffect(() => {
    if (!isOpen) return;
    const onOutside = (e: MouseEvent) => {
      const target = e.target as Node;
      const clickedInsideTrigger = !!containerRef.current && containerRef.current.contains(target);
      if (!clickedInsideTrigger) {
        close();
      }
    };
    document.addEventListener('mousedown', onOutside);
    return () => document.removeEventListener('mousedown', onOutside);
  }, [isOpen]);

  useEffect(
    () => () => {
      if (responsiveItemRef.current) {
        responsiveItemRef.current.style.zIndex = previousResponsiveItemZIndexRef.current;
      }
    },
    [],
  );

  // Raise parent responsive-item z-index while dropdown is open, then restore previous value.
  useEffect(() => {
    if (!containerRef.current) return;

    if (isOpen) {
      // In shadow DOM, closest() won't cross the shadow boundary.
      // Fall back to searching from the shadow host in light DOM.
      let responsiveItem = containerRef.current.closest('.responsive-item') as HTMLElement | null;
      if (!responsiveItem) {
        const root = containerRef.current.getRootNode();
        const host = root && 'host' in root ? (root.host as HTMLElement | null) : null;
        if (host) {
          responsiveItem = host.closest('.responsive-item') as HTMLElement | null;
        }
      }
      if (responsiveItem) {
        responsiveItemRef.current = responsiveItem;
        previousResponsiveItemZIndexRef.current = responsiveItem.style.zIndex || '';
        responsiveItem.style.zIndex = '9999999';
      }
      return;
    }

    if (responsiveItemRef.current) {
      responsiveItemRef.current.style.zIndex = previousResponsiveItemZIndexRef.current;
      responsiveItemRef.current = null;
      previousResponsiveItemZIndexRef.current = '';
    }
  }, [isOpen]);

  useEffect(() => {
    if (!isOpen) return;
    const activeOpt = options[highlightedIndex];
    if (!activeOpt) return;
    const activeEl = document.getElementById(getOptionId(activeOpt.id));
    activeEl?.scrollIntoView({ block: 'nearest' });
  }, [isOpen, highlightedIndex, options]);

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Escape') {
      e.preventDefault();
      close();
      return;
    }

    if (e.key === 'ArrowDown') {
      e.preventDefault();
      if (!isOpen) {
        open();
      } else {
        setHighlightedIndex((prev) => {
          if (!options.length) return 0;
          return prev >= options.length - 1 ? 0 : prev + 1;
        });
      }
      return;
    }

    if (e.key === 'ArrowUp') {
      e.preventDefault();
      if (!isOpen) {
        open();
      } else {
        setHighlightedIndex((prev) => {
          if (!options.length) return 0;
          return prev <= 0 ? options.length - 1 : prev - 1;
        });
      }
      return;
    }

    if (e.key === 'Home' && isOpen) {
      e.preventDefault();
      setHighlightedIndex(0);
      return;
    }

    if (e.key === 'End' && isOpen) {
      e.preventDefault();
      setHighlightedIndex(Math.max(options.length - 1, 0));
      return;
    }

    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      if (isOpen && options[highlightedIndex]) {
        const selected = options[highlightedIndex];
        handleOptionSelect(selected.id, selected.text.replace(/<[^>]*>/g, ''));
      } else {
        open();
      }
    }
  };

  const handleOptionSelect = (optId: string, optText: string) => {
    onSelect(name, optId, optText);
    close();
  };

  return (
    <span ref={containerRef} className={`fib-dropdown${isOpen ? ' open' : ''}`}>
      <button
        type="button"
        role="combobox"
        className={`fib-select-display${displayClass ? ` ${displayClass}` : ''}`}
        onClick={toggle}
        disabled={disabled}
        aria-haspopup="listbox"
        aria-expanded={isOpen}
        aria-controls={listboxId}
        aria-activedescendant={activeDescendant}
        aria-label={ariaLabel}
        onKeyDown={handleKeyDown}
      >
        <span className="fib-select-text">{displayText}</span>
        <span className={`fib-select-arrow${isOpen ? ' open' : ''}`} />
      </button>
      {isOpen && (
        <span id={listboxId} className="fib-dropdown-options" role="listbox" aria-label={ariaLabel}>
          {options.map((opt, optIndex) => {
            const label = opt.text.replace(/<[^>]*>/g, '');
            return (
              <span
                key={opt.id}
                id={getOptionId(opt.id)}
                role="option"
                aria-selected={opt.id === value}
                className={`fib-dropdown-option${opt.id === value ? ' selected' : ''}${
                  optIndex === highlightedIndex ? ' highlighted' : ''
                }`}
                onMouseEnter={() => setHighlightedIndex(optIndex)}
                onMouseDown={(e) => {
                  e.preventDefault();
                  handleOptionSelect(opt.id, label);
                }}
              >
                {label}
              </span>
            );
          })}
        </span>
      )}
    </span>
  );
};

const FillBlanks: React.FC<PartComponentProps<FIBModel>> = (props) => {
  const id: string = props.id;
  const [model, _setModel] = useState<any>(props.model);
  const [localSnapshot, setLocalSnapshot] = useState<any>({});
  const [stateChanged, setStateChanged] = useState<boolean>(false);
  const [mutateState, setMutateState] = useState<any>({});
  const { width, height, content, elements, alternateCorrectDelimiter } = model;
  const fibContainer = useRef(null);
  // Map to store refs for each text input by element key
  const inputRefs = useRef<Map<string, HTMLInputElement>>(new Map());

  const [attempted, setAttempted] = useState<boolean>(false);
  const [contentList, setContentList] = useState<any[]>([]);
  const [elementValues, setElementValues] = useState<SelectOption[]>([]);
  // Live region for screen reader announcements
  const liveRegionRef = useRef<HTMLDivElement>(null);

  const getElementValueByKey = useCallback(
    (key: string) => {
      // get value from `elementValues` based on key
      if (!key || typeof key === 'undefined' || !elementValues?.length) {
        return '';
      }
      const val = elementValues?.find((obj) => obj.key === key);
      return val && val?.value ? val.value.toString() : '';
    },
    [elementValues],
  );

  const prevElementValues = usePrevious<any[]>(elementValues);

  const [enabled, setEnabled] = useState<boolean>(
    model?.enabled !== undefined ? parseBool(model.enabled) : true,
  );
  const [_correct, setCorrect] = useState<boolean>(
    model?.correct !== undefined ? parseBool(model.correct) : false,
  );
  const [showCorrect, setShowCorrect] = useState<boolean>(
    model?.showCorrect !== undefined ? parseBool(model.showCorrect) : false,
  );
  const [showHints, setShowHints] = useState<boolean>(
    model?.showHints !== undefined ? parseBool(model.showHints) : false,
  );
  const [customCss, setCustomCss] = useState<string>(model?.customCss ? model.customCss : '');
  const [customCssClass, setCustomCssClass] = useState<string>(
    model?.customCssClass || model?.customCss || '',
  );
  const [ready, setReady] = useState<boolean>(false);
  const wrapperStyles: CSSProperties = {
    height,
    borderRadius: '5px',
    fontFamily: 'revert',
  };

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

  const initialize = useCallback(async (pModel) => {
    const partResponses: any[] = pModel?.elements?.map((el: any) => {
      const index: number = pModel?.elements?.findIndex((o: any) => o.key === el.key);

      return [
        {
          key: `Input ${index + 1}.Value`,
          type: CapiVariableTypes.STRING,
          value: '',
        },
        {
          key: `Input ${index + 1}.Correct`,
          type: CapiVariableTypes.BOOLEAN,
          value: false,
        },
        { key: `showCorrect`, type: CapiVariableTypes.BOOLEAN, value: pModel.showCorrect },
        { key: `showHints`, type: CapiVariableTypes.BOOLEAN, value: pModel.showHints },
      ];
    });
    const elementPartResponses = partResponses ? [].concat(...partResponses) : [];

    const initResult = await props.onInit({
      id,
      responses: [...elementPartResponses],
    });

    //customCss comes from model and it was assigning blank value to customCss variable on line #85. Once model is updated
    //need to assign the update values to the variable
    if (pModel?.customCss) {
      setCustomCss(pModel.customCss);
    }
    // result of init has a state snapshot with latest (init state applied)
    const currentStateSnapshot = initResult.snapshot;
    setLocalSnapshot(currentStateSnapshot);
    const sEnabled = currentStateSnapshot[`stage.${id}.enabled`];
    if (sEnabled) {
      setEnabled(parseBool(sEnabled));
    }

    const sShowCorrect = currentStateSnapshot[`stage.${id}.showCorrect`];
    if (sShowCorrect) {
      setShowCorrect(parseBool(sShowCorrect));
      const newElementValues = pModel.elements.map((el: any) => {
        return { key: el.key, value: el.correct };
      });
      maybeUpdateElementValues(newElementValues);
    }

    const sShowHints = currentStateSnapshot[`stage.${id}.showHints`];
    if (sShowHints) {
      setShowHints(parseBool(sShowHints));
    }

    const sCustomCss = currentStateSnapshot[`stage.${id}.customCss`];
    if (sCustomCss) {
      setCustomCss(sCustomCss);
    }

    const sCustomCssClass = currentStateSnapshot[`stage.${id}.customCssClass`];
    if (sEnabled) {
      setCustomCssClass(sCustomCssClass);
    }

    const sAttempted = currentStateSnapshot[`stage.${id}.attempted`];
    if (sAttempted) {
      setAttempted(parseBool(sAttempted));
    }
    //Instead of hardcoding REVIEW, we can make it an global interface and then importa that here.
    if (initResult.context.mode === contexts.REVIEW) {
      setEnabled(false);
    }
    setReady(true);
  }, []);

  useEffect(() => {
    initialize(model);
  }, [model]);

  useEffect(() => {
    if (!ready) {
      return;
    }
    props.onReady({ id, responses: [] });
  }, [ready]);

  useEffect(() => {
    //if (elements?.length && state?.length) {
    if (elements?.length) {
      getStateSelections(localSnapshot);
      setContentList(buildContentList());
    }
  }, [elements, localSnapshot]);

  useEffect(() => {
    //if (elements?.length && state?.length) {
    if (elements?.length && stateChanged) {
      getStateSelections(mutateState);
      setContentList(buildContentList());
      setStateChanged(false);
    }
  }, [elements, stateChanged, mutateState]);

  const maybeUpdateElementValues = (newElementValues: SelectOption[]) => {
    setElementValues((prevState: any) => {
      const changed = prevState.some((el: any) => {
        const newEl = newElementValues.find((newEl: any) => newEl.key === el.key);
        return newEl && newEl.value !== el.value;
      });
      if (changed) {
        const updated = prevState.map((el: any) => {
          const newEl = newElementValues.find((newEl: any) => newEl.key === el.key);
          return newEl ? { ...newEl } : el;
        });
        return updated;
      }
      return prevState;
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
        /* console.log(`${notificationType.toString()} notification handled [InputNumber]`, payload); */
        switch (notificationType) {
          case NotificationType.CHECK_STARTED:
            // nothing to do
            break;
          case NotificationType.CHECK_COMPLETE:
            // nothing to do
            break;
          case NotificationType.STATE_CHANGED:
            const { mutateChanges: changes } = payload;
            setStateChanged(true);
            setMutateState(changes);
            const sEnabled = changes[`stage.${id}.enabled`];
            if (sEnabled !== undefined) {
              setEnabled(parseBool(sEnabled));
            }
            const sShowCorrect = changes[`stage.${id}.showCorrect`];
            if (sShowCorrect) {
              setShowCorrect(parseBool(sShowCorrect));
              const newElementValues = model.elements.map((el: any) => {
                return { key: el.key, value: el.correct };
              });
              maybeUpdateElementValues(newElementValues);
            }
            const showHints = changes[`stage.${id}.showHints`];
            if (showHints) {
              setShowHints(parseBool(showHints));
            }
            const sCustomCss = changes[`stage.${id}.customCss`];
            if (sCustomCss) {
              setCustomCss(sCustomCss);
            }
            const sCustomCssClass = changes[`stage.${id}.customCssClass`];
            if (sCustomCssClass) {
              setCustomCssClass(sCustomCssClass);
            }
            const sAttempted = changes[`stage.${id}.attempted`];
            if (sAttempted) {
              setAttempted(parseBool(sAttempted));
            }
            break;
          case NotificationType.CONTEXT_CHANGED:
            {
              const { initStateFacts: changes } = payload;
              const sEnabled = changes[`stage.${id}.enabled`];
              if (sEnabled) {
                setEnabled(parseBool(sEnabled));
              }
              const sShowCorrect = changes[`stage.${id}.showCorrect`];
              if (sShowCorrect) {
                setShowCorrect(parseBool(sShowCorrect));
                const newElementValues = model.elements.map((el: any) => {
                  return { key: el.key, value: el.correct };
                });
                maybeUpdateElementValues(newElementValues);
              }
              const showHints = changes[`stage.${id}.showHints`];
              if (showHints) {
                setShowHints(parseBool(showHints));
              }
              const sCustomCss = changes[`stage.${id}.customCss`];
              if (sCustomCss) {
                setCustomCss(sCustomCss);
              }
              const sCustomCssClass = changes[`stage.${id}.customCssClass`];
              if (sCustomCssClass) {
                setCustomCssClass(sCustomCssClass);
              }
              const sAttempted = changes[`stage.${id}.attempted`];
              if (sAttempted) {
                setAttempted(parseBool(sAttempted));
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
  }, [props.notify, model]);

  const announceToScreenReader = (message: string) => {
    if (liveRegionRef.current) {
      liveRegionRef.current.textContent = message;
      // Clear the message after a short delay to allow re-announcement if needed
      setTimeout(() => {
        if (liveRegionRef.current) {
          liveRegionRef.current.textContent = '';
        }
      }, 500);
    }
  };

  const handleInput = (e: any) => {
    if (!e || typeof e === 'undefined') return;
    setAttempted(true);
    maybeUpdateElementValues([{ key: e.name, value: e.value }]);

    // Announce selection to screen reader — prefer explicit displayText, then native option text
    const displayText = e.displayText || e.options?.[e.selectedIndex]?.text || e.value || '';
    if (displayText) {
      announceToScreenReader(`Selected: ${displayText}`);
    }
  };

  // returns boolean
  const isCorrect = (submission: string, correct: string, alternateCorrect: string) => {
    if (!submission || !correct) return false;

    const correctArray: any[] =
      typeof alternateCorrect !== 'undefined'
        ? Array.isArray(alternateCorrect)
          ? [correct, ...alternateCorrect]
          : [correct, ...alternateCorrect.split(alternateCorrectDelimiter)]
        : [correct];

    return correctArray.includes(submission);
  };

  const saveElements = useCallback(() => {
    if (!elements?.length) return;

    const allCorrect = elements.every(
      (element: { key: string; correct: string; alternateCorrect: string }) => {
        const elVal = getElementValueByKey(element.key);
        return isCorrect(elVal, element.correct, element.alternateCorrect);
      },
    );

    const allInputCompleted = elements.every(
      (element: { key: string; correct: string; alternateCorrect: string }) => {
        const elVal = getElementValueByKey(element.key);
        return elVal?.trim()?.length;
      },
    );

    setCorrect(allCorrect);

    // set up responses array based on current selections/values of elements
    const partResponses: any[] = elements.map((el: any) => {
      const val: string = getElementValueByKey(el.key);
      const index: number = elements.findIndex((o: any) => o.key === el.key);

      return [
        {
          key: `Input ${index + 1}.Value`,
          type: CapiVariableTypes.STRING,
          value: val,
        },
        {
          key: `Input ${index + 1}.Correct`,
          type: CapiVariableTypes.BOOLEAN,
          value: isCorrect(val, el.correct, el.alternateCorrect),
        },
      ];
    });
    // save to state
    try {
      const elementPartResponses = [].concat(...partResponses);

      props.onSave({
        id: `${id}`,
        responses: [
          ...elementPartResponses,
          {
            key: 'enabled',
            type: CapiVariableTypes.BOOLEAN,
            value: enabled,
          },
          {
            key: 'showCorrect',
            type: CapiVariableTypes.BOOLEAN,
            value: showCorrect,
          },
          {
            key: 'customCss',
            type: CapiVariableTypes.STRING,
            value: customCss,
          },
          {
            key: 'customCssClass',
            type: CapiVariableTypes.STRING,
            value: customCssClass,
          },
          {
            key: 'correct',
            type: CapiVariableTypes.BOOLEAN,
            value: allCorrect,
          },
          {
            key: 'IsComplete',
            type: CapiVariableTypes.BOOLEAN,
            value: allInputCompleted,
          },
          {
            key: 'attempted',
            type: CapiVariableTypes.BOOLEAN,
            value: attempted,
          },
          {
            key: 'showHints',
            type: CapiVariableTypes.BOOLEAN,
            value: showHints,
          },
        ],
      });
    } catch (err) {
      console.log(err);
    }
  }, [getElementValueByKey, attempted]);

  useEffect(() => {
    // write to state when elementValues changes
    if (
      prevElementValues &&
      ((prevElementValues.length < 1 && elementValues.length > 0) ||
        // if previous element values contain values and the values don't match currently selected values
        (prevElementValues.length > 0 &&
          !elementValues.every((val) => prevElementValues.includes(val))))
    ) {
      saveElements();
      setContentList(buildContentList());
    }
  }, [elementValues, saveElements]);

  const getStateSelections = (snapshot: any) => {
    if (!Object.keys(snapshot)?.length || !elements?.length) return;

    // check for state vars that match elements keys and
    const interested = Object.keys(snapshot).filter(
      (stateVar) => stateVar.indexOf(`stage.${id}.`) === 0,
    );
    const stateValues: any[] = interested
      .map((stateVar) => {
        const sKey = stateVar;
        if (sKey?.startsWith(`stage.${id}.Input `) && sKey?.endsWith('.Value')) {
          const segments = sKey.split('.');
          const finalsKey = segments.slice(-2).join('.');
          // extract index from stateVar key
          const index: number = parseInt(finalsKey.replace(/[^0-9\\.]/g, ''), 10);
          // get key from `elements` based on 'Input [index].Value'
          const el: any = elements[index - 1];
          const val: string = snapshot[stateVar]?.toString();
          if (el?.key) return { key: el.key, value: val };
        } else {
          return false;
        }
      })
      .filter((v) => !!v);
    // set new elementValues array
    setElementValues([
      ...stateValues,
      ...elementValues.filter((obj) => !stateValues.includes(obj?.key)),
    ]);
  };

  const buildContentList = useCallback(
    () =>
      content?.map(
        (contentItem: { [x: string]: any; insert: any; dropdown: any }, index: number) => {
          if (!elements?.length) return;

          const insertList: any[] = [];
          let insertEl: any;

          if (contentItem.insert) {
            // contentItem.insert is always a string
            const htmlString = contentItem?.insert?.replace(/\n/g, '<br />');
            insertList.push(
              <span dangerouslySetInnerHTML={{ __html: htmlString }} key={`text-${index}`} />,
            );
          } else if (contentItem.dropdown) {
            // get correlating dropdown from `elements`
            insertEl = elements.find((elItem: { key: any }) => elItem.key === contentItem.dropdown);
            if (insertEl) {
              // build list of options for react-select
              const elVal: string = getElementValueByKey(insertEl.key);
              const optionsList = insertEl.options.map(
                ({ value: text, key: id }: { value: any; key: any }) => ({
                  id,
                  text,
                }),
              );
              const answerStatus: string =
                (showCorrect && isCorrect(elVal, insertEl.correct, insertEl.alternateCorrect)) ||
                (showHints && isCorrect(elVal, insertEl.correct, insertEl.alternateCorrect))
                  ? 'correct'
                  : 'incorrect';

              insertList.push(
                <span className="dropdown-blot" tabIndex={-1} key={`dropdown-${insertEl.key}`}>
                  <span className="dropdown-container" tabIndex={-1}>
                    <FibDropdown
                      name={insertEl.key}
                      value={elVal}
                      options={optionsList}
                      disabled={!enabled}
                      ariaLabel={
                        elVal
                          ? `${elVal}, Dropdown ${index + 1}`
                          : `Dropdown ${index + 1}, Make a selection`
                      }
                      displayClass={showCorrect || showHints ? answerStatus : ''}
                      onSelect={(fieldName, optionId, displayText) =>
                        handleInput({ name: fieldName, value: optionId, displayText })
                      }
                    />
                  </span>
                </span>,
              );
            }
          } else if (contentItem['text-input']) {
            // get correlating inputText from `elements`
            insertEl = elements.find((elItem: { key: any }) => {
              return elItem.key === contentItem['text-input'];
            });
            if (insertEl) {
              const elVal: string = getElementValueByKey(insertEl.key);
              const answerStatus: string =
                (showCorrect && isCorrect(elVal, insertEl.correct, insertEl.alternateCorrect)) ||
                (showHints && isCorrect(elVal, insertEl.correct, insertEl.alternateCorrect))
                  ? 'correct'
                  : 'incorrect';

              insertList.push(
                <span className="text-input-blot" key={`text-input-${insertEl.key}`}>
                  <span
                    className={`text-input-container ${
                      showCorrect || showHints ? answerStatus : ''
                    }`}
                    tabIndex={-1}
                  >
                    <input
                      ref={(ref: HTMLInputElement | null) => {
                        if (ref) {
                          inputRefs.current.set(insertEl.key, ref);
                        } else {
                          inputRefs.current.delete(insertEl.key);
                        }
                      }}
                      name={insertEl.key}
                      className={`text-input ${!enabled ? 'disabled' : ''} ${
                        showCorrect && isCorrect(elVal, insertEl.correct, insertEl.alternateCorrect)
                          ? 'correct'
                          : ''
                      }`}
                      type="text"
                      value={elVal}
                      onChange={(e) => handleInput(e.currentTarget)}
                      disabled={!enabled}
                      aria-label={`Text input ${index + 1}`}
                    />
                  </span>
                </span>,
              );
            }
          }
          return insertList;
        },
      ),
    [getElementValueByKey, showHints],
  );

  return (
    <div
      data-janus-type={tagName}
      style={wrapperStyles}
      className={`fib-container`}
      ref={fibContainer}
      role="group"
      aria-label="Fill in the blanks"
    >
      <style type="text/css">@import url(/css/janus_fill_blanks_delivery.css);</style>
      <style type="text/css">{`${customCss}`};</style>
      {/* Live region for screen reader announcements */}
      <div
        ref={liveRegionRef}
        role="status"
        aria-live="polite"
        aria-atomic="true"
        className="sr-only"
        style={{
          position: 'absolute',
          width: '1px',
          height: '1px',
          padding: 0,
          margin: '-1px',
          overflow: 'hidden',
          clip: 'rect(0, 0, 0, 0)',
          whiteSpace: 'nowrap',
          borderWidth: 0,
        }}
      />
      <div className="scene">
        <div className="app">
          <div className="editor ql-container ql-snow ql-disabled">
            <div
              className="ql-editor"
              data-gramm="false"
              contentEditable="false"
              suppressContentEditableWarning={true}
            >
              <p>{contentList}</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export const tagName = 'janus-fill-blanks';
export const watchedProps = ['model', 'id', 'state', 'type'];

export default FillBlanks;
