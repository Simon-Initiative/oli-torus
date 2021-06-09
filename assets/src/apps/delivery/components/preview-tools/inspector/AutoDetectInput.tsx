/* eslint-disable no-prototype-builtins */
/* eslint-disable react/prop-types */
import debounce from 'lodash/debounce';
import React, { useCallback, useEffect, useState } from 'react';
import { v4 as uuidv4 } from 'uuid';
import { CapiVariable, CapiVariableTypes, parseCapiValue } from '../../../../../adaptivity/capi';
import { ApplyStateOperation } from '../../../../../adaptivity/scripting';

interface AutoDetectInputProps {
  label: string;
  value: any;
  state?: any;
  onChange?: (changeOp: ApplyStateOperation) => void;
}
const AutoDetectInput: React.FC<AutoDetectInputProps> = ({
  label,
  value,
  state,
  onChange,
}): any => {
  /* console.log('🚀 > file: PreviewTools.tsx > line 390 > { label, value ,state}', {
    label,
    value,
    state,
  }); */
  const theValue = value as CapiVariable;

  const postChange = useCallback(
    debounce((changedValue) => {
      theValue.value = changedValue;
      const applyOp: ApplyStateOperation = {
        target: theValue.key,
        operator: '=',
        type: theValue.type,
        value: parseCapiValue(theValue),
      };
      if (onChange) {
        onChange(applyOp);
      }
    }, 50),
    [theValue],
  );

  const handleValueChange = useCallback(
    (e, isCheckbox = false) => {
      if (e.type === 'keydown' && e.key !== 'Enter') {
        return;
      }
      const newValue = isCheckbox ? e.target.checked : e.target.value;
      setInternalValue(parseCapiValue(newValue));
      /* console.log('VALUE CHANGE INSPECTOR', { e, newValue, theValue }); */
      if (newValue === theValue.value) {
        return;
      }
      postChange(newValue);
    },
    [onChange],
  );

  const [internalValue, setInternalValue] = useState<any>(parseCapiValue(theValue));

  useEffect(() => {
    setInternalValue(parseCapiValue(theValue));
  }, [theValue]);

  const uuid = uuidv4();
  switch (theValue.type) {
    case CapiVariableTypes.BOOLEAN:
      return (
        <div className="custom-control custom-switch">
          <input
            type="checkbox"
            className="custom-control-input"
            id={uuid}
            checked={internalValue}
            onChange={(e) => handleValueChange(e, true)}
            onBlur={(e) => handleValueChange(e, true)}
          />
          <label className="custom-control-label" htmlFor={uuid}></label>
        </div>
      );

    case CapiVariableTypes.NUMBER:
      return (
        <input
          type="number"
          className="input-group-sm stateValue"
          aria-label={label}
          value={internalValue}
          onKeyDown={handleValueChange}
          onBlur={handleValueChange}
          onChange={handleValueChange}
        />
      );

    case CapiVariableTypes.ARRAY:
    case CapiVariableTypes.ARRAY_POINT:
      // TODO: fancy array editor??
      return (
        <input
          type="text"
          className="input-group-sm stateValue"
          aria-label={label}
          value={JSON.stringify(internalValue)}
          onKeyDown={handleValueChange}
          onBlur={handleValueChange}
          onChange={handleValueChange}
        />
      );

    case CapiVariableTypes.ENUM:
      return (
        // TODO : wire this up
        <div className="user-input">
          <span className="stateKey" title="session.visits.q:1541198781354:733">
            q:1541198781354:733
          </span>
          {/* Dropdown example */}
          <select className="custom-select custom-select-sm" defaultValue="3">
            <option value="1">One</option>
            <option value="2">Two</option>
            <option value="3">Three</option>
            <option value="4">
              This option has a very long text node that may stretch out the drop down. What
              happens?
            </option>
          </select>
        </div>
      );

    default:
      return (
        <input
          type="text"
          className="input-group-sm stateValue"
          aria-label={label}
          value={internalValue}
          onKeyDown={handleValueChange}
          onBlur={handleValueChange}
          onChange={handleValueChange}
        />
      );
  }
};

export default AutoDetectInput;
