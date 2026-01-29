/* eslint-disable react/prop-types */
import React, { CSSProperties, ChangeEvent, useCallback, useEffect, useRef, useState } from 'react';
import debounce from 'lodash/debounce';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import {
  NotificationType,
  subscribeToNotification,
} from '../../../apps/delivery/components/NotificationContext';
import { contexts } from '../../../types/applicationContext';
import { PartComponentProps } from '../types/parts';
import './MultiLineTextInput.scss';
import { MultiLineTextModel } from './schema';

const MultiLineTextInput: React.FC<PartComponentProps<MultiLineTextModel>> = (props) => {
  const [state, setState] = useState<any[]>(Array.isArray(props.state) ? props.state : []);
  const [model, setModel] = useState<any>(Array.isArray(props.model) ? props.model : {});
  const [ready, setReady] = useState<boolean>(false);
  const id: string = props.id;

  const characterCounterRef = useRef<HTMLSpanElement>(null);
  const characterCounterSrRef = useRef<HTMLSpanElement>(null);
  const [text, setText] = useState<string>('');
  const [enabled, setEnabled] = useState(true);
  const [_cssClass, setCssClass] = useState('');
  const lastAnnouncedCountRef = useRef<number>(-1);

  // Generate IDs for ARIA attributes
  const labelId = `${id}-label`;
  const characterCounterId = `${id}-character-count`;

  // Helper function to safely get character count, defaulting to 0 if invalid
  const getCharacterCount = (textValue: string | undefined | null): number => {
    if (textValue == null) return 0;
    const length = typeof textValue === 'string' ? textValue.length : 0;
    return isNaN(length) ? 0 : length;
  };

  // Helper function to update screen reader character counter (only if count changed)
  const updateCharacterCounterSr = (textValue: string | undefined | null) => {
    if (characterCounterSrRef.current) {
      const count = getCharacterCount(textValue);
      // Only update if the count has actually changed to prevent duplicate announcements
      if (count !== lastAnnouncedCountRef.current) {
        characterCounterSrRef.current.textContent = `Character count: ${count}`;
        lastAnnouncedCountRef.current = count;
      }
    }
  };

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
      setText((prevText) => {
        const newText = sText.toString();
        if (prevText !== newText) {
          saveInputText(newText);
          updateCharacterCounterSr(newText);
        }
        // strings wont trigger a re-render if they haven't changed
        return newText;
      });
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

  const { label, width, height, prompt, showLabel, showCharacterCount, fontSize } = model;

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
        /* console.log(
          `${notificationType.toString()} notification handled [%cMultiline text Input%c]`,
          'color: lime;',
          'color: black;',
          payload,
        ); */
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
              const sText = changes[`stage.${id}.text`];
              if (sText !== undefined) {
                setText((prevText) => {
                  const newText = sText.toString();
                  if (prevText !== newText) {
                    saveInputText(newText);
                    updateCharacterCounterSr(newText);
                  }
                  // strings wont trigger a re-render if they haven't changed
                  return newText;
                });
              }

              const sEnabled = changes[`stage.${id}.enabled`];
              if (sEnabled !== undefined) {
                setEnabled(sEnabled);
              }

              const sCssClass = changes[`stage.${id}.customCssClass`];
              if (sCssClass !== undefined) {
                setCssClass(sCssClass);
              }
            }
            break;
          case NotificationType.CONTEXT_CHANGED:
            {
              const { snapshot } = payload;
              const sText = snapshot[`stage.${id}.text`];
              if (sText !== undefined) {
                setText((prevText) => {
                  const newText = sText.toString();
                  if (prevText !== newText) {
                    saveInputText(newText);
                    updateCharacterCounterSr(newText);
                  }
                  // strings wont trigger a re-render if they haven't changed
                  return newText;
                });
                saveInputText(sText.toString());
              }

              const sEnabled = snapshot[`stage.${id}.enabled`];
              if (sEnabled !== undefined) {
                setEnabled(sEnabled);
              }

              const sCssClass = snapshot[`stage.${id}.customCssClass`];
              if (sCssClass !== undefined) {
                setCssClass(sCssClass);
              }
              if (payload.mode === contexts.REVIEW) {
                setEnabled(false);
              }
            }
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

  // Set up the styles
  const wrapperStyles: CSSProperties = {
    width,
  };
  const inputStyles: CSSProperties = {
    width,
    height,
    resize: 'none',
    fontSize,
  };

  useEffect(() => {
    //TODO commenting for now. Need to revisit once state structure logic is in place
    //handleStateChange(state);
  }, [state]);

  const saveInputText = (val: string) => {
    /* console.log('[Multiline Text Input] saveInputText', val); */
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

  const debounceWaitTime = 250;

  // Debounced screen reader announcement - only announces after user stops typing
  const debounceCharacterCounterSr = useCallback(
    debounce((val: string) => {
      updateCharacterCounterSr(val);
    }, debounceWaitTime),
    [],
  );

  // Update screen reader character counter when text changes (debounced)
  useEffect(() => {
    if (ready && showCharacterCount) {
      // Use debounced update to prevent announcements while typing
      debounceCharacterCounterSr(text);
    }
  }, [ready, showCharacterCount, text, debounceCharacterCounterSr]);

  const handleOnChange = (event: ChangeEvent<HTMLTextAreaElement>) => {
    const val = event.target.value;
    const length = getCharacterCount(val);
    if (characterCounterRef.current) {
      characterCounterRef.current.innerText = length.toString();
    }
    setText(val);
    // Wait until user has stopped typing to save the new value
    debounceInputText(val);
  };

  const debounceInputText = useCallback(
    debounce((val) => saveInputText(val), debounceWaitTime),
    [],
  );

  useEffect(() => {
    const styleChanges: any = {};
    if (width !== undefined) {
      styleChanges.width = { value: width as number };
    }
    if (height != undefined) {
      styleChanges.height = { value: height as number };
    }

    props.onResize({ id: `${id}`, settings: styleChanges });
  }, [width, height]);

  const initialCharacterCount = getCharacterCount(text);

  return ready ? (
    <div data-janus-type={tagName} className={`long-text-input`} style={wrapperStyles}>
      {/* Label - always rendered for accessibility, visually hidden when showLabel is false */}
      <label id={labelId} htmlFor={id} className={showLabel ? '' : 'sr-only'}>
        {label || ''}
      </label>
      {/* Screen reader-only character counter announcement */}
      {showCharacterCount && (
        <span
          id={characterCounterId}
          ref={characterCounterSrRef}
          className="sr-only"
          role="status"
          aria-live="polite"
        />
      )}
      <textarea
        name="test"
        id={id}
        onChange={handleOnChange}
        style={inputStyles}
        placeholder={prompt}
        value={text}
        disabled={!enabled}
        aria-labelledby={label ? labelId : undefined}
        aria-multiline="true"
      />
      <div
        title="Number of characters"
        className="characterCounter"
        style={{
          padding: '0px',
          color: 'rgba(0,0,0,0.6)',
          display: showCharacterCount ? 'block' : 'none',
          width: '250px',
          fontFamily: 'Arial',
          textAlign: 'right',
        }}
        aria-hidden="true"
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
