/* eslint-disable react/prop-types */
import { CapiVariableTypes } from '../../../adaptivity/capi';
import debounce from 'lodash/debounce';
import React, { CSSProperties, useCallback, useEffect, useState } from 'react';
import { parseBool } from 'utils/common';
import { CapiVariable } from '../types/parts';

const InputText: React.FC<any> = (props) => {
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
          id: `stage.${id}.enabled`,
          key: 'enabled',
          type: CapiVariableTypes.BOOLEAN,
          value: enabled,
        },
        {
          id: `stage.${id}.text`,
          key: 'text',
          type: CapiVariableTypes.STRING,
          value: text,
        },
        {
          id: `stage.${id}.textLength`,
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
      partResponses: [
        {
          id: `stage.${id}.enabled`,
          key: 'enabled',
          type: CapiVariableTypes.BOOLEAN,
          value: enabled,
        },
        {
          id: `stage.${id}.text`,
          key: 'text',
          type: CapiVariableTypes.STRING,
          value: val,
        },
        {
          id: `stage.${id}.textLength`,
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

  useEffect(() => {
    handleStateChange(state);
  }, [state]);

  const handleStateChange = (vars: CapiVariable[]) => {
    // override text value from state
    const activity = vars.filter((stateVar) => stateVar.id.indexOf(`stage.${id}.`) === 0);
    if (activity?.length) {
      activity.forEach((stateVar) => {
        if (stateVar.key === 'text' && stateVar.value) {
          const stateText = stateVar.value.toString();
          if (text !== stateText) {
            setText(stateText);
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
    }
  };

  return (
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
  );
};

export const tagName = 'janus-input-text';

export default InputText;
