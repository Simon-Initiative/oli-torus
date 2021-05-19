/* eslint-disable react/prop-types */
import { CapiVariableTypes } from '../../../adaptivity/capi';
import { usePrevious } from 'components/hooks/usePrevious';
import { shuffle } from 'lodash';
import React, { CSSProperties, useEffect, useState } from 'react';
import { renderFlow } from '../janus-text-flow/TextFlow';
import { StateVariable } from '../types/parts';
import {
  JanusMultipleChoiceQuestionProperties,
  JanusMultipleChoiceQuestionItemProperties,
} from './MultipleChoiceQuestionType';
import { parseBool } from 'utils/helpers';

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
    <div>
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
const MCQItem: React.FC<JanusMultipleChoiceQuestionProperties> = ({
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
    if (hasImages || hasBlankSpans) {
      mcqItemStyles.width = `calc(${100 / totalItems}% - 6px)`;
    }
    mcqItemStyles.display = `inline-block`;
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
    <div style={mcqItemStyles}>
      <input
        name={groupId}
        id={itemId}
        type={multipleSelection ? 'checkbox' : 'radio'}
        value={val}
        disabled={disabled}
        className="input_30cc60b8-382a-470c-8cd9-908348c58ebe"
        checked={selected}
        onChange={handleChanged}
      />
      <label htmlFor={itemId}>
        <MCQItemContent nodes={nodes} state={state} />
      </label>
    </div>
  );
};
const MultipleChoiceQuestion: React.FC<JanusMultipleChoiceQuestionItemProperties> = (props) => {
  const [state, setState] = useState<any[]>(Array.isArray(props.state) ? props.state : []);
  const [model, setModel] = useState<any>(Array.isArray(props.model) ? props.model : {});
  const id: string = props.id;
  const {
    x = 0,
    y = 0,
    z = 0,
    width,
    multipleSelection,
    mcqItems,
    randomize,
    customCssClass,
    layoutType,
  } = model;

  useEffect(() => {
    if (typeof props?.model === 'string') {
      setModel(JSON.parse(props.model));
    }
    if (typeof props?.state === 'string') {
      setState(JSON.parse(props.state));
    }
  }, [props]);

  // Set up the styles
  const styles: CSSProperties = {
    position: 'absolute',
    top: y,
    left: x,
    width,
    zIndex: z,
  };

  if (layoutType === 'verticalLayout') {
    const hasImages = mcqItems.some((item: any) =>
      item.nodes.some((node: any) =>
        node.children.some((child: { tag: string }) => child.tag === 'img'),
      ),
    );
  }
  // TODO: Reduce the amount of useStates, thus re-renders
  // TODO: send this in via model?
  const [enabled, setEnabled] = useState(true);
  const [randomized, setRandomized] = useState(randomize);
  const [options, setOptions] = useState<any[]>([]);
  const [numberOfSelectedChoices, setNumberOfSelectedChoices] = useState(0);
  // note in SS selection is 1 based
  const [selectedChoice, setSelectedChoice] = useState<number>(0);
  const [selectedChoiceText, setSelectedChoiceText] = useState<string>('');
  const [selectedChoices, setSelectedChoices] = useState<any[]>([]);
  const [selectedChoicesText, setSelectedChoicesText] = useState<any[]>(
    mcqItems?.map((item: { nodes: any }, index: number) => {
      return {
        value: index + 1,
        textValue: getNodeText(item.nodes),
        checked: false,
      };
    }),
  );
  const prevSelectedChoice = usePrevious<number>(selectedChoice);
  const prevSelectedChoices = usePrevious<any[]>(selectedChoices);

  useEffect(() => {
    handleStateChange(state);
  }, [state]);

  const handleStateChange = (stateData: StateVariable[]) => {
    // this runs every time state is updated from *any* source
    // the global variable state
    const interested = stateData.filter((stateVar) => stateVar.id.indexOf(`stage.${id}.`) === 0);
    if (interested?.length) {
      interested.forEach((stateVar) => {
        switch (stateVar.key) {
          case 'enabled':
            // will check for boolean and string truthiness for enabled
            setEnabled(parseBool(stateVar.value));
            break;
          case 'randomize':
            // will check for boolean and string truthiness for randomize
            setRandomized(parseBool(stateVar.value));
            break;
          case 'numberOfSelectedChoices':
            {
              const num = parseInt(stateVar.value as string, 10);
              if (numberOfSelectedChoices !== num) {
                setNumberOfSelectedChoices(num);
              }
            }
            break;
          case 'selectedChoice':
            {
              const choice = parseInt(stateVar.value as string, 10);
              if (selectedChoice !== choice) {
                setSelectedChoice(choice);
              }
            }
            break;
          case 'selectedChoiceText':
            setSelectedChoiceText(stateVar.value.toString());
            break;
          case 'selectedChoices':
            if (Array.isArray(stateVar.value)) {
              // converts string values to numbers
              const updatedValues = stateVar.value.map((item) =>
                !Number.isNaN(parseFloat(item)) ? parseFloat(item) : item,
              );
              setSelectedChoices(updatedValues);
            }
            break;
          case 'selectedChoicesText':
            {
              const vals = stateVar.value;
              if (Array.isArray(vals)) {
                // compare selectedChoicesText with array of strings from state
                // then update 'checked' value based on strings
                const choices = selectedChoicesText.map((choice) => ({
                  ...choice,
                  checked: vals.includes(choice.textValue),
                }));
                setSelectedChoicesText(choices);
              }
            }
            break;
        }
      });
    }
  };

  useEffect(() => {
    props.onReady({
      activityId: `${id}`,
      partResponses: [
        {
          id: `${id}.enabled`,
          key: 'enabled',
          type: 4,
          value: enabled,
        },
        {
          id: `${id}.randomize`,
          key: 'randomize',
          type: 4,
          value: randomized,
        },
        {
          id: `${id}.numberOfSelectedChoices`,
          key: 'numberOfSelectedChoices',
          type: 1,
          value: numberOfSelectedChoices,
        },
        {
          id: `${id}.selectedChoice`,
          key: 'selectedChoice',
          type: 1,
          value: selectedChoice,
        },
        {
          id: `${id}.selectedChoiceText`,
          key: 'selectedChoiceText',
          type: 1,
          value: selectedChoiceText,
        },
        {
          id: `${id}.selectedChoices`,
          key: 'selectedChoices',
          type: 3,
          value: selectedChoices,
        },
        {
          id: `${id}.selectedChoicesText`,
          key: 'selectedChoicesText',
          type: 3,
          value: selectedChoicesText,
        },
      ],
    });
  }, []);

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
    if (selectedChoice !== prevSelectedChoice && selectedChoice !== 0) {
      handleItemSelection({
        value: selectedChoice,
        textValue: selectedChoiceText,
        checked: true,
      });
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
      selectedChoicesText.forEach((option) => {
        handleItemSelection({
          value: option.value,
          textValue: option.textValue,
          checked: selectedChoices.includes(option.value),
        });
      });
    }
  }, [selectedChoices]);

  const handleItemSelection = ({
    value,
    textValue,
    checked,
  }: {
    value: number;
    textValue: string;
    checked: boolean;
  }) => {
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
      activityId: `${id}`,
      partResponses: [
        {
          id: `${id}.enabled`,
          key: 'enabled',
          type: CapiVariableTypes.BOOLEAN,
          value: enabled,
        },
        {
          id: `${id}.randomize`,
          key: 'randomize',
          type: CapiVariableTypes.BOOLEAN,
          value: randomized,
        },
        {
          id: `${id}.numberOfSelectedChoices`,
          key: 'numberOfSelectedChoices',
          type: CapiVariableTypes.NUMBER,
          value: numberOfSelectedChoices,
        },
        {
          id: `${id}.selectedChoice`,
          key: 'selectedChoice',
          type: CapiVariableTypes.NUMBER,
          value: selectedChoice,
        },
        {
          id: `${id}.selectedChoiceText`,
          key: 'selectedChoiceText',
          type: CapiVariableTypes.STRING,
          value: selectedChoiceText,
        },
        {
          id: `${id}.selectedChoices`,
          key: 'selectedChoices',
          type: CapiVariableTypes.ARRAY,
          value: selectedChoices,
        },
        {
          id: `${id}.selectedChoicesText`,
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

  return (
    <div
      data-janus-type={props.type}
      id={id}
      style={styles}
      className={`mcq-input ${customCssClass}`}
    >
      {options?.map((item, index) => (
        <MCQItem
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
          disabled={!enabled}
          multipleSelection={multipleSelection}
        />
      ))}
    </div>
  );
};

export const tagName = 'janus-mcq';

export default MultipleChoiceQuestion;
