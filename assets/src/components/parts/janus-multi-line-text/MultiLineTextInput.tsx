/* eslint-disable react/prop-types */
import { CapiVariableTypes } from '../../../adaptivity/capi';
import debounce from 'lodash/debounce';
import React, { CSSProperties, useCallback, useEffect, useRef, useState } from 'react';
import { parseBool } from 'utils/common';
import { StateVariable } from '../types/parts';

const MultiLineTextInput: React.FC<any> = (props) => {
  const [state, setState] = useState<any[]>(Array.isArray(props.state) ? props.state : []);
  const [model, setModel] = useState<any>(Array.isArray(props.model) ? props.model : {});
  const id: string = props.id;
  const {
    label,
    x = 0,
    y = 0,
    z = 0,
    width,
    height,
    prompt,
    customCssClass,
    initValue,
    showLabel,
    showCharacterCount,
  } = model;

  // Set up the styles
  const wrapperStyles: CSSProperties = {
    position: 'absolute',
    top: y,
    left: x,
    width,
    height,
    zIndex: z,
  };
  const inputStyles: CSSProperties = {
    width,
    height,
    resize: 'none',
  };
  const initialCharacterCount = initValue?.length || 0;
  const characterCounterRef = useRef<any>(null);
  const [value, setValue] = useState<string>(initValue || '');
  const [enabled, setEnabled] = useState(true);
  const [cssClass, setCssClass] = useState(customCssClass);

  useEffect(() => {
    if (typeof props?.model === 'string') {
      setModel(JSON.parse(props.model));
    }
    if (typeof props?.state === 'string') {
      setState(JSON.parse(props.state));
    }
  }, [props]);

  useEffect(() => {
    handleStateChange(state);
  }, [state]);

  const saveInputText = (val: string) => {
    props.onSave({
      id: `${id}`,
      partResponses: [
        {
          id: `${id}.enabled`,
          key: 'enabled',
          type: 4,
          value: enabled,
        },
        {
          id: `${id}.text`,
          key: 'text',
          type: 2,
          value: val,
        },
        {
          id: `${id}.textLength`,
          key: 'textLength',
          type: 1,
          value: val.length,
        },
      ],
    });
  };
  const handleOnChange = (event: any) => {
    const val = event.target.value;
    characterCounterRef.current.innerText = val.length;
    setValue(val);
    // Wait until user has stopped typing to save the new value
    debounceInputText(val);
  };
  const debounceWaitTime = 250;
  const debounceInputText = useCallback(
    debounce((val) => saveInputText(val), debounceWaitTime),
    [],
  );

  const handleStateChange = (stateData: StateVariable[]) => {
    // override text value from state
    const activity = stateData.filter((stateVar) => stateVar.id.indexOf(`${id}.`) === 0);
    activity.forEach((stateVar) => {
      if (stateVar && stateVar.value && stateVar.key === 'text') {
        const stateText = stateVar.value.toString();
        if (value !== stateText) {
          setValue(stateText);
        }
        props.onSave({
          activityId: `${id}`,
          partResponses: [
            {
              id: `${id}.textLength`,
              key: 'textLength',
              type: CapiVariableTypes.NUMBER,
              value: stateText.length,
            },
          ],
        });
      }
      if (stateVar && stateVar.key === 'enabled') {
        setEnabled(parseBool(stateVar.value));
      }
      if (stateVar && stateVar.key === 'customCssClass') {
        setCssClass(stateVar.value.toString());
      }
    });
  };

  useEffect(() => {
    props.onReady({
      id: `${id}`,
      partResponses: [],
    });
  }, []);

  return (
    <div
      data-janus-type={props.type}
      className={`long-text-input ${cssClass}`}
      style={wrapperStyles}
    >
      <label
        htmlFor={id}
        style={{
          display: showLabel ? 'inline-block' : 'none',
        }}
      >
        {label}
      </label>
      <textarea
        name="test"
        id={id}
        onChange={handleOnChange}
        style={inputStyles}
        placeholder={prompt}
        value={value}
        disabled={!enabled}
      />
      <div
        title="Number of characters"
        className="characterCounter"
        style={{
          padding: '0px',
          color: 'rgba(0,0,0,0.6)',
          display: showCharacterCount ? 'block' : 'none',
          width: '250px',
          fontSize: '12px',
          fontFamily: 'Arial',
          textAlign: 'right',
        }}
      >
        <span
          className={`span_${id}`}
          ref={characterCounterRef}
          style={{
            padding: '0px',
            fontFamily: 'Arial',
          }}
        >
          {initialCharacterCount}
        </span>
      </div>
    </div>
  );
};

export const tagName = 'janus-multi-line-text';

export default MultiLineTextInput;
