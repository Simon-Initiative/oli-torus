import React from 'react';
import * as ActivityTypes from '../types';
import { HtmlContentModelRenderer } from 'data/content/writers/renderer';

interface DisplayedHintProps {
  hint: ActivityTypes.Hint;
}

const DisplayedHint = ({ hint }: DisplayedHintProps) => {
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
  const noHintsRequested = props.hints.length === 0;

  // Display nothing if the question has no hints, meaning no hints have been requested so far
  // and there are no more available to be requested
  if (noHintsRequested && !props.hasMoreHints) {
    return null;
  }

  return (
    <div className="hints my-2">
      <div className="hints-adornment"></div>
      <h6>Hints</h6>
      <div className="hints-list">
        {props.hints.map(hint => <DisplayedHint key={hint.id} hint={hint}/>)}
      </div>
      {props.hasMoreHints && <button
        onClick={props.onClick}
        disabled={props.isEvaluated || !props.hasMoreHints}
        className="btn btn-sm btn-primary muted mt-2">Request Hint</button>}
    </div>
  );
};
