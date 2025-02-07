/* eslint-disable react/prop-types */
import React, { CSSProperties, useCallback, useEffect, useState } from 'react';
import { shuffle } from 'lodash';
import { parseArray, parseBoolean } from 'utils/common';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import {
  NotificationType,
  subscribeToNotification,
} from '../../../apps/delivery/components/NotificationContext';
import { contexts } from '../../../types/applicationContext';
import { renderFlow } from '../janus-text-flow/TextFlow';
import { PartComponentProps } from '../types/parts';
import { Item, JanusHubSpokeItemProperties, hubSpokeModel } from './schema';

const SpokeItemContentComponent: React.FC<any> = ({ itemId, nodes, state }) => {
  return (
    <div style={{ position: 'relative', overflow: 'hidden' }}>
      {nodes.map((subtree: any) => {
        const style: any = {};
        if (subtree.tag === 'p') {
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

const SpokeItemContent = React.memo(SpokeItemContentComponent);

export const SpokeItems: React.FC<JanusHubSpokeItemProperties> = ({
  nodes,
  state,
  itemId,
  layoutType,
  totalItems,
  idx,
  overrideHeight,
  columns = 1,
  index,
  verticalGap = 0,
}) => {
  const spokeItemStyles: CSSProperties = {};
  if (layoutType === 'horizontalLayout') {
    if (columns === 1) {
      spokeItemStyles.width = `calc(${Math.floor(100 / totalItems)}% - 6px)`;
    } else {
      spokeItemStyles.width = `calc(100% / ${columns} - 6px)`;
    }
    if (idx !== 0) {
      spokeItemStyles.left = `calc(${(100 / totalItems) * idx}% - 6px)`;
    }
    spokeItemStyles.position = `absolute`;

    spokeItemStyles.display = `inline-block`;
  }
  if (layoutType === 'verticalLayout' && overrideHeight) {
    spokeItemStyles.height = `calc(${100 / totalItems}%)`;
  }
  if (layoutType === 'verticalLayout' && verticalGap && index > 0) {
    spokeItemStyles.marginTop = `${verticalGap}px`;
  }
  return (
    <React.Fragment>
      <div style={spokeItemStyles} className={` hub-spoke-item`}>
        <button type="button" style={{ width: '100%' }} className="btn btn-primary">
          <SpokeItemContent itemId={itemId} nodes={nodes} state={state} />
        </button>
      </div>
      {layoutType !== 'horizontalLayout' && <br style={{ padding: '0px' }} />}
    </React.Fragment>
  );
};

interface SpokeOptionModel extends Item {
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

const getOptionTextById = (options: SpokeOptionModel[], optionId: number): string => {
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
  options: SpokeOptionModel[],
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

const HubSpoke: React.FC<PartComponentProps<hubSpokeModel>> = (props) => {
  const [state, setState] = useState<any[]>(Array.isArray(props.state) ? props.state : []);
  const [model, setModel] = useState<any>(Array.isArray(props.model) ? props.model : {});
  const [ready, setReady] = useState<boolean>(false);
  const id: string = props.id;

  const [enabled, setEnabled] = useState(true);
  const [randomized, setRandomized] = useState(false);
  const [options, setOptions] = useState<SpokeOptionModel[]>([]);
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
    /* console.log('MCQ INIT', { pModel }); */
    // set defaults from model
    const dEnabled = typeof pModel.enabled === 'boolean' ? pModel.enabled : enabled;
    setEnabled(dEnabled);

    const dRandomized = parseBoolean(pModel.randomize);
    setRandomized(dRandomized);

    const dMultipleSelection = parseBoolean(pModel.multipleSelection);
    setMultipleSelection(dMultipleSelection);

    // we need to set up a new list so that we can shuffle while maintaining correct index/values
    let mcqList: SpokeOptionModel[] = pModel.mcqItems?.map((item: any, index: number) => ({
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
    const sSelectedChoices: string[] = currentStateSnapshot[`stage.${id}.selectedChoices`];
    if (dMultipleSelection && sSelectedChoices !== undefined) {
      hasDoneMultiple = true;
      hasDoneSelectedChoice = true;
      // convert stringfied number array to number array
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

    // this is for setting *multiple* choices being selected by the text value
    const sSelectedChoicesText = currentStateSnapshot[`stage.${id}.selectedChoicesText`];
    if (dMultipleSelection && sSelectedChoicesText !== undefined && !hasDoneSelectedChoice) {
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

  const { width, customCssClass, layoutType, height, overrideHeight = false, verticalGap } = model;

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
      // const originalValue = parseInt(value.toString(), 10);
      // const newChoice = checked ? originalValue : 0;
      // const newCount = checked ? 1 : 0;
      // const newSelectedChoices = [newChoice];
      // let updatedChoicesText = [checked ? textValue : ''];
      // let modifiedNewSelectedChoices = newSelectedChoices;
      // const blankValueExit =
      //   (newSelectedChoices.length === 1 && newSelectedChoices.filter((value) => value <= 0)) || [];
      // if (blankValueExit.length) {
      //   modifiedNewSelectedChoices = [];
      //   updatedChoicesText = [];
      // }
      // if (shouldSave) {
      //   saveState({
      //     numberOfSelectedChoices: newCount,
      //     selectedChoice: newChoice,
      //     selectedChoiceText: updatedChoiceText,
      //     selectedChoices: modifiedNewSelectedChoices,
      //     selectedChoicesText: updatedChoicesText,
      //   });
      // }
    },
    [multipleSelection, selectionState],
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
              console.log({ changes });
            }
            break;
          case NotificationType.CONTEXT_CHANGED:
            {
              const { snapshot: changes } = payload;

              console.log('MCQ CONTEXT CHANGED', { changes });

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
    // props.onSave({
    //   id: `${id}`,
    //   responses: [
    //     {
    //       key: 'numberOfSelectedChoices',
    //       type: CapiVariableTypes.NUMBER,
    //       value: numberOfSelectedChoices,
    //     },
    //     {
    //       key: 'selectedChoice',
    //       type: CapiVariableTypes.NUMBER,
    //       value: selectedChoice,
    //     },
    //     {
    //       key: 'selectedChoiceText',
    //       type: CapiVariableTypes.STRING,
    //       value: selectedChoiceText,
    //     },
    //     {
    //       key: 'selectedChoices',
    //       type: CapiVariableTypes.ARRAY,
    //       value: selectedChoices,
    //     },
    //     {
    //       key: 'selectedChoicesText',
    //       type: CapiVariableTypes.ARRAY,
    //       value: selectedChoicesText,
    //     },
    //   ],
    // });
  };

  const isItemSelected = useCallback(
    (item: SpokeOptionModel) => {
      // checks if the item is selected to set the input's "selected" attr
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

  return ready ? (
    <div data-janus-type={tagName} style={styles} className={`mcq-input mcq-${layoutType}`}>
      {options?.map((item, index) => (
        <SpokeItems
          idx={index}
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

export const tagName = 'janus-hub-spoke';

export default HubSpoke;
