/* eslint-disable react/prop-types */
import { usePrevious } from 'components/hooks/usePrevious';
import { shuffle } from 'lodash';
import React, { CSSProperties, useCallback, useEffect, useState } from 'react';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import {
  NotificationType,
  subscribeToNotification,
} from '../../../apps/delivery/components/NotificationContext';
import { contexts } from '../../../types/applicationContext';
import { parseBoolean } from '../../../utils/common';
import { renderFlow } from '../janus-text-flow/TextFlow';
import { PartComponentProps } from '../types/parts';
import { JanusMultipleChoiceQuestionProperties } from './MultipleChoiceQuestionType';
import { McqModel } from './schema';

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
}) => {
  const mcqItemStyles: CSSProperties = {};
  if (layoutType === 'horizontalLayout') {
    const hasImages = nodes.some((node: any) =>
      node.children.some((child: { tag: string }) => child.tag === 'img'),
    );
    const hasBlankSpans = nodes.some((node: any) =>
      node.children.some(
        (child: { tag: string; children: string | any[] }) =>
          child.tag === 'span' && child.children.length === 0,
      ),
    );
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

  const textValue = getNodeText(nodes);

  const handleChanged = (e: { target: { checked: any } }) => {
    const selection = {
      value: val,
      textValue,
      checked: e.target.checked,
    };
    onSelected(selection);
  };

  return (
    <React.Fragment>
      <div style={mcqItemStyles}>
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

const MultipleChoiceQuestion: React.FC<PartComponentProps<McqModel>> = (props) => {
  const [state, setState] = useState<any[]>(Array.isArray(props.state) ? props.state : []);
  const [model, setModel] = useState<any>(Array.isArray(props.model) ? props.model : {});
  const [ready, setReady] = useState<boolean>(false);
  const id: string = props.id;

  const [enabled, setEnabled] = useState(true);
  const [randomized, setRandomized] = useState(false);
  const [options, setOptions] = useState<any[]>([]);
  const [numberOfSelectedChoices, setNumberOfSelectedChoices] = useState(0);
  // note in SS selection is 1 based
  const [selectedChoice, setSelectedChoice] = useState<number>(0);
  const [selectedChoiceText, setSelectedChoiceText] = useState<string>('');
  const [selectedChoices, setSelectedChoices] = useState<any[]>([]);
  const [selectedChoicesText, setSelectedChoicesText] = useState<any[]>([]);
  const prevSelectedChoice = usePrevious<number>(selectedChoice);
  const prevSelectedChoices = usePrevious<any[]>(selectedChoices);

  const initialize = useCallback(async (pModel) => {
    // set defaults from model
    const dEnabled = typeof pModel.enabled === 'boolean' ? pModel.enabled : enabled;
    setEnabled(dEnabled);

    const dRandomized = parseBoolean(pModel.randomize);
    setRandomized(dRandomized);

    // BS: not sure I grok this one
    const dMcqItems = pModel.mcqItems || [];
    setSelectedChoicesText(
      dMcqItems.map((item: { nodes: any }, index: number) => {
        return {
          value: index + 1,
          textValue: getNodeText(item.nodes),
          checked: false,
        };
      }),
    );

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
    const sSelectedChoices = currentStateSnapshot[`stage.${id}.selectedChoices`];
    if (sSelectedChoices !== undefined) {
      setSelectedChoices(sSelectedChoices);
    }
    const sSelectedChoicesText = currentStateSnapshot[`stage.${id}.selectedChoicesText`];
    if (sSelectedChoices !== undefined) {
      setSelectedChoicesText(sSelectedChoicesText);
    }
    const sSelectedChoiceText = currentStateSnapshot[`stage.${id}.selectedChoiceText`];
    if (sSelectedChoiceText !== undefined) {
      setSelectedChoiceText(sSelectedChoiceText);
    }
    const sSelectedChoice = currentStateSnapshot[`stage.${id}.selectedChoice`];
    if (sSelectedChoice !== undefined) {
      setSelectedChoice(sSelectedChoice);
    }
    const sNumberOfSelectedChoices = currentStateSnapshot[`stage.${id}.numberOfSelectedChoices`];
    if (sNumberOfSelectedChoices !== undefined) {
      setNumberOfSelectedChoices(sNumberOfSelectedChoices);
    }
    //Instead of hardcoding REVIEW, we can make it an global interface and then importa that here.
    if (initResult.context.mode === contexts.REVIEW) {
      setEnabled(false);
    }
    setReady(true);
  }, []);

  const {
    x = 0,
    y = 0,
    z = 0,
    width,
    multipleSelection,
    mcqItems,
    customCssClass,
    layoutType,
    height,
    overrideHeight = false,
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

  const getOptionTextFromNode = (children: any): any => {
    let optionText = '';
    if (children.tag === 'text') {
      optionText = children.text;
    } else if (children?.children?.length) {
      optionText = getOptionTextFromNode(children.children[0]);
    }
    return optionText;
  };

  const getOptionTextById = (options: any, optionId: any): any => {
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

  const getOptionTextByText = (options: any, optionText: any): any => {
    const text = options.map((option: any) => {
      const text = getOptionTextFromNode(option.nodes[0]);
      if (text === optionText) {
        return option.value;
      }
    });

    return text.filter((option: any) => option !== undefined);
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
              const sSelectedChoice = changes[`stage.${id}.selectedChoice`];
              if (sSelectedChoice !== undefined) {
                const choice = parseInt(String(sSelectedChoice), 10);
                if (selectedChoice !== choice) {
                  setSelectedChoice(choice);
                }
              }
              const sSelectedChoiceText = changes[`stage.${id}.selectedChoiceText`];
              if (sSelectedChoiceText !== undefined) {
                const updatedSelectedOptions = getOptionTextByText(options, sSelectedChoiceText);
                setSelectedChoice(updatedSelectedOptions);
              }
              const sSelectedChoices = changes[`stage.${id}.selectedChoices`];
              if (sSelectedChoices !== undefined && Array.isArray(sSelectedChoices)) {
                const updatedValues = sSelectedChoices.map((item) =>
                  !Number.isNaN(parseFloat(item)) ? parseFloat(item) : item,
                );
                props.onSave({
                  id: `${id}`,
                  responses: [
                    {
                      key: 'numberOfSelectedChoices',
                      type: CapiVariableTypes.NUMBER,
                      value: updatedValues?.length,
                    },
                  ],
                });
                setSelectedChoices(updatedValues);
              }
              const sSelectedChoicesText = changes[`stage.${id}.selectedChoicesText`];
              if (sSelectedChoicesText !== undefined) {
                if (Array.isArray(sSelectedChoicesText)) {
                  const updatedSelectedOptions = sSelectedChoicesText
                    .map((item) => getOptionTextByText(options, item))
                    .map((option) => {
                      return option[0];
                    });
                  setSelectedChoices(updatedSelectedOptions);
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
              const sSelectedChoice = changes[`stage.${id}.selectedChoice`];
              if (sSelectedChoice !== undefined) {
                const choice = parseInt(String(sSelectedChoice), 10);
                if (selectedChoice !== choice) {
                  setSelectedChoice(choice);
                }
              }
              const sSelectedChoices = changes[`stage.${id}.selectedChoices`];
              if (sSelectedChoices !== undefined && Array.isArray(sSelectedChoices)) {
                const updatedValues = sSelectedChoices.map((item) =>
                  !Number.isNaN(parseFloat(item)) ? parseFloat(item) : item,
                );
                setSelectedChoices(updatedValues);
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
  if (layoutType === 'verticalLayout') {
    const hasImages = mcqItems.some((item: any) =>
      item.nodes.some((node: any) =>
        node.children.some((child: { tag: string }) => child.tag === 'img'),
      ),
    );
  }

  useEffect(() => {
    // we need to set up a new list so that we can shuffle while maintaining correct index/values
    let mcqList: any[] = mcqItems?.map((item: any, index: number) => ({
      ...item,
      index: index,
      value: index + 1,
    }));

    if (randomized) {
      mcqList = shuffle(mcqList);
    }

    setOptions(mcqList);
  }, [mcqItems]);

  useEffect(() => {
    // watch for a new choice then
    // trigger item selection handler
    if (selectedChoice !== 0 && selectedChoice !== -1) {
      let shouldSave = false;
      let optionText = selectedChoiceText;
      if (!optionText?.length) {
        // if selectedChoiceText blank then it means selectedChoice is being set from either init or mutate state and
        //hence need to save the props as well.
        shouldSave = true;
        optionText = getOptionTextById(options, selectedChoice);
      }
      /* console.log('handling MCQ single select'); */
      handleItemSelection(
        {
          value: selectedChoice,
          textValue: optionText,
          checked: true,
        },
        shouldSave,
      );
    }
  }, [selectedChoice]);

  useEffect(() => {
    // watch for new choices that may be set programmatically
    // trigger item selection handler for each
    if (
      multipleSelection &&
      prevSelectedChoices &&
      // if previous selected is less than 1 and selected are greater than 1
      ((prevSelectedChoices.length < 1 && selectedChoices.length > 0) ||
        // if previous selected contains values and the values don't match currently selected values
        (prevSelectedChoices.length > 0 &&
          !prevSelectedChoices.every((fact) => selectedChoices.includes(fact))))
    ) {
      let shouldSave = false;
      if (!selectedChoicesText?.length) {
        // if selectedChoiceText blank then it means selectedChoice is being set from either init or mutate state and
        //hence need to save the props.
        shouldSave = true;
        selectedChoices.forEach((option) => {
          selectedChoicesText.push({
            value: option,
            textValue: getOptionTextById(options, option),
            checked: selectedChoices.includes(option),
          });
        });
      }
      /* console.log('handling MCQ multi select'); */
      selectedChoicesText.forEach((option) => {
        handleItemSelection(
          {
            value: option.value,
            textValue: option.textValue,
            checked: selectedChoices.includes(option.value),
          },
          shouldSave,
        );
      });
    }
  }, [selectedChoices]);

  const handleItemSelection = (
    {
      value,
      textValue,
      checked,
    }: {
      value: number;
      textValue: string;
      checked: boolean;
    },
    shouldSave = true,
  ) => {
    /*  console.log('mcq handle select'); */
    // TODO: non-number values?? - pb: I suspect not, since there's no SS ability to specify a value for an item
    const newChoice = parseInt(value.toString(), 10);
    let newCount = 1;

    let newSelectedChoices = [newChoice];
    let updatedChoicesText = [textValue];

    if (!multipleSelection) {
      // sets data for radios, which can only have single values
      setNumberOfSelectedChoices(newCount);
      setSelectedChoice(checked ? newChoice : 0);
      setSelectedChoiceText(checked ? textValue : '');
    } else {
      // sets data for checkboxes, which can have multiple values
      newSelectedChoices = [...new Set([...selectedChoices, newChoice])].filter(
        (c) => checked || (!checked && newChoice !== c),
      );

      const updatedSelections = selectedChoicesText.map((item) => {
        const modifiedItem = { ...item };
        modifiedItem.checked = item.value === value ? checked : item.checked;
        return modifiedItem;
      });

      updatedChoicesText = updatedSelections
        .filter((item) => item.checked)
        .map((item) => item.textValue);

      newCount = newSelectedChoices.length;
      setNumberOfSelectedChoices(newCount);
      setSelectedChoices(newSelectedChoices);
      setSelectedChoicesText(updatedSelections);
    }
    if (shouldSave) {
      saveState({
        numberOfSelectedChoices: newCount,
        selectedChoice:
          multipleSelection && newSelectedChoices?.length
            ? newSelectedChoices[newSelectedChoices.length - 1]
            : checked
            ? newChoice
            : 0,
        selectedChoiceText:
          multipleSelection && updatedChoicesText?.length
            ? updatedChoicesText[updatedChoicesText.length - 1]
            : checked
            ? textValue
            : '',
        selectedChoices: newSelectedChoices,
        selectedChoicesText: updatedChoicesText,
      });
    }
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
        />
      ))}
    </div>
  ) : null;
};

export const tagName = 'janus-mcq';

export default MultipleChoiceQuestion;
