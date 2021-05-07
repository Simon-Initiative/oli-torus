/* eslint-disable react/prop-types */
import debounce from 'lodash/debounce';
import React, { CSSProperties, useCallback, useEffect, useState } from 'react';

const InputText: React.FC<any> = (props) => {
  const [state, setState] = useState<any[]>(Array.isArray(props.state) ? props.state : []);
  const [model, setModel] = useState<any>(Array.isArray(props.model) ? props.model : {});

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
    // This will call onSaveActivity
    console.log(val);
  };
  const handleChange = (event: any) => {
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
    if (typeof props?.model === 'string') {
      setModel(JSON.parse(props.model));
    }
    if (typeof props?.state === 'string') {
      setState(JSON.parse(props.state));
    }
  }, [props]);

  useEffect(() => {
    //TODO handle value changes on state updates
    console.log({ state });
  }, [state]);

  useEffect(() => {
    props.onReady({
      activityId: `${props.id}`,
      partResponses: [],
    });
  }, []);

  return (
    <div data-janus-type={props.type} style={styles} className={`short-text-input ${cssClass}`}>
      <label htmlFor={props.id}>{showLabel && label ? label : <span>&nbsp;</span>}</label>
      <input
        name="janus-input-text"
        id={props.id}
        type="text"
        placeholder={prompt}
        onChange={handleChange}
        disabled={!enabled}
        value={text}
      />
    </div>
  );
};

export const tagName = 'janus-input-text';

export default InputText;
