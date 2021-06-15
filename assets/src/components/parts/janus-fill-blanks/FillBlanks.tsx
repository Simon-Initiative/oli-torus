/* eslint-disable react/prop-types */
import React, { CSSProperties, useEffect, useRef, useState } from 'react';
import Select2 from 'react-select2-wrapper';
import { usePrevious } from '../../hooks/usePrevious';
// eslint-disable-next-line @typescript-eslint/no-var-requires
const css = require('./FillBlanks.css');
// eslint-disable-next-line @typescript-eslint/no-var-requires
const quill = require('./Quill.css');
// eslint-disable-next-line @typescript-eslint/no-var-requires
const select2Styles = require('react-select2-wrapper/css/select2.css');
import { JanusFillBlanksProperties } from './FillBlanksType';

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
    if (typeof props?.model === 'string') {
      setModel(JSON.parse(props.model));
    }
    if (typeof props?.state === 'string') {
      setState(JSON.parse(props.state));
    }
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

  useEffect(() => {
    //if (elements?.length && state?.length) {
    if (elements?.length) {
      getStateSelections();
      setContentList(buildContentList);
    }
  }, [elements, state]);

  useEffect(() => {
    props.onReady({ activityId: `${id}`, partResponses: [] });
  }, []);

  useEffect(() => {
    //TODO implement once state support is added
  }, [state]);

  useEffect(() => {
    // explicitly update properties from state
    if (model.enabled) {
      setEnabled(parseBool(model.enabled));
    }
    if (model.showCorrect) {
      setShowCorrect(parseBool(model.showCorrect));
    }
    if (model.customCss) {
      setCustomCss(model.customCss);
    }
    if (model.customCssClass) {
      setCustomCssClass(model.customCssClass);
    }
  }, [model]);

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
    /*  if (parseBool(attempted)) {
            props.onSavePart({
                activityId: `${id}`,
                partResponses: [
                    {
                        id: `stage.${id}.attempted`,
                        key: 'attempted',
                        type: CapiVariableTypes.BOOLEAN,
                        value: attempted,
                    },
                ],
            });
        } */
  }, [attempted]);

  useEffect(() => {
    // update `elementValues` when `newElement` is updated
    if (newElement) {
      setElementValues([newElement, ...elementValues.filter((obj) => newElement.key !== obj?.key)]);
    }
  }, [newElement]);

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
          id: `stage.${id}.Input ${index + 1}.Value`,
          key: `Input ${index + 1}.Value`,
          type: 2,
          value: val,
        },
        {
          id: `stage.${id}.Input ${index + 1}.Correct`,
          key: `Input ${index + 1}.Correct`,
          type: 4,
          value: isCorrect(val, el.correct, el.alternateCorrect),
        },
      ];
    });

    // save to state
    /*  try {
      const elementPartResponses = [].concat(...partResponses);

       props.onSavePArt({
                activityId: `${id}`,
                partResponses: [
                    ...elementPartResponses,
                    {
                        id: `stage.${id}.enabled`,
                        key: 'enabled',
                        type: CapiVariableTypes.BOOLEAN,
                        value: enabled,
                    },
                    {
                        id: `stage.${id}.showCorrect`,
                        key: 'showCorrect',
                        type: CapiVariableTypes.BOOLEAN,
                        value: showCorrect,
                    },
                    {
                        id: `stage.${id}.customCss`,
                        key: 'customCss',
                        type: CapiVariableTypes.STRING,
                        value: customCss,
                    },
                    {
                        id: `stage.${id}.customCssClass`,
                        key: 'customCssClass',
                        type: CapiVariableTypes.STRING,
                        value: customCssClass,
                    },
                    {
                        id: `stage.${id}.correct`,
                        key: 'correct',
                        type: CapiVariableTypes.BOOLEAN,
                        value: allCorrect,
                    },
                ],
            });
    } catch (err) {
      console.log(err);
    } */
  };

  const getStateSelections = () => {
    if (!state?.length || !elements?.length || !Array.isArray(state)) return;

    // check for state vars that match elements keys and
    const interested = state.filter((stateVar) => stateVar.id.indexOf(`stage.${id}.`) === 0);
    const stateValues = interested.map((stateVar) => {
      const sKey = stateVar?.key;
      if (sKey?.startsWith('Input ') && sKey?.endsWith('.Value')) {
        // extract index from stateVar key
        const index: number = parseInt(sKey.replace(/[^0-9\\.]/g, ''), 10);
        // get key from `elements` based on 'Input [index].Value'
        const el: any = elements[index - 1];
        const val: string = stateVar?.value?.toString();
        if (el?.key) return { key: el.key, value: val };
      } else {
        return false;
      }
    });
    // set new elementValues array
    setElementValues([...stateValues]);
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
      <style type="text/css">
        {quill};{select2Styles};{css};
      </style>
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
