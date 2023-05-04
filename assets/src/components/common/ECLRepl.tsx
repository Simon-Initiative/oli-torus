import React, {useState, useEffect, useCallback} from 'react';
import { WrappedMonaco } from 'components/activities/common/variables/WrappedMonaco';
import { makeRequest, ServerError } from 'data/persistence/common';
import * as Extrinsic from 'data/persistence/extrinsic';
import debounce from 'lodash/debounce';

interface Props {
  id: string;
  code: string;
  slug: string;
  attemptGuid: string;
  children?: React.ReactNode;
}

export type EvalResult = Evaluation | ServerError;

export type Evaluation = {
  result: any;
};

export function evaluate(code: string): Promise<EvalResult> {
  const params = {
    url: '/content_types/ecl',
    method: 'POST',
    body: JSON.stringify({ code })
  };
  return makeRequest<EvalResult>(params);
}

function label(waiting: boolean) {
  return waiting
  ? <span><span className="spinner-border spinner-border-sm"></span> Running...</span>
  : <span>Run</span>;
}

export const ECLRepl: React.FC<Props> = (props) => {

  const [code, setCode] = useState('');
  const [key, setKey] = useState('code_' + props.id);

  useEffect(() => {
    if (props.attemptGuid !== '') {
      Extrinsic.readAttempt(props.slug, props.attemptGuid, [props.id])
      .then(result => {
        if (result && (result as any)[props.id]) {
          setCode((result as any)[props.id]);
        } else {
          setCode(props.code);
        }
      });
    }
  }, []);

  const [output, setOutput] = useState('');
  const [waiting, setWaiting] = useState(false);

  const onRun = () => {
    // Eval and update output
    setWaiting(true);

    evaluate(code)
    .then(result => {
      setWaiting(false);
      if (typeof result.result === 'string') {
        setOutput(result.result);
      } else if (typeof result.result === 'object') {
        setOutput(JSON.stringify(result.result, undefined, 2));
      }
    })
  };

  const onClear = () => setOutput('');

  const onReset = () => {
    // The Monaco editor doesn't like it when we change the model, but we can
    // trick it into updating from a pushed down props by changing the key.
    setKey('code_' + props.id + '_' + Date.now());
    setCode(props.code);
    Extrinsic.upsertAttempt(props.slug, props.attemptGuid, {[props.id]: props.code});
    setOutput('');

  };

  const waitTime = 800;
  const persistChanges = useCallback(
    debounce((val) => Extrinsic.upsertAttempt(props.slug, props.attemptGuid, {[props.id]: val}), waitTime), []);

  const maybeShowEditor = code !== ''
    ? <WrappedMonaco
        key={key}
        language="mathematica"
        model={code}
        editMode={true}
        onEdit={(code) => {
          const paddedCode = code.trim() === '' ? '\n' : code;
          setCode(paddedCode);
          persistChanges(paddedCode)
        }}/>
    : null;

  return (
    <div>
      {maybeShowEditor}
      <div className="mt-2 mb-2 d-flex flex-row-reverse">
        <button className="btn btn-sm btn-secondary" onClick={onReset}>Reset</button>
        <button className="btn btn-sm btn-secondary mr-1" onClick={onClear}>Clear Output</button>
        <button className="btn btn-sm btn-primary mr-1" disabled={waiting} onClick={onRun}>{label(waiting)}</button>
      </div>
      <pre>
        <code>
          {output}
        </code>
      </pre>
    </div>
  );
};
