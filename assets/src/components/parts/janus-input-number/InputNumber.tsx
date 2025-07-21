import React, {
  CSSProperties,
  ReactEventHandler,
  useCallback,
  useEffect,
  useMemo,
  useState,
} from 'react';
import debounce from 'lodash/debounce';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import {
  NotificationType,
  subscribeToNotification,
} from '../../../apps/delivery/components/NotificationContext';
import { contexts } from '../../../types/applicationContext';
import { countSigFigs, parseBool } from '../../../utils/common';
import { PartComponentProps } from '../types/parts';
import './InputNumber.scss';
import { InputNumberModel } from './schema';

/**
 * If you pass in a string, return the JSON.parse, otherwise return the same value.
 *
 * maybeParseJson('{"a": 1}') => {a: 1}
 * maybeParseJson({"a": 1}) => {a: 1}
 *
 */
const maybeParseJson = (value: any) => {
  if (typeof value === 'string') {
    try {
      return JSON.parse(value);
    } catch (err) {
      // bad json, what do?
      console.error("Couldn't parse JSON to number input", value, err);
    }
  }

  return value;
};

const InputNumber: React.FC<PartComponentProps<InputNumberModel>> = ({
  id,
  model: inputModel,
  notify,
  onSave,
  onInit,
  onReady,
  onResize,
}) => {
  //const debugRef = useRef(props);
  const model = useMemo(() => maybeParseJson(inputModel), [inputModel]);

  const [ready, setReady] = useState<boolean>(false);
  const [inputNumberValue, setInputNumberValue] = useState<string | number>('');
  const [enabled, setEnabled] = useState(true);

  const {
    x,
    y,
    z,
    width,
    minValue,
    maxValue,
    unitsLabel,
    label,
    showLabel,
    showIncrementArrows,
    prompt = '',
  } = model;

  /**
   * Given a value, return either a number or an empty string, the value will be between
   * minValue and maxValue inclusive.
   *
   * sanitizeValue(1) => 1
   * sanitizeValue(1.2) => 1
   * sanitizeValue('1') => 1
   * sanitizeValue('1.2') => 1.2
   * sanitizeValue('buffalo') => ''
   * sanitizeValue(null) => ''
   * sanitizeValue(undefined) => ''
   * sanitizeValue('') => ''
   *
   * minValue=0, maxValue=10
   * sanitizeValue(11) => 10
   * sanitizeValue(-1) => 0
   *
   */
  const sanitizeValue = useCallback(
    (value: number | string | null | undefined): number | string => {
      let val = isNaN(parseFloat(String(value))) ? '' : parseFloat(String(value));

      if (minValue !== maxValue && val !== '') {
        val = !isNaN(maxValue) ? Math.min(val as number, maxValue) : val;
        val = !isNaN(minValue) ? Math.max(val as number, minValue) : val;
      }
      return val;
    },
    [minValue, maxValue],
  );

  const initialize = useCallback(async () => {
    // set defaults
    const dEnabled = typeof model.enabled === 'boolean' ? model.enabled : true;
    setEnabled(dEnabled);

    const initResult = await onInit({
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
          value: '',
        },
        {
          key: 'customCssClass',
          type: CapiVariableTypes.STRING,
          value: model.customCssClass || '',
        },
        {
          key: 'Number of sigfigs',
          type: CapiVariableTypes.NUMBER,
          value: 0,
        },
      ],
    });

    // result of init has a state snapshot with latest (init state applied)
    const currentStateSnapshot = initResult.snapshot;
    const sEnabled = currentStateSnapshot[`stage.${id}.enabled`];
    if (sEnabled !== undefined) {
      setEnabled(parseBool(sEnabled));
    }
    const sValue = currentStateSnapshot[`stage.${id}.value`];
    if (sValue !== undefined) {
      setInputNumberValue(sValue);
    }

    //Instead of hardcoding REVIEW, we can make it an global interface and then importa that here.
    if (initResult.context.mode === contexts.REVIEW) {
      setEnabled(false);
    }
    setReady((currentValue) => {
      if (currentValue) {
        console.warn(
          'InputNumber was previously initialized, but initialize was called again. This is probably a bug and would be caused by one of these props changing: id, onInit, onReady, model',
          { id, model },
        );
      }
      return true;
    });

    onReady({ id, responses: [] });
  }, [id, onInit, onReady, model]);

  useEffect(() => {
    if (!notify) {
      return;
    }
    const notificationsHandled = [
      NotificationType.CHECK_STARTED,
      NotificationType.CHECK_COMPLETE,
      NotificationType.CONTEXT_CHANGED,
      NotificationType.STATE_CHANGED,
    ];
    const notifications = notificationsHandled.map((notificationType: NotificationType) => {
      const handler = (payload: any) => {
        /* console.log(`${notificationType.toString()} notification handled [InputNumber]`, payload); */
        switch (notificationType) {
          case NotificationType.CHECK_STARTED:
            // nothing to do
            break;
          case NotificationType.CHECK_COMPLETE:
            // nothing to do
            break;
          case NotificationType.STATE_CHANGED:
            {
              const { mutateChanges: changes } = payload;
              const sEnabled = changes[`stage.${id}.enabled`];
              if (sEnabled !== undefined) {
                setEnabled(parseBool(sEnabled));
              }
              const sValue = changes[`stage.${id}.value`];
              if (sValue !== undefined) {
                setInputNumberValue(sValue);
              }
            }
            break;
          case NotificationType.CONTEXT_CHANGED:
            {
              const { initStateFacts } = payload;

              const sEnabled = initStateFacts[`stage.${id}.enabled`];
              if (sEnabled !== undefined) {
                setEnabled(parseBool(sEnabled));
              }
              const sValue = initStateFacts[`stage.${id}.value`];
              if (sValue !== undefined) {
                setInputNumberValue(sValue);
              }

              if (payload.mode === contexts.REVIEW) {
                setEnabled(false);
              }
            }
            break;
        }
      };
      const unsub = subscribeToNotification(notify, notificationType, handler);
      return unsub;
    });
    return () => {
      notifications.forEach((unsub) => {
        unsub();
      });
    };
  }, [id, notify]);

  useEffect(() => {
    initialize();
  }, [initialize]);

  const inputNumberDivStyles: CSSProperties = {
    top: y,
    left: x,
    zIndex: z,
    width,
  };

  const inputNumberCompStyles: CSSProperties = {
    width: '100%',
  };

  useEffect(() => {
    const styleChanges: any = {};
    if (width !== undefined) {
      styleChanges.width = { value: width as number };
    }
    onResize({ id: `${id}`, settings: styleChanges });
  }, [id, width, onResize]);

  const saveInputText = useCallback(
    (normalizedValue: number, rawInput: string) => {
      const numberOFSigfigs = countSigFigs(rawInput);
      onSave({
        id: `${id}`,
        responses: [
          {
            key: 'value',
            type: CapiVariableTypes.NUMBER,
            value: normalizedValue,
          },
          {
            key: 'Number of sigfigs',
            type: CapiVariableTypes.NUMBER,
            value: numberOFSigfigs,
          },
        ],
      });
    },
    [id, onSave],
  );

  const debouncetime = 300;
  // eslint-disable-next-line react-hooks/exhaustive-deps
  const debounceSave = useCallback(
    debounce((normalizedValue, rawInput) => {
      saveInputText(normalizedValue, rawInput);
    }, debouncetime),
    [saveInputText],
  );

  const handleOnChange: ReactEventHandler<HTMLInputElement> = (event) => {
    // We preserve rawInput (user-typed string) to accurately count significant figures.
    // For example, "5.0" has 2 sigfigs, while "5" has only 1 — this detail is lost after parsing.
    const rawInput = (event.target as HTMLInputElement).value;
    const normalizedValue = sanitizeValue(rawInput);
    setInputNumberValue(normalizedValue);
    debounceSave(normalizedValue, rawInput);
  };

  return ready ? (
    <div data-janus-type={tagName} style={inputNumberDivStyles} className={`number-input`}>
      {showLabel && (
        <React.Fragment>
          <label htmlFor={`${id}-number-input`} className="inputNumberLabel">
            {label?.length > 0 ? label : ''}
          </label>
          <br />
        </React.Fragment>
      )}
      <input
        type="number"
        disabled={!enabled}
        onChange={handleOnChange}
        id={`${id}-number-input`}
        min={minValue}
        max={maxValue}
        placeholder={prompt}
        className={`${showIncrementArrows ? '' : 'hideIncrementArrows'}`}
        style={inputNumberCompStyles}
        value={inputNumberValue}
      />
      {unitsLabel && <span className="unitsLabel">{unitsLabel}</span>}
    </div>
  ) : null;
};

export const tagName = 'janus-input-number';

export default InputNumber;
