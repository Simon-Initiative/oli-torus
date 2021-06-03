/* eslint-disable react/prop-types */
import debounce from 'lodash/debounce';
import React, { CSSProperties, useCallback, useEffect, useRef, useState } from 'react';
import { parseBool } from 'utils/common';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import { CapiVariable } from '../types/parts';

const MultiLineTextInput: React.FC<any> = (props) => {
  const [state, setState] = useState<any[]>(Array.isArray(props.state) ? props.state : []);
  const [model, setModel] = useState<any>(Array.isArray(props.model) ? props.model : {});
  const [ready, setReady] = useState<boolean>(false);
  const id: string = props.id;

  const characterCounterRef = useRef<any>(null);
  const [text, setText] = useState<string>('');
  const [enabled, setEnabled] = useState(true);
  const [cssClass, setCssClass] = useState('');

  const initialize = useCallback(async (pModel) => {
    // set defaults
    const dEnabled = typeof pModel.enabled === 'boolean' ? pModel.enabled : enabled;
    setEnabled(dEnabled);

    const dCssClass = pModel.customCssClass || '';
    setCssClass(dCssClass);

    const dText = pModel.initValue || '';
    setText(dText);

    const initResult = await props.onInit({
      id,
      responses: [
        {
          key: 'enabled',
          type: CapiVariableTypes.BOOLEAN,
          value: dEnabled,
        },
        {
          key: 'customCssClass',
          type: CapiVariableTypes.STRING,
          value: dCssClass,
        },
        {
          key: 'text',
          type: CapiVariableTypes.STRING,
          value: dText,
        },
        {
          key: 'textLength',
          type: CapiVariableTypes.NUMBER,
          value: dText.length,
        },
      ],
    });

    // result of init has a state snapshot with latest (init state applied)
    const currentStateSnapshot = initResult.snapshot;
    const sEnabled = currentStateSnapshot[`stage.${id}.enabled`];
    if (sEnabled !== undefined) {
      setEnabled(sEnabled);
    }
    const sText = currentStateSnapshot[`stage.${id}.text`];
    if (sText !== undefined) {
      setText(sText);
    }
    const sCssClass = currentStateSnapshot[`stage.${id}.customCssClass`];
    if (sCssClass !== undefined) {
      setCssClass(sCssClass);
    }

    setReady(true);
  }, []);

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
    initialize(pModel);
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

  useEffect(() => {
    //TODO commenting for now. Need to revisit once state structure logic is in place
    //handleStateChange(state);
  }, [state]);

  const saveInputText = (val: string) => {
    props.onSave({
      id: `${id}`,
      responses: [
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
    characterCounterRef.current.innerText = val.length;
    setText(val);
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
        if (text !== stateText) {
          setText(stateText);
        }
        props.onSave({
          id: `${id}`,
          responses: [
            {
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

  const initialCharacterCount = text.length || 0;

  return ready ? (
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
        value={text}
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
  ) : null;
};

export const tagName = 'janus-multi-line-text';

export default MultiLineTextInput;
