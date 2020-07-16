import React from 'react';
import * as ActivityTypes from '../types';
import { HtmlContentModelRenderer } from 'data/content/writers/renderer';

interface DisplayedHintProps {
  hint: ActivityTypes.Hint;
}

const DisplayedHint = ({ hint }: DisplayedHintProps) => {
  console.log('hint in displayed hint', hint)
  return (
    <div key={hint.id}
      className="hint mb-2 d-flex">
      <i className="fas fa-lightbulb"></i>
      <div className="flex-fill ml-2">
        <HtmlContentModelRenderer text={hint.content} />
      </div>
    </div>
  );
};

interface HintsProps {
  isEvaluated: boolean;
  hints: ActivityTypes.Hint[];
  hasMoreHints: boolean;
  onClick: () => void;
}

export const Hints = (props: HintsProps) => {
  console.log("has more hints", props.hasMoreHints)
  console.log("hints", props.hints)
  return (
    <div className="hints my-2">
      <div className="hints-adornment"></div>
      <h6>Hints</h6>
      <div className="hints-list">
        {props.hints.map(hint => <DisplayedHint key={hint.id} hint={hint}/>)}
      </div>
      <button
        onClick={props.onClick}
        disabled={props.isEvaluated || !props.hasMoreHints}
        className="btn btn-sm btn-primary muted mt-2">Request Hint</button>
    </div>
  );
};
