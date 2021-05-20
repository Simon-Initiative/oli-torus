/* eslint-disable react/prop-types */
import { CapiVariableTypes } from '../../../adaptivity/capi';
import debounce from 'lodash/debounce';
import React, { CSSProperties, useCallback, useEffect, useRef, useState } from 'react';
import { parseBool } from 'utils/common';
import { CapiVariable } from '../types/parts';

const MultiLineTextInput: React.FC<any> = (props) => {
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
          id: `stage.${id}.text`,
          key: 'text',
          type: CapiVariableTypes.STRING,
          value: value,
        },
        {
          id: `stage.${id}.textLength`,
          key: 'textLength',
          type: CapiVariableTypes.NUMBER,
          value: value.length,
        },
        {
          id: `stage.${id}.enabled`,
          key: 'enabled',
          type: CapiVariableTypes.BOOLEAN,
          value: enabled,
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
    handleStateChange(state);
  }, [state]);

  const saveInputText = (val: string) => {
    props.onSave({
      id: `${id}`,
      partResponses: [
        {
          id: `stage.${id}.enabled`,
          key: 'enabled',
          type: 4,
          value: enabled,
        },
        {
          id: `stage.${id}.text`,
          key: 'text',
          type: 2,
          value: val,
        },
        {
          id: `stage.${id}.textLength`,
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

  const handleStateChange = (stateData: CapiVariable[]) => {
    // override text value from state
    const activity = stateData.filter((stateVar) => stateVar.id.indexOf(`stage.${id}.`) === 0);
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
              id: `stage.${id}.textLength`,
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
