/* eslint-disable react/prop-types */
import { CapiVariableTypes } from '../../../adaptivity/capi';
import React, { CSSProperties, useEffect, useState } from 'react';
import { parseBool } from 'utils/common';
import { CapiVariable } from '../types/parts';

const Dropdown: React.FC<any> = (props) => {
  const [state, setState] = useState<any[]>(Array.isArray(props.state) ? props.state : []);
  const [model, setModel] = useState<any>(Array.isArray(props.model) ? props.model : {});
  const [ready, setReady] = useState<boolean>(false);
  const id: string = props.id;
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
    props.onInit({
      id,
      responses: [
        {
          id: `enabled`,
          key: 'enabled',
          type: CapiVariableTypes.BOOLEAN,
          value: true,
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
    setReady(true);
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
  const [enabled, setEnabled] = useState(true);
  const [selection, setSelection] = useState<number>(-1);
  const [selectedItem, setSelectedItem] = useState<string>('');

  const dropDownStyle = {
    width: 'auto',
    height: 'auto',
  };
  if (!(showLabel && label)) {
    dropDownStyle.width = `${Number(width) - 10}px`;
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

  const handleStateChange = (stateData: CapiVariable[]) => {
    // override text value from state
    //** Changed `stage.${id}` to `` and this might need to be done in all the components*
    //** reason of doing this is if there are multiple variables with Ids - dropdownInput, dropdownInput2 & dropdownInput3/
    //** doing `stage.${id}` always get all the variables starting with dropdownInput instead of just filtering variables with dropdownInput id*/
    const interested = stateData.filter(
      (stateVar: { id: string | string[] }) => stateVar.id.indexOf(`stage.${id}.`) === 0,
    );
    if (interested?.length) {
      interested.forEach((stateVar) => {
        switch (stateVar.key) {
          case 'selectedIndex':
            {
              // handle selectedItem, which is a number/index
              const stateSelection = Number(stateVar.value);
              if (selection !== stateSelection) {
                setSelection(stateSelection);
                setSelectedItem(optionLabels[stateSelection - 1]);
              }
            }
            break;
          case 'selectedItem':
            // handle selectedItem, which is a string
            {
              const stateSelectedItem = String(stateVar.value);
              if (selectedItem !== stateSelectedItem) {
                const selectionIndex: number = optionLabels.findIndex((str: string) =>
                  stateSelectedItem.includes(str),
                );
                setSelectedItem(stateSelectedItem);
                setSelection(selectionIndex + 1);
              }
            }
            break;
          case 'enabled':
            // check for boolean and string truthiness
            setEnabled(parseBool(stateVar.value));
            break;
        }
      });
    }
  };

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

  return (
    <div data-janus-type={props.type} className="dropdown-input" style={dropdownContainerStyles}>
      <label htmlFor={id}>{showLabel && label ? label : ''}</label>
      <select
        style={dropDownStyle}
        id={id}
        value={selection}
        className={'dropdown ' + customCssClass}
        onChange={handleChange}
        disabled={!enabled}
      >
        {dropdownOptions()}
      </select>
    </div>
  );
};

export const tagName = 'janus-dropdown';

export default Dropdown;
