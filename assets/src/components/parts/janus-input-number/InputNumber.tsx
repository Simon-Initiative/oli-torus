/* eslint-disable react/prop-types */
import debounce from 'lodash/debounce';
import React, { CSSProperties, useCallback, useEffect, useState } from 'react';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import { CapiVariable } from '../types/parts';

const InputNumber: React.FC<any> = (props) => {
  const [state, setState] = useState<any[]>(Array.isArray(props.state) ? props.state : []);
  const [model, setModel] = useState<any>(Array.isArray(props.model) ? props.model : {});
  const [ready, setReady] = useState<boolean>(false);
  const id: string = props.id;

  const [inputNumberValue, setInputNumberValue] = useState<string | number>('');
  const [enabled, setEnabled] = useState(true);
  const [cssClass, setCssClass] = useState('');

  const initialize = useCallback(async (pModel) => {
    // set defaults
    const dEnabled = typeof pModel.enabled === 'boolean' ? pModel.enabled : enabled;
    setEnabled(dEnabled);

    const dCssClass = pModel.customCssClass || '';
    setCssClass(dCssClass);

    // test undefined because 0 is falsey yet valid
    const dValue = pModel.value !== undefined ? pModel.value : '';
    setInputNumberValue(dValue);

    const initResult = await props.onInit({
      id,
      responses: [
        {
          key: 'enabled',
          type: CapiVariableTypes.BOOLEAN,
          value: dEnabled,
        },
        {
          key: 'value',
          type: CapiVariableTypes.NUMBER,
          value: dValue,
        },
        {
          key: 'customCssClass',
          type: CapiVariableTypes.STRING,
          value: dCssClass,
        },
      ],
    });

    // result of init has a state snapshot with latest (init state applied)
    const currentStateSnapshot = initResult.snapshot;
    const sEnabled = currentStateSnapshot[`stage.${id}.enabled`];
    if (sEnabled !== undefined) {
      setEnabled(sEnabled);
    }
    const sValue = currentStateSnapshot[`stage.${id}.value`];
    if (sValue !== undefined) {
      setInputNumberValue(sValue);
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
    x,
    y,
    z,
    width,
    height,
    minValue,
    maxValue,
    customCssClass,
    unitsLabel,
    label,
    showLabel,
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

  const debouncetime = 300;
  const debounceSave = useCallback(
    debounce((val) => {
      saveInputText(val);
    }, debouncetime),
    [],
  );

  useEffect(() => {
    //TODO commenting for now. Need to revisit once state structure logic is in place
    //handleStateChange(state);
  }, [state]);

  const handleStateChange = (data: CapiVariable[]) => {
    const interested = data.filter((stateVar) => stateVar.id.indexOf(`stage.${id}.`) === 0);
    if (interested?.length) {
      interested.forEach((stateVar) => {
        if (stateVar.key === 'value') {
          setInputNumberValue(stateVar.value as number);
        }
        if (stateVar.key === 'enabled') {
          setEnabled(stateVar.value as boolean);
        }
      });
    }
  };

  const saveInputText = (val: number, isEnabled = true) => {
    props.onSave({
      id: `${id}`,
      responses: [
        {
          key: 'value',
          type: CapiVariableTypes.NUMBER,
          value: val,
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

  return ready ? (
    <div
      data-janus-type={props.type}
      className={`number-input ${cssClass}`}
      style={inputNumberDivStyles}
    >
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
        disabled={!enabled}
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
  ) : null;
};

export const tagName = 'janus-input-number';

export default InputNumber;
