import React, { CSSProperties, useEffect } from 'react';
import { AuthorPartComponentProps } from 'components/parts/types/parts';
import { sanitizeRichLabelHtml } from '../../../utils/richOptionLabel';
import { DropdownModel } from './schema';

const DropdownAuthor: React.FC<AuthorPartComponentProps<DropdownModel>> = (props) => {
  const { id, model } = props;

  const { width, showLabel, label, prompt, optionLabels } = model;
  const styles: CSSProperties = {
    width,
    position: 'relative',
    display: 'inline-flex',
    flexDirection: 'column',
    gap: '4px',
  };
  const dropDownStyle: CSSProperties = {
    width: '100%',
    height: 'auto',
    cursor: 'move',
  };
  useEffect(() => {
    // all activities *must* emit onReady
    props.onReady({ id: `${props.id}` });
  }, []);
  const dropdownOptions = () => {
    // use explicit Array() since we're using Elements
    const options = [];

    if (prompt) {
      // If a prompt exists and the selectedIndex is not set or is set to -1, set prompt as disabled first option.
      options.push(
        <option key="-1" value="-1" style={{ display: 'none' }}>
          {prompt}
        </option>,
      );
    }
    if (optionLabels) {
      for (let i = 0; i < optionLabels.length; i++) {
        options.push(
          <option key={i + 1} value={i + 1}>
            {optionLabels[i]}
          </option>,
        );
      }
    }
    return options;
  };
  return (
    <div data-janus-type={tagName} className="dropdown-input" style={styles}>
      <label
        htmlFor={`${id}-select`}
        dangerouslySetInnerHTML={{ __html: showLabel && label ? sanitizeRichLabelHtml(label) : '' }}
      />
      <select
        style={dropDownStyle}
        id={`${id}-select`}
        defaultValue="-1"
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
