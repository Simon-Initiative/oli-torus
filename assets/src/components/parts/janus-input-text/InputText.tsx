/* eslint-disable react/prop-types */
import debounce from 'lodash/debounce';
import React, { CSSProperties, useCallback, useEffect, useState } from 'react';
import { CapiVariableTypes } from '../../../adaptivity/capi';

const InputText: React.FC<any> = (props) => {
  const id: string = props.id;
  const [ready, setReady] = useState<boolean>(false);
  const [state, setState] = useState<any[]>(Array.isArray(props.state) ? props.state : []);
  const [model, setModel] = useState<any>(Array.isArray(props.model) ? props.model : {});

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
          key: 'enabled',
          type: CapiVariableTypes.BOOLEAN,
          value: enabled,
        },
        {
          key: 'text',
          type: CapiVariableTypes.STRING,
          value: text,
        },
        {
          key: 'textLength',
          type: CapiVariableTypes.NUMBER,
          value: text.length,
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

  const { x, y, z, width, height, customCssClass, showLabel, label, prompt } = model;
  const styles: CSSProperties = {
    position: 'absolute',
    top: y,
    left: x,
    width,
    height,
    zIndex: z,
  };
  const [enabled, setEnabled] = useState(true);
  const [cssClass, setCssClass] = useState(customCssClass);
  const [text, setText] = useState<string>('');

  const saveInputText = (val: string) => {
    props.onSave({
      id: `${id}`,
      responses: [
        {
          key: 'enabled',
          type: CapiVariableTypes.BOOLEAN,
          value: enabled,
        },
        {
          key: 'text',
          type: CapiVariableTypes.STRING,
          value: val,
        },
        {
          key: 'textLength',
          type: CapiVariableTypes.NUMBER,
          value: val.length,
        },
      ],
    });
  };

  const handleOnChange = (event: any) => {
    const val = event.target.value;
    // Update/set the value
    setText(val);
    // Wait until user has stopped typing to save the new value
    debounceInputText(val);
  };
  const debounceWaitTime = 250;
  const debounceInputText = useCallback(
    debounce((val) => saveInputText(val), debounceWaitTime),
    [],
  );

  return ready ? (
    <div data-janus-type={props.type} style={styles} className={`short-text-input ${cssClass}`}>
      <label htmlFor={id}>{showLabel && label ? label : <span>&nbsp;</span>}</label>
      <input
        name="janus-input-text"
        id={id}
        type="text"
        placeholder={prompt}
        onChange={handleOnChange}
        disabled={!enabled}
        value={text}
      />
    </div>
  ) : null;
};

export const tagName = 'janus-input-text';

export default InputText;
