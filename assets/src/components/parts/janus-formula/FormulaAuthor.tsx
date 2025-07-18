import React, { useCallback, useEffect, useState } from 'react';
import ReactDOM from 'react-dom';
import {
  NotificationType,
  subscribeToNotification,
} from 'apps/delivery/components/NotificationContext';
import { clone, parseBoolean } from 'utils/common';
import { Formula } from '../../common/Formula';
import { AuthorPartComponentProps } from '../types/parts';
import { formulaTagName, registerFormulaEditor } from './FormulaEditor';
import { FormulaModel } from './schema';

// eslint-disable-next-line react/display-name
const Editor: React.FC<any> = React.memo(({ formula, alttext, portal, type }) => {
  const MathEditorModalProps: { formula?: any; alttext?: any } = {};
  MathEditorModalProps.alttext = alttext;
  MathEditorModalProps.formula = formula;
  return (
    portal &&
    ReactDOM.createPortal(
      <div style={{ padding: 0 }}>{React.createElement(formulaTagName, MathEditorModalProps)}</div>,
      portal,
    )
  );
});

const FormulaAuthor: React.FC<AuthorPartComponentProps<FormulaModel>> = (props) => {
  const {
    configuremode,
    id,
    model: incomingModel,
    onConfigure,
    onCancelConfigure,
    onSaveConfigure,
    onReady,
  } = props;

  const [model, setModel] = useState<FormulaModel>(incomingModel);
  const [inConfigureMode, setInConfigureMode] = useState(parseBoolean(configuremode));
  const [ready, setReady] = useState(false);
  const [mathData, setMathData] = useState({
    input: incomingModel.formula,
    altText: incomingModel.formulaAltText,
  });
  const [formulaData, setFormulaData] = useState({
    input: incomingModel.formula,
    altText: incomingModel.formulaAltText,
  });

  useEffect(() => setModel(incomingModel), [incomingModel]);
  useEffect(() => setInConfigureMode(parseBoolean(configuremode)), [configuremode]);
  const [portalEl, setPortalEl] = useState<HTMLElement | null>(null);
  const initialize = useCallback(() => setReady(true), []);
  useEffect(() => {
    initialize();
  }, [initialize]);

  useEffect(() => {
    // timeout to give modal a moment to load
    setTimeout(() => {
      const el = document.getElementById(props.portal);
      if (el) {
        setPortalEl(el);
      }
    }, 10);
  }, [inConfigureMode, props.portal]);

  useEffect(() => {
    registerFormulaEditor();
  }, []);

  useEffect(() => {
    if (ready) {
      onReady({ id, responses: [] });
    }
  }, [ready, id, onReady]);

  const handleNotificationSave = useCallback(async () => {
    const modelClone = clone(model);
    modelClone.formula = formulaData.input;
    modelClone.formulaAltText = formulaData.altText;
    setMathData({ altText: formulaData.altText, input: formulaData.input });
    setModel(modelClone);
    onSaveConfigure({ id, snapshot: modelClone });
    setInConfigureMode(false);
  }, [model, formulaData]);

  useEffect(() => {
    if (!props.notify) {
      return;
    }
    const notificationsHandled = [
      NotificationType.CONFIGURE,
      NotificationType.CONFIGURE_SAVE,
      NotificationType.CONFIGURE_CANCEL,
    ];
    const notifications = notificationsHandled.map((notificationType: NotificationType) => {
      const handler = (payload: any) => {
        if (!payload) {
          // if we don't have anything, we won't even have an id to know who it's for
          // for these events we need something, it's not for *all* of them
          return;
        }
        switch (notificationType) {
          case NotificationType.CONFIGURE:
            {
              const { partId } = payload;
              if (partId === id) {
                setInConfigureMode(false);
                onConfigure({
                  id,
                  configure: true,
                  context: { fullscreen: false, customClassName: 'modal-800' },
                });
              }
            }
            break;
          case NotificationType.CONFIGURE_SAVE:
            {
              const { id: partId } = payload;
              if (partId === id) {
                handleNotificationSave();
              }
            }
            break;
          case NotificationType.CONFIGURE_CANCEL:
            {
              const { id: partId } = payload;
              if (partId === id) {
                setInConfigureMode(false);
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
  }, [props.notify, handleNotificationSave]);

  useEffect(() => {
    const handleEditorSave = (e: any) => {};

    const handleEditorCancel = () => {
      if (!inConfigureMode) {
        return;
      } // not mine
      setInConfigureMode(false);
      onCancelConfigure({ id });
    };

    const handleEditorChange = (e: any) => {
      if (!inConfigureMode) {
        return;
      } // not mine
      const { payload } = e.detail;
      setFormulaData({
        input: payload.input,
        altText: payload.altText,
      });
    };

    if (inConfigureMode) {
      document.addEventListener(`${formulaTagName}-change`, handleEditorChange);
      document.addEventListener(`${formulaTagName}-save`, handleEditorSave);
      document.addEventListener(`${formulaTagName}-cancel`, handleEditorCancel);
    }

    return () => {
      document.removeEventListener(`${formulaTagName}-change`, handleEditorChange);
      document.removeEventListener(`${formulaTagName}-save`, handleEditorSave);
      document.removeEventListener(`${formulaTagName}-cancel`, handleEditorCancel);
    };
  }, [ready, inConfigureMode, model]);

  if (!model.visible || !ready) return null;
  const isMathML = mathData?.input?.trim().startsWith('<math');
  return (
    <div>
      {inConfigureMode && portalEl ? (
        <Editor formula={mathData.input} alttext={mathData.altText} portal={portalEl} />
      ) : (
        <>
          <Formula
            id={id}
            src={mathData.input}
            formulaAltText={mathData.altText}
            subtype={isMathML ? 'mathml' : 'latex'}
          />
        </>
      )}
    </div>
  );
};

export const tagName = 'janus-formula';
export default React.memo(FormulaAuthor);
