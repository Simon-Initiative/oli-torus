import React from 'react';
import * as ActivityTypes from '../types';
import { HtmlContentModelRenderer } from 'data/content/writers/renderer';
import { fromText } from './utils';

export const Evaluation = ({ attemptState } : { attemptState : ActivityTypes.ActivityState}) => {

  const { score, outOf, parts } = attemptState;
  const error = parts[0].error;
  const feedback = parts[0].feedback.content;

  const errorText = fromText('There was an error processing this response');

  let resultClass = 'incorrect';
  if (error !== undefined) {
    resultClass = 'error';
  } else if (score === outOf) {
    resultClass = 'correct';
  } else if ((score as number) > 0) {
    resultClass = 'incorrect';
  }

  return (
    <div key="evaluation"
      className={`evaluation feedback ${resultClass} my-1`}>
        <div className="result">
          <span className="score">{score}</span>
          <span className="out-of">{` / ${outOf}`}</span>
        </div>
      <HtmlContentModelRenderer text={error ? errorText : feedback} />
    </div>
  );

};
