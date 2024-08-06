import React, { CSSProperties, useEffect } from 'react';
import { AuthorPartComponentProps } from 'components/parts/types/parts';
import { DropdownModel } from './schema';

const DropdownAuthor: React.FC<AuthorPartComponentProps<DropdownModel>> = (props) => {
  const { id, model } = props;

  const { width, showLabel, label, prompt, optionLabels } = model;
  const styles: CSSProperties = {
    width,
  };
  const dropDownStyle: CSSProperties = {
    width: 'auto',
    height: 'auto',
    cursor: 'move',
  };
  if (!(showLabel && label)) {
    dropDownStyle.width = `${Number(width) - 10}px`;
  }
  if (showLabel && label && width) {
    //is this the best way to handle?
    //if lable is visible then need to set the maxWidth otherwise it gets out of the container
    dropDownStyle.maxWidth = `${Number(width * 0.63)}px`;
  }
  useEffect(() => {
    // all activities *must* emit onReady
    props.onReady({ id: `${props.id}` });
  }, []);
  const dropdownOptions = () => {
    // use explicit Array() since we're using Elements
    const options = [];

    if (prompt) {
      // If a prompt exists and the selectedIndex is not set or is set to -1, set prompt as disabled first option
      options.push(
        <option key="-1" value="-1" style={{ display: 'none' }}>
          {prompt}
        </option>,
      );
    }
    if (optionLabels) {
      for (let i = 0; i < optionLabels.length; i++) {
        // Set selected if selectedIndex equals current index
        options.push(
          <option key={i + 1} value={i + 1} selected={i + 1 === -1}>
            {optionLabels[i]}
          </option>,
        );
      }
    }
    return options;
  };
  return (
    <div data-janus-type={tagName} className="dropdown-input" style={styles}>
      <label htmlFor={`${id}-select`}>{showLabel && label ? label : ''}</label>
      <select
        style={dropDownStyle}
        id={`${id}-select`}
        value={-1}
        className={'dropdown '}
        onMouseDown={(e) => {
          e.preventDefault();
        }}
      >
        {dropdownOptions()}
      </select>
    </div>
  );
};

export const tagName = 'janus-dropdown';

export default DropdownAuthor;
