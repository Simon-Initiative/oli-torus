/* eslint-disable react/prop-types */
import debounce from 'lodash/debounce';
import React, { CSSProperties, ReactEventHandler, useCallback, useEffect, useState } from 'react';
import { parseBool } from '../../../utils/common';
import { contexts } from '../../../types/applicationContext';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import {
  NotificationType,
  subscribeToNotification,
} from '../../../apps/delivery/components/NotificationContext';
import { JanusAbsolutePositioned, PartComponentProps } from '../types/parts';

interface InputTextModel extends JanusAbsolutePositioned {
  showLabel: boolean;
  label: string;
  prompt: string;
}

const InputText: React.FC<PartComponentProps<InputTextModel>> = (props) => {
  const [state, setState] = useState<any[]>(Array.isArray(props.state) ? props.state : []);
  const [model, setModel] = useState<any>(typeof props.model === 'object' ? props.model : {});
  const [ready, setReady] = useState<boolean>(false);
  const id: string = props.id;

  const [enabled, setEnabled] = useState(true);
  const [cssClass, setCssClass] = useState('');
  const [text, setText] = useState<string>('');

  const initialize = useCallback(async (pModel) => {
    // set defaults
    const dEnabled = typeof pModel.enabled === 'boolean' ? pModel.enabled : enabled;
    setEnabled(dEnabled);

    const dCssClass = pModel.customCssClass || '';
    setCssClass(dCssClass);

    const dText = pModel.text || '';
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
      setEnabled(parseBool(sEnabled));
    }
    const sText = currentStateSnapshot[`stage.${id}.text`];
    if (sText !== undefined) {
      setText(sText);
    }
    const sCssClass = currentStateSnapshot[`stage.${id}.customCssClass`];
    if (sCssClass !== undefined) {
      setCssClass(sCssClass);
    }
    //Instead of hardcoding REVIEW, we can make it an global interface and then importa that here.
    if (initResult.context.mode === contexts.REVIEW) {
      setEnabled(false);
    }
    setReady(true);
  }, []);

  useEffect(() => {
    if (!props.notify) {
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
        /* console.log(`${notificationType.toString()} notification handled [InputText]`, payload); */
        switch (notificationType) {
          case NotificationType.CHECK_STARTED:
            // nothing to do
            break;
          case NotificationType.CHECK_COMPLETE:
            // nothing to do... change color if wrong?
            break;
          case NotificationType.STATE_CHANGED:
            {
              /* console.log('MUTATE STATE!!!!', {
                payload,
              }); */
              const { mutateChanges: changes } = payload;
              const sEnabled = changes[`stage.${id}.enabled`];
              if (sEnabled !== undefined) {
                setEnabled(parseBool(sEnabled));
              }
              const sText = changes[`stage.${id}.text`];
              if (sText !== undefined) {
                setText(sText);
                props.onSave({
                  id,
                  responses: [
                    {
                      key: 'textLength',
                      type: CapiVariableTypes.NUMBER,
                      value: sText.length,
                    },
                  ],
                });
              }
              const sCssClass = changes[`stage.${id}.customCssClass`];
              if (sCssClass !== undefined) {
                setCssClass(sCssClass);
              }
            }
            break;
          case NotificationType.CONTEXT_CHANGED:
            // nothing to do
            break;
        }
      };
      const unsub = subscribeToNotification(props.notify, notificationType, handler);
      return unsub;
    });
    return () => {
      notifications.forEach((unsub) => {
        unsub();
      });
    };
  }, [props.notify]);

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

  const { x, y, z, width, height, showLabel, label, prompt } = model;
  const styles: CSSProperties = {
    position: 'absolute',
    top: y,
    left: x,
    width,
    height,
    zIndex: z,
  };

  const saveInputText = (val: string) => {
    props.onSave({
      id,
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

  const handleOnChange: ReactEventHandler<HTMLInputElement> = (event) => {
    const el = event.target as HTMLInputElement;
    const val = el.value;
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

  // TODO: MUTATE STATE CHANGES

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
