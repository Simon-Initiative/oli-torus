/* eslint-disable no-prototype-builtins */

/* eslint-disable react/prop-types */
import React, { useCallback, useEffect, useState } from 'react';
import debounce from 'lodash/debounce';
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
          style={{ flex: '1', minWidth: 75 }}
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
          style={{ flex: '1', minWidth: 75 }}
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
        <div className="user-input">
          <select onChange={handleValueChange} className="custom-select custom-select-sm">
            {value?.allowedValues?.map((item: any) => {
              return (
                <option key={item} value={item} selected={internalValue === item}>
                  {item}
                </option>
              );
            })}
          </select>
        </div>
      );

    default:
      return (
        <input
          type="text"
          style={{ flex: '1', minWidth: 75 }}
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
