/* eslint-disable react/prop-types */
import React, { CSSProperties, useCallback, useEffect, useState } from 'react';
import { shuffle } from 'lodash';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import {
  NotificationType,
  subscribeToNotification,
} from '../../../apps/delivery/components/NotificationContext';
import { contexts } from '../../../types/applicationContext';
import { parseArray, parseBoolean } from '../../../utils/common';
import { renderFlow } from '../janus-text-flow/TextFlow';
import { PartComponentProps } from '../types/parts';
import { JanusMultipleChoiceQuestionProperties } from './MultipleChoiceQuestionType';
import { getNodeText } from './mcq-util';
import { McqItem, McqModel } from './schema';

const MCQItemContentComponent: React.FC<any> = ({ itemId, nodes, state }) => {
  return (
    // left:18 + relative positioning preserved
    <div style={{ left: 18, position: 'relative', overflow: 'hidden' }}>
      {nodes.map((subtree: any) => {
        const style: any = {};
        if (subtree.tag === 'p') {
          // PMP-347
          const hasImages = subtree.children.some((child: { tag: string }) => child.tag === 'img');
          if (hasImages) {
            style.display = 'inline-block';
          }
        }
        return renderFlow(`${itemId}-root`, subtree, style, state);
      })}
    </div>
  );
};

const MCQItemContent = React.memo(MCQItemContentComponent);

export const MCQItem: React.FC<JanusMultipleChoiceQuestionProperties> = ({
  nodes,
  state,
  multipleSelection,
  itemId,
  layoutType,
  totalItems,
  groupId,
  selected = false,
  onSelected,
  val,
  disabled,
  idx,
  overrideHeight,
  columns = 1,
  onConfigOptionClick,
  index,
  configureMode,
  verticalGap = 0,
}) => {
  const inputRef = React.useRef<HTMLInputElement>(null);
  const isMouseInteraction = React.useRef<boolean>(false);

  /* layout rules preserved */
  const mcqItemStyles: CSSProperties = {};
  if (layoutType === 'horizontalLayout') {
    if (columns === 1) {
      mcqItemStyles.width = `calc(${Math.floor(100 / totalItems)}% - 6px)`;
    } else {
      mcqItemStyles.width = `calc(100% / ${columns} - 6px)`;
    }
    if (idx !== 0) {
      mcqItemStyles.left = `calc(${(100 / totalItems) * idx}% - 6px)`;
    }
    mcqItemStyles.position = `absolute`;
    mcqItemStyles.display = `inline-block`;
  }
  if (layoutType === 'verticalLayout' && overrideHeight) {
    mcqItemStyles.height = `calc(${100 / totalItems}%)`;
  }
  if (layoutType === 'verticalLayout' && verticalGap && index > 0) {
    mcqItemStyles.marginTop = `${verticalGap}px`;
  }

  const textValue = getNodeText(nodes);
  const labelId = `${itemId}-label`;

  /** When user checks/unchecks, we must refocus the input so SR
   *  re-announces the option text with updated state
   */
  const handleChanged = (e: { target: { checked: boolean } }) => {
    const selection = {
      value: val,
      textValue,
      checked: e.target.checked,
    };

    onSelected && onSelected(selection);

    // Always blur-then-focus for mouse interactions to force SR re-announcement
    // Don't refocus for keyboard interactions (Enter/Space) to allow normal navigation
    if (multipleSelection && isMouseInteraction.current) {
      // Always blur-then-focus to force SR re-announcement
      // Even if input already has focus, this sequence makes SR re-read the label
      inputRef.current?.blur();
      requestAnimationFrame(() => {
        requestAnimationFrame(() => {
          inputRef.current?.focus();
        });
      });
      // Reset flag after handling
      setTimeout(() => {
        isMouseInteraction.current = false;
      }, 100);
    }
  };

  /** Track mouse interactions */
  const handleMouseDown = (e: React.MouseEvent<HTMLInputElement>) => {
    if (multipleSelection) {
      isMouseInteraction.current = true;
    }
  };

  /** Track keyboard interactions and reset mouse flag */
  const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (multipleSelection) {
      // Track that this is a keyboard interaction (Enter or Space)
      if (e.key === 'Enter' || e.key === ' ') {
        isMouseInteraction.current = false;
      }
    } else {
      // For single-select (radio buttons), prevent arrow keys from navigating options
      // This allows users to scroll the page with arrow keys instead
      if (e.key === 'ArrowUp' || e.key === 'ArrowDown') {
        e.preventDefault();
        e.currentTarget.blur();
        // Manually scroll the page
        const scrollAmount = 50;
        window.scrollBy({
          top: e.key === 'ArrowUp' ? -scrollAmount : scrollAmount,
          behavior: 'auto',
        });
      }
      // Handle Tab navigation between options for single-select
      if (e.key === 'Tab') {
        const container = e.currentTarget.closest('.mcq-input');
        if (!container) return;
        const allOptions = container.querySelectorAll<HTMLInputElement>(
          `input[name="${groupId}"]:not([disabled])`,
        );
        const currentIndex = Array.from(allOptions).indexOf(e.currentTarget);
        if (currentIndex === -1) return;

        if (e.shiftKey) {
          // Shift+Tab: move to previous option
          if (currentIndex > 0) {
            e.preventDefault();
            allOptions[currentIndex - 1].focus();
          }
          // If at first option, allow normal Tab behavior to move to previous control
        } else {
          // Tab: move to next option
          if (currentIndex < allOptions.length - 1) {
            e.preventDefault();
            allOptions[currentIndex + 1].focus();
          }
          // If at last option, allow normal Tab behavior to move to next control
        }
      }
    }
  };

  return (
    <>
      <div style={mcqItemStyles} className="mcq-item">
        {/* authoring buttons preserved exactly */}
        {configureMode && (
          <>
            <button
              className="aa-add-button btn btn-primary btn-sm"
              type="button"
              aria-describedby="button-tooltip"
              onClick={() => onConfigOptionClick(index, 2)}
              style={{ fontSize: '10px;', padding: 1, cursor: 'pointer' }}
            >
              <i className="fa fa-trash" style={{ color: 'white' }} />
            </button>

            <button
              className="aa-add-button btn btn-primary btn-sm"
              type="button"
              aria-describedby="button-tooltip"
              onClick={() => onConfigOptionClick(index, 1)}
              style={{ fontSize: '10px;', padding: 1, marginLeft: 4, cursor: 'pointer' }}
            >
              <i className="fas fa-edit" style={{ color: 'white' }} />
            </button>

            <button
              className="aa-add-button btn btn-primary btn-sm"
              type="button"
              aria-describedby="button-tooltip"
              onClick={() => onConfigOptionClick(index, 3)}
              style={{ fontSize: '10px;', padding: 1, marginLeft: 4, cursor: 'pointer' }}
            >
              <i className="fas fa-plus" style={{ color: 'white' }} />
            </button>
          </>
        )}

        {/* Input now has ref + correct ARIA */}
        <input
          ref={inputRef}
          style={{ position: 'absolute', marginTop: 5 }}
          name={groupId}
          id={itemId}
          type={multipleSelection ? 'checkbox' : 'radio'}
          value={val}
          disabled={disabled}
          checked={selected}
          onChange={handleChanged}
          onMouseDown={handleMouseDown}
          onKeyDown={handleKeyDown}
          aria-labelledby={labelId}
          tabIndex={disabled ? -1 : 0}
        />

        {/* Label holds only the option content */}
        <label id={labelId} htmlFor={itemId}>
          <MCQItemContent itemId={itemId} nodes={nodes} state={state} />
        </label>
      </div>

      {layoutType !== 'horizontalLayout' && <br style={{ padding: '0px' }} />}
    </>
  );
};

interface McqOptionModel extends McqItem {
  index: number;
  value: number;
}

const getOptionTextFromNode = (children: any): any => {
  let optionText = '';
  if (children.tag === 'text') {
    optionText = children.text;
  } else if (children?.children?.length) {
    optionText = getOptionTextFromNode(children.children[0]);
  }
  return optionText;
};

const getOptionTextById = (options: McqOptionModel[], optionId: number): string => {
  const text = options
    .map((option: any) => {
      if (option.value === optionId) {
        if (option.nodes[0].tag === 'text') {
          return option.nodes[0].text;
        } else {
          return getOptionTextFromNode(option.nodes[0]);
        }
      }
    })
    .filter((option: any) => option !== undefined);
  return text?.length ? text[0] : '';
};

const getOptionNumberFromText = (
  options: McqOptionModel[],
  optionText: string,
): number | undefined => {
  const values = options
    .map((option) => {
      const text = getOptionTextFromNode(option.nodes[0]);
      if (text === optionText) {
        return option.value;
      }
    })
    .filter((option) => option !== undefined);

  return values[0];
};

interface ItemSelectionInput {
  value: number;
  textValue: string;
  checked: boolean;
}

const MultipleChoiceQuestion: React.FC<PartComponentProps<McqModel>> = (props) => {
  const [state, setState] = useState<any[]>(Array.isArray(props.state) ? props.state : []);
  const [model, setModel] = useState<any>(Array.isArray(props.model) ? props.model : {});
  const [ready, setReady] = useState<boolean>(false);
  const id: string = props.id;

  const [enabled, setEnabled] = useState(true);
  const [randomized, setRandomized] = useState(false);
  const [options, setOptions] = useState<McqOptionModel[]>([]);
  const [multipleSelection, setMultipleSelection] = useState(false);

  const [selectionState, setSelectionState] = useState<{
    numberOfSelectedChoices: number;
    selectedChoice: number;
    selectedChoiceText: string;
    selectedChoices: number[];
    selectedChoicesText: string[];
  }>({
    numberOfSelectedChoices: 0,
    selectedChoice: 0,
    selectedChoiceText: '',
    selectedChoices: [],
    selectedChoicesText: [],
  });

  // converts stringfied number array to number array
  const convertToNumberArray = (arr: string[]) =>
    arr.map((element) => parseInt(element.toString().replace(/"/g, ''), 10));

  const initialize = useCallback(async (pModel) => {
    // set defaults from model
    const dEnabled = typeof pModel.enabled === 'boolean' ? pModel.enabled : enabled;
    setEnabled(dEnabled);

    const dRandomized = parseBoolean(pModel.randomize);
    setRandomized(dRandomized);

    // Handle multipleSelection: explicitly check for boolean false, or parse if truthy, default to false
    let dMultipleSelection = false;
    if (pModel.multipleSelection !== undefined && pModel.multipleSelection !== null) {
      if (typeof pModel.multipleSelection === 'boolean') {
        dMultipleSelection = pModel.multipleSelection;
      } else {
        dMultipleSelection = parseBoolean(pModel.multipleSelection);
      }
    }
    setMultipleSelection(dMultipleSelection);

    // build options list
    let mcqList: McqOptionModel[] = pModel.mcqItems?.map((item: any, index: number) => ({
      ...item,
      index: index,
      value: index + 1,
    }));

    if (dRandomized) {
      mcqList = shuffle(mcqList);
    }

    setOptions(mcqList);

    // init adaptivity variables
    const initResult = await props.onInit({
      id,
      responses: [
        {
          key: 'enabled',
          type: CapiVariableTypes.BOOLEAN,
          value: dEnabled,
        },
        {
          key: 'randomize',
          type: CapiVariableTypes.BOOLEAN,
          value: dRandomized,
        },
        {
          key: 'numberOfSelectedChoices',
          type: CapiVariableTypes.NUMBER,
          value: selectionState.numberOfSelectedChoices,
        },
        {
          key: 'selectedChoice',
          type: CapiVariableTypes.NUMBER,
          value: -1,
        },
        {
          key: 'selectedChoiceText',
          type: CapiVariableTypes.STRING,
          value: selectionState.selectedChoiceText,
        },
        {
          key: 'selectedChoices',
          type: CapiVariableTypes.ARRAY,
          value: selectionState.selectedChoices,
        },
        {
          key: 'selectedChoicesText',
          type: CapiVariableTypes.ARRAY,
          value: selectionState.selectedChoicesText,
        },
      ],
    });

    const currentStateSnapshot = initResult.snapshot;
    setState(currentStateSnapshot);

    const sEnabled = currentStateSnapshot[`stage.${id}.enabled`];
    if (sEnabled !== undefined) {
      setEnabled(sEnabled);
    }

    const sRandomize = currentStateSnapshot[`stage.${id}.randomize`];
    if (sRandomize !== undefined) {
      setRandomized(sRandomize);
    }

    // apply incoming state (selected choices etc.)
    let hasDoneMultiple = false;
    let hasDoneSelectedChoice = false;

    const sSelectedChoices: string[] = currentStateSnapshot[`stage.${id}.selectedChoices`];
    if (dMultipleSelection && sSelectedChoices !== undefined) {
      hasDoneMultiple = true;
      hasDoneSelectedChoice = true;
      const selectedArray = convertToNumberArray(sSelectedChoices);

      if (Array.isArray(selectedArray)) {
        const newSelectionArray = selectedArray.map((choice) => ({
          value: choice,
          textValue: getOptionTextById(mcqList, choice),
          checked: true,
        }));
        handleMultipleItemSelection(newSelectionArray, true);
      }
    }

    const sSelectedChoicesText = currentStateSnapshot[`stage.${id}.selectedChoicesText`];
    if (dMultipleSelection && sSelectedChoicesText !== undefined && !hasDoneSelectedChoice) {
      hasDoneMultiple = true;
      const selectedArray = parseArray(sSelectedChoicesText);
      if (Array.isArray(selectedArray)) {
        const newSelectionArray = selectedArray
          .map((choiceText) => ({
            value: getOptionNumberFromText(mcqList, choiceText as string),
            textValue: choiceText,
            checked: true,
          }))
          .filter((choice) => choice.value !== undefined);
        handleMultipleItemSelection(newSelectionArray as ItemSelectionInput[], true);
      }
    }

    if (!hasDoneMultiple) {
      const sSelectedChoice = currentStateSnapshot[`stage.${id}.selectedChoice`];
      if (sSelectedChoice !== undefined) {
        hasDoneSelectedChoice = true;
        const choice = parseInt(String(sSelectedChoice), 10);
        const checked = choice > 0;
        const textValue = checked ? getOptionTextById(mcqList, choice) : '';
        handleItemSelection({ value: choice, textValue, checked }, true);
      }

      const sSelectedChoiceText = currentStateSnapshot[`stage.${id}.selectedChoiceText`];
      if (sSelectedChoiceText !== undefined && !hasDoneSelectedChoice) {
        const choiceNumber = getOptionNumberFromText(mcqList, sSelectedChoiceText);
        if (choiceNumber !== undefined) {
          handleItemSelection(
            { value: choiceNumber, textValue: sSelectedChoiceText, checked: true },
            true,
          );
        }
      }
    }

    if (initResult.context.mode === contexts.REVIEW) {
      setEnabled(false);
    }
    setReady(true);
  }, []);

  const {
    width,
    customCssClass,
    layoutType,
    height,
    overrideHeight = false,
    verticalGap,
    ariaLabelledBy,
  } = model;

  useEffect(() => {
    let pModel;
    let pState;
    if (typeof props?.model === 'string') {
      try {
        pModel = JSON.parse(props.model);
        setModel(pModel);
      } catch (err) {
        // ignore
      }
    }
    if (typeof props?.state === 'string') {
      try {
        pState = JSON.parse(props.state);
        setState(pState);
      } catch (err) {
        // ignore
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

  // will always *replace* the selected choices (used by init & mutate)
  const handleMultipleItemSelection = (selections: ItemSelectionInput[], shouldSave = true) => {
    let modifiedSelections = selections;
    const newCount = selections.length;
    const blankValueExit =
      (selections.length === 1 && selections.filter((item) => item.value <= 0)) || [];
    if (blankValueExit.length) {
      modifiedSelections = [];
    }
    const newSelectedChoices = modifiedSelections
      .sort((a, b) => a.value - b.value)
      .map((item) => item.value);

    const newSelectedChoice = newSelectedChoices.length ? newSelectedChoices[0] : -1;

    const newSelectedChoicesText = modifiedSelections
      .sort((a, b) => a.value - b.value)
      .map((item) => item.textValue);

    const newSelectedChoiceText = newSelectedChoicesText.length ? newSelectedChoicesText[0] : '';

    setSelectionState({
      numberOfSelectedChoices: newCount,
      selectedChoice: newSelectedChoice,
      selectedChoiceText: newSelectedChoiceText,
      selectedChoices: newSelectedChoices,
      selectedChoicesText: newSelectedChoicesText,
    });

    if (shouldSave) {
      saveState({
        numberOfSelectedChoices: newCount,
        selectedChoice: newSelectedChoice,
        selectedChoiceText: newSelectedChoiceText,
        selectedChoices: newSelectedChoices,
        selectedChoicesText: newSelectedChoicesText,
      });
    }
  };

  const handleItemSelection = useCallback(
    ({ value, textValue, checked }: ItemSelectionInput, shouldSave = true) => {
      const originalValue = parseInt(value.toString(), 10);
      let newChoice = checked ? originalValue : 0;
      let newCount = checked ? 1 : 0;
      let newSelectedChoices = [newChoice];
      let updatedChoicesText = [checked ? textValue : ''];
      let updatedChoiceText = updatedChoicesText[0];

      if (multipleSelection) {
        newSelectedChoices = [...new Set([...selectionState.selectedChoices, newChoice])].filter(
          (c) => checked || (!checked && originalValue !== c && c > 0),
        );

        newChoice = newSelectedChoices.sort()[0] || 0;

        updatedChoicesText = newSelectedChoices
          .sort()
          .map((choice) => getOptionTextById(options, choice));
        updatedChoiceText = updatedChoicesText[0] || '';

        newCount = newSelectedChoices.length;
      }
      let modifiedNewSelectedChoices = newSelectedChoices;
      const blankValueExit =
        (newSelectedChoices.length === 1 && newSelectedChoices.filter((value) => value <= 0)) || [];
      if (blankValueExit.length) {
        modifiedNewSelectedChoices = [];
        updatedChoicesText = [];
      }

      setSelectionState({
        numberOfSelectedChoices: newCount,
        selectedChoice: newChoice,
        selectedChoiceText: updatedChoiceText,
        selectedChoices: modifiedNewSelectedChoices,
        selectedChoicesText: updatedChoicesText,
      });

      if (shouldSave) {
        saveState({
          numberOfSelectedChoices: newCount,
          selectedChoice: newChoice,
          selectedChoiceText: updatedChoiceText,
          selectedChoices: modifiedNewSelectedChoices,
          selectedChoicesText: updatedChoicesText,
        });
      }
    },
    [multipleSelection, selectionState, options],
  );

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
        switch (notificationType) {
          case NotificationType.CHECK_STARTED:
            break;
          case NotificationType.CHECK_COMPLETE:
            break;
          case NotificationType.STATE_CHANGED:
            {
              const { mutateChanges: changes } = payload;
              const sEnabled = changes[`stage.${id}.enabled`];
              if (sEnabled !== undefined) {
                setEnabled(sEnabled);
              }
              const sRandomized = changes[`stage.${id}.randomize`];
              if (sRandomized !== undefined) {
                setRandomized(parseBoolean(sRandomized));
              }

              let hasDoneMultiple = false;
              let hasDoneSelectedChoice = false;

              const sSelectedChoices = changes[`stage.${id}.selectedChoices`];
              if (sSelectedChoices !== undefined) {
                hasDoneMultiple = true;
                hasDoneSelectedChoice = true;
                const selectedArray = convertToNumberArray(sSelectedChoices);

                if (Array.isArray(selectedArray)) {
                  const newSelectionArray = selectedArray.map((choice) => ({
                    value: choice,
                    textValue: getOptionTextById(options, choice),
                    checked: true,
                  }));
                  handleMultipleItemSelection(newSelectionArray, true);
                }
              }

              const sSelectedChoicesText = changes[`stage.${id}.selectedChoicesText`];
              if (sSelectedChoicesText !== undefined && !hasDoneSelectedChoice) {
                hasDoneMultiple = true;
                const selectedArray = parseArray(sSelectedChoicesText);
                if (Array.isArray(selectedArray)) {
                  const newSelectionArray = selectedArray
                    .map((choiceText) => ({
                      value: getOptionNumberFromText(options, choiceText as string),
                      textValue: choiceText,
                      checked: true,
                    }))
                    .filter((choice) => choice.value !== undefined);
                  handleMultipleItemSelection(newSelectionArray as ItemSelectionInput[], true);
                }
              }

              if (!hasDoneMultiple) {
                const sSelectedChoice = changes[`stage.${id}.selectedChoice`];
                if (sSelectedChoice !== undefined) {
                  hasDoneSelectedChoice = true;
                  const choice = parseInt(String(sSelectedChoice), 10);
                  const checked = choice > 0;
                  const textValue = checked ? getOptionTextById(options, choice) : '';
                  handleItemSelection({ value: choice, textValue, checked }, true);
                }

                const sSelectedChoiceText = changes[`stage.${id}.selectedChoiceText`];
                if (sSelectedChoiceText !== undefined && !hasDoneSelectedChoice) {
                  const choiceNumber = getOptionNumberFromText(options, sSelectedChoiceText);
                  if (choiceNumber !== undefined) {
                    handleItemSelection(
                      { value: choiceNumber, textValue: sSelectedChoiceText, checked: true },
                      true,
                    );
                  }
                }
              }
            }
            break;
          case NotificationType.CONTEXT_CHANGED:
            {
              const { snapshot: changes } = payload;

              const sEnabled = changes[`stage.${id}.enabled`];
              if (sEnabled !== undefined) {
                setEnabled(sEnabled);
              }
              const sRandomize = changes[`stage.${id}.randomize`];
              if (sRandomize !== undefined) {
                setRandomized(parseBoolean(sRandomize));
              }
              let hasDoneMultiple = false;
              let hasDoneSelectedChoice = false;

              const sSelectedChoices = changes[`stage.${id}.selectedChoices`];
              if (multipleSelection && sSelectedChoices !== undefined) {
                hasDoneMultiple = true;
                hasDoneSelectedChoice = true;
                const selectedArray = convertToNumberArray(sSelectedChoices);

                if (Array.isArray(selectedArray)) {
                  const newSelectionArray = selectedArray.map((choice) => ({
                    value: choice,
                    textValue: getOptionTextById(options, choice),
                    checked: true,
                  }));
                  handleMultipleItemSelection(newSelectionArray, true);
                }
              }

              const sSelectedChoicesText = changes[`stage.${id}.selectedChoicesText`];
              if (
                multipleSelection &&
                sSelectedChoicesText !== undefined &&
                !hasDoneSelectedChoice
              ) {
                hasDoneMultiple = true;
                const selectedArray = parseArray(sSelectedChoicesText);
                if (Array.isArray(selectedArray)) {
                  const newSelectionArray = selectedArray
                    .map((choiceText) => ({
                      value: getOptionNumberFromText(options, choiceText as string),
                      textValue: choiceText,
                      checked: true,
                    }))
                    .filter((choice) => choice.value !== undefined);
                  handleMultipleItemSelection(newSelectionArray as ItemSelectionInput[], true);
                }
              }

              if (!hasDoneMultiple) {
                const sSelectedChoice = changes[`stage.${id}.selectedChoice`];
                if (sSelectedChoice !== undefined) {
                  hasDoneSelectedChoice = true;
                  const choice = parseInt(String(sSelectedChoice), 10);
                  const checked = choice > 0;
                  const textValue = checked ? getOptionTextById(options, choice) : '';
                  handleItemSelection({ value: choice, textValue, checked }, true);
                }

                const sSelectedChoiceText = changes[`stage.${id}.selectedChoiceText`];
                if (sSelectedChoiceText !== undefined && !hasDoneSelectedChoice) {
                  const choiceNumber = getOptionNumberFromText(options, sSelectedChoiceText);
                  if (choiceNumber !== undefined) {
                    handleItemSelection(
                      { value: choiceNumber, textValue: sSelectedChoiceText, checked: true },
                      true,
                    );
                  }
                }
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
  }, [props.notify, options, handleItemSelection, multipleSelection]);

  // Set up the styles
  const styles: CSSProperties = {
    width,
  };
  if (overrideHeight) {
    styles.height = height;
    styles.marginTop = '8px';
  }

  useEffect(() => {
    setOptions((currentOptions) => {
      if (randomized) {
        return shuffle(currentOptions);
      }
      return currentOptions;
    });
  }, [randomized]);

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

  const saveState = ({
    numberOfSelectedChoices,
    selectedChoice,
    selectedChoiceText,
    selectedChoices,
    selectedChoicesText,
  }: {
    numberOfSelectedChoices: number;
    selectedChoice: number;
    selectedChoiceText: string;
    selectedChoices: number[];
    selectedChoicesText: string[];
  }) => {
    props.onSave({
      id: `${id}`,
      responses: [
        {
          key: 'numberOfSelectedChoices',
          type: CapiVariableTypes.NUMBER,
          value: numberOfSelectedChoices,
        },
        {
          key: 'selectedChoice',
          type: CapiVariableTypes.NUMBER,
          value: selectedChoice,
        },
        {
          key: 'selectedChoiceText',
          type: CapiVariableTypes.STRING,
          value: selectedChoiceText,
        },
        {
          key: 'selectedChoices',
          type: CapiVariableTypes.ARRAY,
          value: selectedChoices,
        },
        {
          key: 'selectedChoicesText',
          type: CapiVariableTypes.ARRAY,
          value: selectedChoicesText,
        },
      ],
    });
  };

  const isItemSelected = useCallback(
    (item: McqOptionModel) => {
      let selected = false;
      if (multipleSelection) {
        selected = selectionState.selectedChoices.includes(item.index + 1);
      } else {
        selected = selectionState.selectedChoice === item.index + 1;
      }
      return selected;
    },
    [multipleSelection, selectionState],
  );

  let columns = 1;
  if (customCssClass === 'two-columns') {
    columns = 2;
  }
  if (customCssClass === 'three-columns') {
    columns = 3;
  }
  if (customCssClass === 'four-columns') {
    columns = 4;
  }

  const groupLabelId = `mcq-group-label-${id}`;
  const groupLabelText =
    ariaLabelledBy?.trim() || (multipleSelection ? 'Select all that apply' : 'Multiple choice');

  return ready ? (
    <div
      data-janus-type={tagName}
      style={styles}
      className={`mcq-input mcq-${layoutType}`}
      role="group"
      aria-labelledby={groupLabelId}
      aria-live="off"
      aria-atomic="false"
    >
      <span id={groupLabelId} className="sr-only">
        {groupLabelText}
      </span>
      {options?.map((item, index) => {
        const { index: _itemIndex, ...itemWithoutIndex } = item;
        return (
          <MCQItem
            idx={index}
            index={index}
            key={`${id}-item-${index}`}
            title={item.title}
            totalItems={options.length}
            layoutType={layoutType}
            itemId={`${id}-item-${index}`}
            groupId={`mcq-${id}`}
            selected={isItemSelected(item)}
            val={item.value}
            onSelected={handleItemSelection}
            state={state}
            {...itemWithoutIndex}
            x={0}
            y={0}
            overrideHeight={overrideHeight}
            disabled={!enabled}
            multipleSelection={multipleSelection}
            columns={columns}
            verticalGap={verticalGap}
          />
        );
      })}
    </div>
  ) : null;
};

export const tagName = 'janus-mcq';

export default MultipleChoiceQuestion;
