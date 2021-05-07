/* eslint-disable react/prop-types */
import debounce from 'lodash/debounce';
import React, { CSSProperties, useCallback, useEffect, useState } from 'react';

const InputNumber: React.FC<any> = (props) => {
  const [state, setState] = useState<any[]>(Array.isArray(props.state) ? props.state : []);
  const [model, setModel] = useState<any>(Array.isArray(props.model) ? props.model : {});
  const id: string = props.id;

  const {
    x,
    y,
    z,
    width,
    height,
    number = NaN,
    minValue,
    maxValue,
    customCssClass,
    unitsLabel,
    label,
    showLabel,
    enabled = true,
    showIncrementArrows,
  } = model;
  const inputNumberDivStyles: CSSProperties = {
    position: 'absolute',
    top: y,
    left: x,
    zIndex: z,
    width,
  };
  const inputNumberCompStyles: CSSProperties = {
    width,
  };
  const [inputNumberValue, setInputNumberValue] = useState(number ? number : '');
  const [inputNumberEnabled, setInputNumberEnabled] = useState(enabled);
  const debouncetime = 300;
  const debounceSave = useCallback(
    debounce((val) => {
      saveInputText(val);
    }, debouncetime),
    [],
  );

  useEffect(() => {
    if (typeof props?.model === 'string') {
      setModel(JSON.parse(props.model));
    }
    if (typeof props?.state === 'string') {
      setState(JSON.parse(props.state));
    }
  }, [props]);

  useEffect(() => {
    console.log({ state });
  }, [state]);

  const saveInputText = (val: string, isEnabled = true) => {
    return;
    //TODO props.onSavePart is not yet implemented.
    props.onSavePart({
      activityId: `${id}`,
      partResponses: [
        {
          id: `stage.${id}.value`,
          key: 'value',
          type: 2,
          value: val,
        },
        {
          id: `stage.${id}.enabled`,
          key: 'enabled',
          type: 4,
          value: isEnabled,
        },
      ],
    });
  };

  const handleOnChange = (event: any) => {
    setInputNumberValue(event.target.value);
  };

  useEffect(() => {
    let val = isNaN(parseFloat(String(inputNumberValue)))
      ? ''
      : parseFloat(String(inputNumberValue));
    if (minValue !== maxValue && val !== '') {
      val = !isNaN(maxValue) ? Math.min(val as number, maxValue) : val;
      val = !isNaN(minValue) ? Math.max(val as number, minValue) : val;
    }
    if (val !== inputNumberValue) {
      setInputNumberValue(val);
    } else {
      debounceSave(val);
    }
  }, [inputNumberValue]);

  useEffect(() => {
    props.onReady({
      activityId: `${id}`,
      partResponses: [
        {
          id: `stage.${id}.value`,
          key: 'value',
          type: 2,
          value: inputNumberValue || '',
        },
        {
          id: `stage.${id}.enabled`,
          key: 'enabled',
          type: 4,
          value: inputNumberEnabled,
        },
      ],
    });
  }, []);

  return (
    <div data-janus-type={props.type} className="number-input" style={inputNumberDivStyles}>
      {showLabel && (
        <React.Fragment>
          <label htmlFor={id} className="inputNumberLabel">
            {label.length > 0 ? label : ''}
          </label>
          <br />
        </React.Fragment>
      )}
      <input
        type="number"
        disabled={!inputNumberEnabled}
        onChange={handleOnChange}
        id={id}
        min={minValue}
        max={maxValue}
        className={`${customCssClass} ${showIncrementArrows ? '' : 'hideIncrementArrows'}`}
        style={inputNumberCompStyles}
        value={inputNumberValue}
      />
      {unitsLabel && <span className="unitsLabel">{unitsLabel}</span>}
    </div>
  );
};

export const tagName = 'janus-input-number';

export default InputNumber;
