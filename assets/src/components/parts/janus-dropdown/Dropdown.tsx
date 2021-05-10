/* eslint-disable react/prop-types */
import React, { CSSProperties, useEffect, useState } from 'react';

const Dropdown: React.FC<any> = (props) => {
  const [state, setState] = useState<any[]>(Array.isArray(props.state) ? props.state : []);
  const [model, setModel] = useState<any>(Array.isArray(props.model) ? props.model : {});
  const id: string = props.id;
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

  const handleChange = (event: any) => {
    const val = Number(event.target.value);
    // Update/set the value
    setSelection(val);
  };

  useEffect(() => {
    if (typeof props?.model === 'string') {
      setModel(JSON.parse(props.model));
    }
    if (typeof props?.state === 'string') {
      setState(JSON.parse(props.state));
    }
  }, [props]);

  useEffect(() => {
    //TODO handle value changes on state updates
  }, [state]);

  useEffect(() => {
    props.onReady({
      activityId: `${id}`,
      partResponses: [
        {
          id: `stage.${id}.enabled`,
          key: 'enabled',
          type: 4,
          value: true,
        },
        {
          id: `stage.${id}.selectedIndex`,
          key: 'selectedIndex',
          type: 1,
          value: -1,
        },
        {
          id: `stage.${id}.selectedItem`,
          key: 'selectedItem',
          type: 2,
          value: '',
        },
        {
          id: `stage.${id}.value`,
          key: 'value',
          type: 2,
          value: 'NULL',
        },
      ],
    });
  }, []);

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
