import React, {useState } from 'react';
import { WrappedMonaco } from 'components/activities/common/variables/WrappedMonaco';
import { makeRequest, ServerError } from 'data/persistence/common';

interface Props {
  code: string;
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

  const [code, setCode] = useState(props.code);
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

  return (
    <div>
      <WrappedMonaco
        language="mathematica"
        model={code}
        editMode={true}
        onEdit={(code) => setCode(code)}/>
      <div className="mt-2 mb-2 d-flex flex-row-reverse">
        <button className="btn btn-secondary" onClick={onClear}>Clear Output</button>
        <button className="btn btn-primary mr-2" disabled={waiting} onClick={onRun}>{label(waiting)}</button>
      </div>
      <pre>
        <code>
          {output}
        </code>
      </pre>
    </div>
  );
};
