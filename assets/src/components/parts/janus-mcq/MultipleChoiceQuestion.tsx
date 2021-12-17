/* eslint-disable react/prop-types */
import { shuffle } from 'lodash';
import React, { CSSProperties, useCallback, useEffect, useState } from 'react';
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
import { McqItem, McqModel } from './schema';

// SS assumes the unstyled "text" of the label is the text value
// there should only be one node in a label text, but we'll concat them jic
const getNodeText = (node: any): any => {
  if (Array.isArray(node)) {
    return node.reduce((txt, newNode) => (txt += getNodeText(newNode)), '');
  }
  let nodeText = node.text || '';
  nodeText += node.children.reduce((childrenText: any, childNode: any) => {
    let txt = childrenText;
    txt += getNodeText(childNode);
    return txt;
  }, '');
  return nodeText;
};

const MCQItemContent: React.FC<any> = ({ nodes, state }) => {
  return (
    // Need to set {{ left: 18, position: 'relative' }}. checked it in SS as well. This gets set for all the MCQ and external CSS override change it
    //depending upon their needs
    <div style={{ left: 18, position: 'relative' }}>
      {nodes.map((subtree: any) => {
        const style: any = {};
        if (subtree.tag === 'p') {
          // PMP-347
          const hasImages = subtree.children.some((child: { tag: string }) => child.tag === 'img');
          if (hasImages) {
            style.display = 'inline-block';
          }
        }
        return renderFlow('root', subtree, style, state);
      })}
    </div>
  );
};

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
  const mcqItemStyles: CSSProperties = {};
  if (layoutType === 'horizontalLayout') {
    if (columns === 1) {
      mcqItemStyles.width = `calc(${100 / totalItems}% - 6px)`;
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

  const handleChanged = (e: { target: { checked: any } }) => {
    const selection = {
      value: val,
      textValue,
      checked: e.target.checked,
    };
    if (onSelected) {
      onSelected(selection);
    }
  };
  return (
    <React.Fragment>
      <div style={mcqItemStyles}>
        {configureMode && (
          <>
            <button
              className="aa-add-button btn btn-primary btn-sm"
              type="button"
              aria-describedby="button-tooltip"
              onClick={() => onConfigOptionClick(index, 2)}
              style={{
                fontSize: '10px;',
                padding: 1,
                cursor: 'pointer',
              }}
            >
              <i
                className="fa fa-trash"
                style={{ cursor: 'pointer', color: 'white' }}
                aria-hidden="true"
                title="Delete the option"
              ></i>{' '}
            </button>

            <button
              className="aa-add-button btn btn-primary btn-sm"
              type="button"
              aria-describedby="button-tooltip"
              onClick={() => onConfigOptionClick(index, 1)}
              style={{
                fontSize: '10px;',
                padding: 1,
                marginLeft: 4,
                cursor: 'pointer',
              }}
            >
              <i
                className="fas fa-edit"
                style={{ cursor: 'pointer', color: 'white' }}
                aria-hidden="true"
                title="Edit the option"
              ></i>{' '}
            </button>
            <button
              className="aa-add-button btn btn-primary btn-sm"
              type="button"
              aria-describedby="button-tooltip"
              onClick={() => onConfigOptionClick(index, 3)}
              style={{
                fontSize: '10px;',
                padding: 1,
                marginLeft: 4,
                cursor: 'pointer',
                marginRight: 2,
              }}
            >
              <i
                className="fas fa-plus"
                style={{ cursor: 'pointer', color: 'white' }}
                aria-hidden="true"
                title="Add new option"
              ></i>{' '}
            </button>
          </>
        )}
        <input
          style={{ position: 'absolute', marginTop: 5 }}
          name={groupId}
          id={itemId}
          type={multipleSelection ? 'checkbox' : 'radio'}
          value={val}
          disabled={disabled}
          checked={selected}
          onChange={handleChanged}
        />
        <label htmlFor={itemId}>
          <MCQItemContent nodes={nodes} state={state} />
        </label>
      </div>
      {layoutType !== 'horizontalLayout' && <br style={{ padding: '0px;' }} />}
    </React.Fragment>
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

  // even if there are multiple choices with the same text (why??) pick the first one
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
  const [numberOfSelectedChoices, setNumberOfSelectedChoices] = useState(0);
  // note in SS selection is 1 based
  const [selectedChoice, setSelectedChoice] = useState<number>(0);
  const [selectedChoiceText, setSelectedChoiceText] = useState<string>('');
  const [selectedChoices, setSelectedChoices] = useState<number[]>([]);
  const [selectedChoicesText, setSelectedChoicesText] = useState<string[]>([]);

  const initialize = useCallback(async (pModel) => {
    // set defaults from model
    const dEnabled = typeof pModel.enabled === 'boolean' ? pModel.enabled : enabled;
    setEnabled(dEnabled);

    const dRandomized = parseBoolean(pModel.randomize);
    setRandomized(dRandomized);

    // we need to set up a new list so that we can shuffle while maintaining correct index/values
    let mcqList: McqOptionModel[] = pModel.mcqItems?.map((item: any, index: number) => ({
      ...item,
      index: index,
      value: index + 1,
    }));

    if (dRandomized) {
      mcqList = shuffle(mcqList);
    }

    setOptions(mcqList);

    // now we need to save the defaults used in adaptivity (not necessarily the same)
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
          value: numberOfSelectedChoices,
        },
        {
          key: 'selectedChoice',
          type: CapiVariableTypes.NUMBER,
          value: -1,
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

    // result of init has a state snapshot with latest (init state applied)
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

    // it doesn't make sense to apply *all* of these if they came at the same time (they shouldn't)
    let hasDoneMultiple = false;
    let hasDoneSelectedChoice = false;

    // this is for setting *multiple* choices being selected by the number value
    const sSelectedChoices = currentStateSnapshot[`stage.${id}.selectedChoices`];
    if (sSelectedChoices !== undefined) {
      hasDoneMultiple = true;
      hasDoneSelectedChoice = true;
      const selectedArray = parseArray(sSelectedChoices);
      if (Array.isArray(selectedArray)) {
        const newSelectionArray = selectedArray.map((choice) => ({
          value: choice,
          textValue: getOptionTextById(options, choice),
          checked: true,
        }));
        handleMultipleItemSelection(newSelectionArray, true);
      }
    }

    // this is for setting *multiple* choices being selected by the text value
    const sSelectedChoicesText = currentStateSnapshot[`stage.${id}.selectedChoicesText`];
    if (sSelectedChoicesText !== undefined && !hasDoneSelectedChoice) {
      hasDoneMultiple = true;
      const selectedArray = parseArray(sSelectedChoicesText);
      if (Array.isArray(selectedArray)) {
        const newSelectionArray = selectedArray
          .map((choiceText) => ({
            value: getOptionNumberFromText(options, choiceText),
            textValue: choiceText,
            checked: true,
          }))
          .filter((choice) => choice.value !== undefined);
        handleMultipleItemSelection(newSelectionArray as ItemSelectionInput[], true);
      }
    }

    if (!hasDoneMultiple) {
      // this is for setting a *single* seletion by the number
      const sSelectedChoice = currentStateSnapshot[`stage.${id}.selectedChoice`];
      if (sSelectedChoice !== undefined) {
        hasDoneSelectedChoice = true;
        const choice = parseInt(String(sSelectedChoice), 10);
        const checked = choice > 0;
        const textValue = checked ? getOptionTextById(options, choice) : '';
        handleItemSelection(
          { value: choice, textValue, checked },
          true, // need to save pretty much every time because of related properties like count
        );
      }

      // this is for a *single* choice being selected by the text value
      const sSelectedChoiceText = currentStateSnapshot[`stage.${id}.selectedChoiceText`];
      if (sSelectedChoiceText !== undefined && !hasDoneSelectedChoice) {
        const choiceNumber = getOptionNumberFromText(options, sSelectedChoiceText);
        if (choiceNumber !== undefined) {
          handleItemSelection(
            { value: choiceNumber, textValue: sSelectedChoiceText, checked: true },
            true, // need to save pretty much every time because of related properties like count
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
    multipleSelection,
    customCssClass,
    layoutType,
    height,
    overrideHeight = false,
    verticalGap,
  } = model;

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
        /* console.log(`${notificationType.toString()} notification handled [MCQ]`, payload); */
        switch (notificationType) {
          case NotificationType.CHECK_STARTED:
            // should disable input during check?
            break;
          case NotificationType.CHECK_COMPLETE:
            // if disabled above then re-enable now
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

              // it doesn't make sense to apply *all* of these if they came at the same time (they shouldn't)
              let hasDoneMultiple = false;
              let hasDoneSelectedChoice = false;

              // this is for setting *multiple* choices being selected by the number value
              const sSelectedChoices = changes[`stage.${id}.selectedChoices`];
              if (sSelectedChoices !== undefined) {
                hasDoneMultiple = true;
                hasDoneSelectedChoice = true;
                const selectedArray = parseArray(sSelectedChoices);
                if (Array.isArray(selectedArray)) {
                  const newSelectionArray = selectedArray.map((choice) => ({
                    value: choice,
                    textValue: getOptionTextById(options, choice),
                    checked: true,
                  }));
                  handleMultipleItemSelection(newSelectionArray, true);
                }
              }

              // this is for setting *multiple* choices being selected by the text value
              const sSelectedChoicesText = changes[`stage.${id}.selectedChoicesText`];
              if (sSelectedChoicesText !== undefined && !hasDoneSelectedChoice) {
                hasDoneMultiple = true;
                const selectedArray = parseArray(sSelectedChoicesText);
                if (Array.isArray(selectedArray)) {
                  const newSelectionArray = selectedArray
                    .map((choiceText) => ({
                      value: getOptionNumberFromText(options, choiceText),
                      textValue: choiceText,
                      checked: true,
                    }))
                    .filter((choice) => choice.value !== undefined);
                  handleMultipleItemSelection(newSelectionArray as ItemSelectionInput[], true);
                }
              }

              if (!hasDoneMultiple) {
                // this is for setting a *single* seletion by the number
                const sSelectedChoice = changes[`stage.${id}.selectedChoice`];
                if (sSelectedChoice !== undefined) {
                  hasDoneSelectedChoice = true;
                  const choice = parseInt(String(sSelectedChoice), 10);
                  const checked = choice > 0;
                  const textValue = checked ? getOptionTextById(options, choice) : '';
                  handleItemSelection(
                    { value: choice, textValue, checked },
                    true, // need to save pretty much every time because of related properties like count
                  );
                }

                // this is for a *single* choice being selected by the text value
                const sSelectedChoiceText = changes[`stage.${id}.selectedChoiceText`];
                if (sSelectedChoiceText !== undefined && !hasDoneSelectedChoice) {
                  const choiceNumber = getOptionNumberFromText(options, sSelectedChoiceText);
                  if (choiceNumber !== undefined) {
                    handleItemSelection(
                      { value: choiceNumber, textValue: sSelectedChoiceText, checked: true },
                      true, // need to save pretty much every time because of related properties like count
                    );
                  }
                }
              }

              // NOTE: it doesn't make sense (SS doesn't let you) to allow the things like
              // numberOfSelectedChoices to be set via mutate state
            }
            break;
          case NotificationType.CONTEXT_CHANGED:
            {
              const { snapshot: changes } = payload;
              const sEnabled = changes[`stage.${id}.enabled`];
              if (sEnabled !== undefined) {
                setEnabled(sEnabled);
              }
              const sRandomized = changes[`stage.${id}.randomize`];
              if (sRandomized !== undefined) {
                setRandomized(parseBoolean(sRandomized));
              }
              // it doesn't make sense to apply *all* of these if they came at the same time (they shouldn't)
              let hasDoneMultiple = false;
              let hasDoneSelectedChoice = false;

              // this is for setting *multiple* choices being selected by the number value
              const sSelectedChoices = changes[`stage.${id}.selectedChoices`];
              if (sSelectedChoices !== undefined) {
                hasDoneMultiple = true;
                hasDoneSelectedChoice = true;
                const selectedArray = parseArray(sSelectedChoices);
                if (Array.isArray(selectedArray)) {
                  const newSelectionArray = selectedArray.map((choice) => ({
                    value: choice,
                    textValue: getOptionTextById(options, choice),
                    checked: true,
                  }));
                  handleMultipleItemSelection(newSelectionArray, true);
                }
              }

              // this is for setting *multiple* choices being selected by the text value
              const sSelectedChoicesText = changes[`stage.${id}.selectedChoicesText`];
              if (sSelectedChoicesText !== undefined && !hasDoneSelectedChoice) {
                hasDoneMultiple = true;
                const selectedArray = parseArray(sSelectedChoicesText);
                if (Array.isArray(selectedArray)) {
                  const newSelectionArray = selectedArray
                    .map((choiceText) => ({
                      value: getOptionNumberFromText(options, choiceText),
                      textValue: choiceText,
                      checked: true,
                    }))
                    .filter((choice) => choice.value !== undefined);
                  handleMultipleItemSelection(newSelectionArray as ItemSelectionInput[], true);
                }
              }

              if (!hasDoneMultiple) {
                // this is for setting a *single* seletion by the number
                const sSelectedChoice = changes[`stage.${id}.selectedChoice`];
                if (sSelectedChoice !== undefined) {
                  hasDoneSelectedChoice = true;
                  const choice = parseInt(String(sSelectedChoice), 10);
                  const checked = choice > 0;
                  const textValue = checked ? getOptionTextById(options, choice) : '';
                  handleItemSelection(
                    { value: choice, textValue, checked },
                    true, // need to save pretty much every time because of related properties like count
                  );
                }

                // this is for a *single* choice being selected by the text value
                const sSelectedChoiceText = changes[`stage.${id}.selectedChoiceText`];
                if (sSelectedChoiceText !== undefined && !hasDoneSelectedChoice) {
                  const choiceNumber = getOptionNumberFromText(options, sSelectedChoiceText);
                  if (choiceNumber !== undefined) {
                    handleItemSelection(
                      { value: choiceNumber, textValue: sSelectedChoiceText, checked: true },
                      true, // need to save pretty much every time because of related properties like count
                    );
                  }
                }
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
  }, [props.notify, options]);

  // Set up the styles
  const styles: CSSProperties = {
    /* position: 'absolute',
    top: y,
    left: x,
    width,
    zIndex: z, */
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
      // TODO: return original model order??
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

    const newSelectedChoice = newSelectedChoices[0];

    const newSelectedChoicesText = modifiedSelections
      .sort((a, b) => a.value - b.value)
      .map((item) => item.textValue);

    const newSelectedChoiceText = newSelectedChoicesText[0];

    setNumberOfSelectedChoices(newCount);
    setSelectedChoice(newSelectedChoice);
    setSelectedChoices(newSelectedChoices);
    setSelectedChoiceText(newSelectedChoiceText);
    setSelectedChoicesText(newSelectedChoicesText);

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

  const handleItemSelection = (
    { value, textValue, checked }: ItemSelectionInput,
    shouldSave = true,
  ) => {
    const originalValue = parseInt(value.toString(), 10);
    let newChoice = checked ? originalValue : 0;
    let newCount = 1;
    let newSelectedChoices = [newChoice];
    let updatedChoicesText = [checked ? textValue : ''];
    let updatedChoiceText = updatedChoicesText[0];

    if (multipleSelection) {
      // sets data for checkboxes, which can have multiple values
      newSelectedChoices = [...new Set([...selectedChoices, newChoice])].filter(
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
    setNumberOfSelectedChoices(newCount);
    setSelectedChoice(newChoice);
    setSelectedChoices(modifiedNewSelectedChoices);
    setSelectedChoiceText(updatedChoiceText);
    setSelectedChoicesText(updatedChoicesText);

    if (shouldSave) {
      saveState({
        numberOfSelectedChoices: newCount,
        selectedChoice: newChoice,
        selectedChoiceText: updatedChoiceText,
        selectedChoices: modifiedNewSelectedChoices,
        selectedChoicesText: updatedChoicesText,
      });
    }
    console.log('MCQ HANDLE SELECT', {
      shouldSave,
      newCount,
      newChoice,
      newSelectedChoices,
      updatedChoiceText,
      updatedChoicesText,
    });
  };

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

  const isItemSelected = (index: number) => {
    // checks if the item is selected to set the input's "selected" attr
    let selected = false;
    if (multipleSelection) {
      selected = selectedChoices.includes(index + 1);
    } else {
      selected = selectedChoice === index + 1;
    }
    return selected;
  };

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

  return ready ? (
    <div data-janus-type={tagName} style={styles} className={`mcq-input`}>
      {options?.map((item, index) => (
        <MCQItem
          idx={index}
          key={`${id}-item-${index}`}
          title={item.title}
          totalItems={options.length}
          layoutType={layoutType}
          itemId={`${id}-item-${index}`}
          groupId={`mcq-${id}`}
          selected={isItemSelected(item.index)}
          val={item.value}
          onSelected={handleItemSelection}
          state={state}
          {...item}
          x={0}
          y={0}
          overrideHeight={overrideHeight}
          disabled={!enabled}
          multipleSelection={multipleSelection}
          columns={columns}
          verticalGap={verticalGap}
        />
      ))}
    </div>
  ) : null;
};

export const tagName = 'janus-mcq';

export default MultipleChoiceQuestion;
