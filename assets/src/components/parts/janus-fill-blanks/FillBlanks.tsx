/* eslint-disable react/prop-types */
import React, { CSSProperties, useCallback, useEffect, useRef, useState } from 'react';
import Select2 from 'react-select2-wrapper';
import { usePrevious } from '../../hooks/usePrevious';
// eslint-disable-next-line @typescript-eslint/no-var-requires
const css = require('./FillBlanks.css');
// eslint-disable-next-line @typescript-eslint/no-var-requires
const quill = require('./Quill.css');
// eslint-disable-next-line @typescript-eslint/no-var-requires
const select2Styles = require('react-select2-wrapper/css/select2.css');
import { JanusFillBlanksProperties } from './FillBlanksType';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import {
  NotificationType,
  subscribeToNotification,
} from '../../../apps/delivery/components/NotificationContext';
import { contexts } from '../../../utils/common';
export const parseBool = (val: any) => {
  // cast value to number
  const num: number = +val;
  return !isNaN(num) ? !!num : !!String(val).toLowerCase().replace('false', '');
};
interface SelectOption {
  key: string;
  value: string;
}

const FillBlanks: React.FC<JanusFillBlanksProperties> = (props) => {
  const id: string = props.id;
  const [state, setState] = useState<any[]>(Array.isArray(props.state) ? props.state : []);
  const [model, setModel] = useState<any>(Array.isArray(props.model) ? props.model : []);
  const [localSnapshot, setLocalSnapshot] = useState<any>({});
  const [stateChanged, setStateChanged] = useState<boolean>(false);
  const [mutateState, setMutateState] = useState<any>({});
  const {
    x = 0,
    y = 0,
    z = 0,
    width,
    height,
    content,
    elements,
    alternateCorrectDelimiter,
  } = model;
  const fibContainer = useRef(null);

  const [attempted, setAttempted] = useState<boolean>(false);
  const [contentList, setContentList] = useState<any[]>([]);
  const [elementValues, setElementValues] = useState<any[]>([]);
  const [newElement, setNewElement] = useState<SelectOption>();

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
  const prevElementValues = usePrevious<any[]>(elementValues);

  const [enabled, setEnabled] = useState<boolean>(model?.enabled ? parseBool(model.enabled) : true);
  const [correct, setCorrect] = useState<boolean>(
    model?.correct ? parseBool(model.correct) : false,
  );
  const [showCorrect, setShowCorrect] = useState<boolean>(
    model?.showCorrect ? parseBool(model.showCorrect) : false,
  );
  const [customCss, setCustomCss] = useState<string>(model?.customCss ? model.customCss : '');
  const [customCssClass, setCustomCssClass] = useState<string>(
    model?.customCss ? model.customCss : '',
  );
  const [ready, setReady] = useState<boolean>(false);
  const wrapperStyles: CSSProperties = {
    position: 'absolute',
    top: y,
    left: x,
    width,
    height,
    zIndex: z,
    borderRadius: '5px',
    fontFamily: 'revert',
  };
  const initialize = useCallback(async (pModel) => {
    const initResult = await props.onInit({
      id,
      responses: [],
    });

    // result of init has a state snapshot with latest (init state applied)
    const currentStateSnapshot = initResult.snapshot;
    setLocalSnapshot(currentStateSnapshot);
    const sEnabled = currentStateSnapshot[`stage.${id}.enabled`];
    if (sEnabled) {
      setEnabled(parseBool(sEnabled));
    }

    const sShowCorrect = currentStateSnapshot[`stage.${id}.showCorrect`];
    if (sShowCorrect) {
      setShowCorrect(parseBool(sShowCorrect));
    }

    const sCustomCss = currentStateSnapshot[`stage.${id}.customCss`];
    if (sCustomCss) {
      setCustomCss(sCustomCss);
    }

    const sCustomCssClass = currentStateSnapshot[`stage.${id}.customCssClass`];
    if (sEnabled) {
      setCustomCssClass(sCustomCssClass);
    }
    //Instead of hardcoding REVIEW, we can make it an global interface and then importa that here.
    if (initResult.context.mode === contexts.REVIEW) {
      setEnabled(false);
    }

    setReady(true);
  }, []);

  useEffect(() => {
    if (!ready) {
      return;
    }
    props.onReady({ id, responses: [] });
  }, [ready]);

  useEffect(() => {
    //if (elements?.length && state?.length) {
    if (elements?.length) {
      getStateSelections(localSnapshot);
      setContentList(buildContentList);
    }
  }, [elements, localSnapshot]);

  useEffect(() => {
    //if (elements?.length && state?.length) {
    if (elements?.length && stateChanged) {
      getStateSelections(mutateState);
      setContentList(buildContentList);
      setStateChanged(false);
    }
  }, [elements, stateChanged, mutateState]);

  useEffect(() => {
    // write to state when elementValues changes
    if (
      prevElementValues &&
      ((prevElementValues.length < 1 && elementValues.length > 0) ||
        // if previous element values contain values and the values don't match currently selected values
        (prevElementValues.length > 0 &&
          !elementValues.every((val) => prevElementValues.includes(val))))
    ) {
      saveElements();
      setContentList(buildContentList);
    }
  }, [elementValues]);

  useEffect(() => {
    if (parseBool(attempted)) {
      props.onSave({
        activityId: `${id}`,
        partResponses: [
          {
            key: 'attempted',
            type: CapiVariableTypes.BOOLEAN,
            value: attempted,
          },
        ],
      });
    }
  }, [attempted]);

  useEffect(() => {
    // update `elementValues` when `newElement` is updated
    if (newElement) {
      setElementValues([newElement, ...elementValues.filter((obj) => newElement.key !== obj?.key)]);
    }
  }, [newElement]);

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
        /* console.log(`${notificationType.toString()} notification handled [InputNumber]`, payload); */
        switch (notificationType) {
          case NotificationType.CHECK_STARTED:
            // nothing to do
            break;
          case NotificationType.CHECK_COMPLETE:
            // nothing to do
            break;
          case NotificationType.STATE_CHANGED:
            const { mutateChanges: changes } = payload;
            setStateChanged(true);
            setMutateState(changes);
            const sEnabled = changes[`stage.${id}.enabled`];
            if (sEnabled) {
              setEnabled(parseBool(sEnabled));
            }
            const sShowCorrect = changes[`stage.${id}.showCorrect`];
            if (sShowCorrect) {
              setShowCorrect(parseBool(sShowCorrect));
            }
            const sCustomCss = changes[`stage.${id}.customCss`];
            if (sCustomCss) {
              setCustomCss(sCustomCss);
            }
            const sCustomCssClass = changes[`stage.${id}.customCssClass`];
            if (sCustomCssClass) {
              setCustomCssClass(sCustomCssClass);
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

  const handleInput = (e: any) => {
    if (!e || typeof e === 'undefined') return;

    setAttempted(true);
    setNewElement({
      key: e?.name,
      value: e?.value,
    });
  };

  const getElementValueByKey = (key: string) => {
    // get value from `elementValues` based on key
    if (!key || typeof key === 'undefined' || !elementValues?.length) return;
    const val = elementValues?.find((obj) => obj.key === key);
    return typeof val !== 'undefined' && val?.value ? val.value.toString() : '';
  };

  // returns boolean
  const isCorrect = (submission: string, correct: string, alternateCorrect: string) => {
    if (!submission || !correct) return false;

    const correctArray: any[] =
      typeof alternateCorrect !== 'undefined'
        ? [correct, ...alternateCorrect.split(alternateCorrectDelimiter)]
        : [correct];

    return correctArray.includes(submission);
  };

  const saveElements = () => {
    if (!elements?.length) return;

    const allCorrect = elements.every(
      (element: { key: string; correct: string; alternateCorrect: string }) => {
        const elVal = getElementValueByKey(element.key);
        return isCorrect(elVal, element.correct, element.alternateCorrect);
      },
    );
    setCorrect(allCorrect);

    // set up responses array based on current selections/values of elements
    const partResponses: any[] = elements.map((el: any) => {
      const val: string = getElementValueByKey(el.key);
      const index: number = elements.findIndex((o: any) => o.key === el.key);

      return [
        {
          key: `Input ${index + 1}.Value`,
          type: CapiVariableTypes.STRING,
          value: val,
        },
        {
          key: `Input ${index + 1}.Correct`,
          type: CapiVariableTypes.BOOLEAN,
          value: isCorrect(val, el.correct, el.alternateCorrect),
        },
      ];
    });
    // save to state
    try {
      const elementPartResponses = [].concat(...partResponses);

      props.onSave({
        id: `${id}`,
        responses: [
          ...elementPartResponses,
          {
            key: 'enabled',
            type: CapiVariableTypes.BOOLEAN,
            value: enabled,
          },
          {
            key: 'showCorrect',
            type: CapiVariableTypes.BOOLEAN,
            value: showCorrect,
          },
          {
            key: 'customCss',
            type: CapiVariableTypes.STRING,
            value: customCss,
          },
          {
            key: 'customCssClass',
            type: CapiVariableTypes.STRING,
            value: customCssClass,
          },
          {
            key: 'correct',
            type: CapiVariableTypes.BOOLEAN,
            value: allCorrect,
          },
        ],
      });
    } catch (err) {
      console.log(err);
    }
  };

  const getStateSelections = (snapshot: any) => {
    if (!Object.keys(snapshot)?.length || !elements?.length) return;

    // check for state vars that match elements keys and
    const interested = Object.keys(snapshot).filter(
      (stateVar) => stateVar.indexOf(`stage.${id}.`) === 0,
    );
    const stateValues = interested.map((stateVar) => {
      const sKey = stateVar;
      if (sKey?.startsWith(`stage.${id}.Input `) && sKey?.endsWith('.Value')) {
        const segments = sKey.split('.');
        const finalsKey = segments.slice(-2).join('.');
        // extract index from stateVar key
        const index: number = parseInt(finalsKey.replace(/[^0-9\\.]/g, ''), 10);
        // get key from `elements` based on 'Input [index].Value'
        const el: any = elements[index - 1];
        const val: string = snapshot[stateVar]?.toString();
        if (el?.key) return { key: el.key, value: val };
      } else {
        return false;
      }
    });
    // set new elementValues array
    setElementValues([
      ...stateValues,
      ...elementValues.filter((obj) => !stateValues.includes(obj?.key)),
    ]);
  };

  const buildContentList = content?.map(
    (contentItem: { [x: string]: any; insert: any; dropdown: any }) => {
      if (!elements?.length) return;

      const insertList: any[] = [];
      let insertEl: any;

      if (contentItem.insert) {
        // contentItem.insert is always a string
        insertList.push(<span dangerouslySetInnerHTML={{ __html: contentItem.insert }} />);
      } else if (contentItem.dropdown) {
        // get correlating dropdown from `elements`
        insertEl = elements.find((elItem: { key: any }) => elItem.key === contentItem.dropdown);
        if (insertEl) {
          // build list of options for react-select
          const elVal: string = getElementValueByKey(insertEl.key);
          const optionsList = insertEl.options.map(
            ({ value: text, key: id }: { value: any; key: any }) => ({ id, text }),
          );
          const answerStatus: string =
            showCorrect && isCorrect(elVal, insertEl.correct, insertEl.alternateCorrect)
              ? 'correct'
              : 'incorrect';

          insertList.push(
            <span className="dropdown-blot" tabIndex={-1}>
              <span className="dropdown-container" tabIndex={-1}>
                <Select2
                  className={`dropdown ${showCorrect ? answerStatus : ''}`}
                  name={insertEl.key}
                  data={optionsList}
                  value={elVal}
                  aria-label="Make a selection"
                  options={{
                    dropdownParent: fibContainer.current,
                    minimumResultsForSearch: 10,
                    selectOnClose: false,
                  }}
                  onChange={(e: any) => handleInput(e.currentTarget)}
                  disabled={!enabled}
                />
              </span>
            </span>,
          );
        }
      } else if (contentItem['text-input']) {
        // get correlating inputText from `elements`
        insertEl = elements.find((elItem: { key: any }) => {
          return elItem.key === contentItem['text-input'];
        });
        if (insertEl) {
          const elVal: string = getElementValueByKey(insertEl.key);
          const answerStatus: string =
            showCorrect && isCorrect(elVal, insertEl.correct, insertEl.alternateCorrect)
              ? 'correct'
              : 'incorrect';

          insertList.push(
            <span className="text-input-blot">
              <span
                className={`text-input-container ${showCorrect ? answerStatus : ''}`}
                tabIndex={-1}
              >
                <input
                  name={insertEl.key}
                  className={`text-input ${!enabled ? 'disabled' : ''} ${
                    showCorrect && isCorrect(elVal, insertEl.correct, insertEl.alternateCorrect)
                      ? 'correct'
                      : ''
                  }`}
                  type="text"
                  value={elVal}
                  onChange={(e) => handleInput(e.currentTarget)}
                  disabled={!enabled}
                />
              </span>
            </span>,
          );
        }
      }
      return insertList;
    },
  );
  return (
    <div
      data-janus-type={props.type}
      style={wrapperStyles}
      className={`fib-container ${customCssClass}`}
      ref={fibContainer}
    >
      <style type="text/css">@import url(/css/janus_fill_blanks_delivery.css);</style>
      <style type="text/css">{`${customCss}`};</style>
      <div className="scene">
        <div className="app">
          <div className="editor ql-container ql-snow ql-disabled">
            <div
              className="ql-editor"
              data-gramm="false"
              contentEditable="false"
              suppressContentEditableWarning={true}
            >
              <p>{contentList}</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export const tagName = 'janus-fill-blanks';
export const watchedProps = ['model', 'id', 'state', 'type'];

export default FillBlanks;
