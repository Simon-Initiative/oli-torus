import React, { CSSProperties, useCallback, useEffect, useRef, useState } from 'react';
import Select2 from 'react-select2-wrapper';
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

// Module-level variable to track which dropdown should receive focus after selection
// This persists across component re-renders
const pendingFocusRestore: Map<string, { elementKey: string; timestamp: number }> = new Map();

export const parseBool = (val: any) => {
  // cast value to number
  const num: number = +val;
  return !isNaN(num) ? !!num : !!String(val).toLowerCase().replace('false', '');
};
interface SelectOption {
  key: string;
  value: string;
}

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
    const inputOption: SelectOption = { key: e.name, value: e.value };
    maybeUpdateElementValues([inputOption]);

    // Check if this is a dropdown selection
    if (fibContainer.current) {
      const container = fibContainer.current as HTMLElement;
      const selectElement = container.querySelector(
        `select[name="${e.name}"]`,
      ) as HTMLSelectElement;
      if (selectElement) {
        // This is a dropdown - track it for focus restoration using module-level variable
        // Use component id + element key as unique identifier
        const focusKey = `${id}-${e.name}`;
        pendingFocusRestore.set(focusKey, {
          elementKey: e.name,
          timestamp: Date.now(),
        });

        // Get the selected option text for announcement
        const selectedOption = selectElement.options[selectElement.selectedIndex];
        const selectedText = selectedOption ? selectedOption.text : e.value || 'No selection';
        announceToScreenReader(`Selected: ${selectedText}`);
      } else {
        // This is a text input - focus should already be on it
        const inputRef = inputRefs.current.get(e.name);
        if (inputRef && document.activeElement !== inputRef) {
          inputRef.focus();
        }
      }
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

  useEffect(() => {
    if (!ready || !fibContainer.current) return;

    const componentFocusKeys = Array.from(pendingFocusRestore.keys()).filter((key) =>
      key.startsWith(`${id}-`),
    );

    if (componentFocusKeys.length === 0) return;

    const restoreFocus = () => {
      if (!fibContainer.current) return;

      const container = fibContainer.current as HTMLElement;

      componentFocusKeys.forEach((focusKey) => {
        const pendingFocus = pendingFocusRestore.get(focusKey);
        if (!pendingFocus) return;

        const { elementKey } = pendingFocus;

        const selectElement = container.querySelector(
          `select[name="${elementKey}"]`,
        ) as HTMLSelectElement | null;

        if (!selectElement) {
          // Element gone → clean up
          pendingFocusRestore.delete(focusKey);
          return;
        }
        let select2Container: HTMLElement | null = null;

        // Sibling container (most common structure)
        if (selectElement.parentElement) {
          select2Container = selectElement.parentElement.querySelector('.select2-container');
        }

        if (!select2Container) return; // retry next render

        const selection = select2Container.querySelector(
          '.select2-selection--single',
        ) as HTMLElement | null;

        if (!selection) return; // retry next render

        selection.focus();

        if (document.activeElement === selection) {
          pendingFocusRestore.delete(focusKey);
        }
      });
    };

    // 🧠 Timing: wait for React + Select2 to settle
    const timeoutId = setTimeout(() => {
      requestAnimationFrame(() => {
        requestAnimationFrame(restoreFocus);
      });
    }, 100);

    return () => clearTimeout(timeoutId);
  }, [contentList, ready, id]);

  // Clear pending focus restores when user clicks outside the component
  useEffect(() => {
    if (!ready || !fibContainer.current) return;

    const handleClickOutside = (event: MouseEvent) => {
      if (!fibContainer.current) return;
      const container = fibContainer.current as HTMLElement;

      const target = event.target as Node;
      // Check if click is outside the component
      if (!container.contains(target)) {
        // Clear all pending focus restores for this component
        const componentFocusKeys = Array.from(pendingFocusRestore.keys()).filter((key) =>
          key.startsWith(`${id}-`),
        );
        componentFocusKeys.forEach((focusKey) => {
          pendingFocusRestore.delete(focusKey);
        });
      }
    };

    // Also handle focus changes - if focus moves outside component, clear pending restores
    const handleFocusChange = () => {
      if (!fibContainer.current) return;
      const container = fibContainer.current as HTMLElement;

      const activeElement = document.activeElement;
      // If focus is outside the component, clear pending restores
      if (activeElement && !container.contains(activeElement)) {
        const componentFocusKeys = Array.from(pendingFocusRestore.keys()).filter((key) =>
          key.startsWith(`${id}-`),
        );
        componentFocusKeys.forEach((focusKey) => {
          pendingFocusRestore.delete(focusKey);
        });
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    document.addEventListener('focusin', handleFocusChange);

    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
      document.removeEventListener('focusin', handleFocusChange);
    };
  }, [ready, id]);

  // Set up Select2 event listeners for focus management and ARIA updates
  useEffect(() => {
    if (!ready || !elements?.length || !fibContainer.current) return;

    const cleanupFunctions: (() => void)[] = [];

    // Find all Select2 dropdowns within the component
    const container = fibContainer.current as HTMLElement;
    const select2Containers = container.querySelectorAll('.select2-container');

    select2Containers.forEach((select2Container) => {
      const $select2 = (window as any).$(select2Container);
      if (!$select2 || !$select2.data('select2')) return;

      // Find the associated select element to get the name/key
      const selectElement = select2Container.querySelector('select[name]') as HTMLSelectElement;
      if (!selectElement) return;

      const elementKey = selectElement.name;

      // Update initial aria-label to avoid redundant reading
      const selectedOption = selectElement.options[selectElement.selectedIndex];
      const selectedText = selectedOption ? selectedOption.text : '';

      // Find the index of this dropdown in content array
      let dropdownIndex = -1;
      if (content) {
        for (let i = 0; i < content.length; i++) {
          if (content[i].dropdown === elementKey) {
            dropdownIndex = i;
            break;
          }
        }
      }

      const indexLabel = dropdownIndex >= 0 ? `Dropdown ${dropdownIndex + 1}` : 'Dropdown';
      if (selectedText) {
        // Set aria-label to just the value, Select2 will add "combobox" automatically
        selectElement.setAttribute('aria-label', `${selectedText}, ${indexLabel}`);
      } else {
        selectElement.setAttribute('aria-label', `${indexLabel}, Make a selection`);
      }

      const handleOpen = () => {
        // Update aria-expanded when dropdown opens
        const selection = select2Container.querySelector(
          '.select2-selection--single',
        ) as HTMLElement;
        if (selection) {
          selection.setAttribute('aria-expanded', 'true');
        }
      };

      const handleSelect = () => {
        // Track that this dropdown was selected - use module-level variable
        const focusKey = `${id}-${elementKey}`;
        pendingFocusRestore.set(focusKey, {
          elementKey: elementKey,
          timestamp: Date.now(),
        });
      };

      const handleClose = () => {
        // Update aria-expanded when dropdown closes
        const selection = select2Container.querySelector(
          '.select2-selection--single',
        ) as HTMLElement;
        if (selection) {
          selection.setAttribute('aria-expanded', 'false');

          // Update aria-label to include selected value and avoid redundant reading
          const selectedOption = selectElement.options[selectElement.selectedIndex];
          const selectedText = selectedOption ? selectedOption.text : '';

          // Find the index of this dropdown in content array
          let dropdownIndex = -1;
          if (content) {
            for (let i = 0; i < content.length; i++) {
              if (content[i].dropdown === elementKey) {
                dropdownIndex = i;
                break;
              }
            }
          }

          const indexLabel = dropdownIndex >= 0 ? `Dropdown ${dropdownIndex + 1}` : 'Dropdown';
          if (selectedText) {
            // Set aria-label to just the value, Select2 will add "combobox" automatically
            selectElement.setAttribute('aria-label', `${selectedText}, ${indexLabel}`);
          } else {
            selectElement.setAttribute('aria-label', `${indexLabel}, Make a selection`);
          }
        }

        // Check if this dropdown should have focus restored using module-level variable
        const focusKey = `${id}-${elementKey}`;
        const pendingFocus = pendingFocusRestore.get(focusKey);

        if (pendingFocus && pendingFocus.elementKey === elementKey) {
          // When dropdown closes, restore focus to the trigger
          // Use multiple delays to ensure component has finished re-rendering
          setTimeout(() => {
            requestAnimationFrame(() => {
              requestAnimationFrame(() => {
                // Wait a bit more to ensure re-render is complete
                setTimeout(() => {
                  // Verify this is still the correct dropdown after re-render
                  const currentSelectElement = container.querySelector(
                    `select[name="${elementKey}"]`,
                  ) as HTMLSelectElement;
                  if (!currentSelectElement) {
                    // Element doesn't exist, safe to delete
                    pendingFocusRestore.delete(focusKey);
                    return;
                  }

                  // Try multiple methods to find the Select2 container
                  // In Select2, the container is often a sibling of the select element
                  let currentSelect2Container: HTMLElement | null = null;

                  // Method 1: Use jQuery/Select2 API (most reliable)
                  const $select2 = (window as any).$(currentSelectElement);
                  if ($select2 && $select2.data('select2')) {
                    const select2Instance = $select2.data('select2');
                    if (select2Instance.$container && select2Instance.$container.length > 0) {
                      currentSelect2Container = select2Instance.$container[0] as HTMLElement;
                    }
                  }

                  // Method 2: Find sibling select2-container (they're siblings in the DOM)
                  if (!currentSelect2Container) {
                    const parent = currentSelectElement.parentElement;
                    if (parent) {
                      // Look for select2-container as a sibling
                      currentSelect2Container = parent.querySelector(
                        '.select2-container',
                      ) as HTMLElement;
                    }
                  }

                  // Method 3: closest() - works if select is a descendant
                  if (!currentSelect2Container) {
                    currentSelect2Container = currentSelectElement.closest(
                      '.select2-container',
                    ) as HTMLElement;
                  }

                  // Method 4: Find by data-select2-id relationship
                  if (!currentSelect2Container) {
                    const select2Id = currentSelectElement.getAttribute('data-select2-id');
                    if (select2Id) {
                      // The container's data-select2-id is usually close to the select's id
                      // Try finding container in the same parent
                      const parent = currentSelectElement.parentElement;
                      if (parent) {
                        currentSelect2Container = parent.querySelector(
                          '.select2-container',
                        ) as HTMLElement;
                      }
                      // If still not found, search the whole container
                      if (!currentSelect2Container) {
                        currentSelect2Container = container.querySelector(
                          `.select2-container[data-select2-id]`,
                        ) as HTMLElement;
                      }
                    }
                  }

                  // Method 5: Find container by looking for parent with class
                  if (!currentSelect2Container) {
                    let parent = currentSelectElement.parentElement;
                    while (parent && parent !== container) {
                      if (parent.classList.contains('select2-container')) {
                        currentSelect2Container = parent;
                        break;
                      }
                      parent = parent.parentElement;
                    }
                  }

                  if (!currentSelect2Container) {
                    // Select2 container not found yet - might still be initializing after re-render
                    // Keep pending for retry, don't delete - the post-render effect will retry
                    return;
                  }

                  const currentSelection = currentSelect2Container.querySelector(
                    '.select2-selection--single',
                  ) as HTMLElement;
                  if (currentSelection) {
                    const activeElement = document.activeElement;
                    const isWithinComponent = container.contains(activeElement);

                    // Only restore focus if focus is still within the component
                    // This prevents focus jumping when user clicks outside
                    if (isWithinComponent) {
                      // Ensure the element is focusable
                      currentSelection.setAttribute('tabindex', '0');
                      // Focus the selection element
                      currentSelection.focus();
                      // Also ensure the underlying select has focus for Select2 compatibility
                      currentSelectElement.focus();

                      // Only clear the tracking after focus is successfully restored
                      if (
                        document.activeElement === currentSelection ||
                        document.activeElement === currentSelectElement
                      ) {
                        pendingFocusRestore.delete(focusKey);
                      }
                    } else {
                      // User clicked outside, clear the pending restore
                      pendingFocusRestore.delete(focusKey);
                    }
                  } else {
                    // Selection element not found, but container exists
                    // Keep pending for retry - might be a timing issue
                    return;
                  }
                }, 100); // Additional delay to ensure re-render is complete
              });
            });
          }, 300); // Initial delay to allow screen reader announcement
        }
      };

      $select2.on('select2:open', handleOpen);
      $select2.on('select2:select', handleSelect);
      $select2.on('select2:close', handleClose);
      cleanupFunctions.push(() => {
        $select2.off('select2:open', handleOpen);
        $select2.off('select2:select', handleSelect);
        $select2.off('select2:close', handleClose);
      });
    });

    return () => {
      cleanupFunctions.forEach((cleanup) => cleanup());
    };
  }, [ready, elements, contentList]);

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
                    <Select2
                      className={`dropdown ${showCorrect || showHints ? answerStatus : ''}`}
                      name={insertEl.key}
                      data={optionsList}
                      value={elVal}
                      aria-label={
                        elVal
                          ? `${elVal}, Dropdown ${index + 1}`
                          : `Dropdown ${index + 1}, Make a selection`
                      }
                      options={{
                        dropdownParent: fibContainer.current,
                        minimumResultsForSearch: 10,
                        selectOnClose: false,
                        // 👇 Important to allow HTML rendering in options
                        escapeMarkup: (markup: string) => markup,
                      }}
                      onSelect={(e: any) => handleInput(e.currentTarget)}
                      disabled={!enabled}
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
