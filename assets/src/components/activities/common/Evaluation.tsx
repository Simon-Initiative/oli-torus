import React from 'react';
import * as ActivityTypes from '../types';
import { HtmlContentModelRenderer } from 'data/content/writers/renderer';
import { fromText } from './utils';
import { WriterContext } from 'data/content/writers/context';

export const Evaluation = ({ attemptState, context }:
  { attemptState: ActivityTypes.ActivityState, context: WriterContext }) => {

  const { score, outOf, parts } = attemptState;
  const error = parts[0].error;
  const feedback = parts[0].feedback.content;

  const errorText = fromText('There was an error processing this response');

  let resultClass = 'incorrect';
  if (error !== undefined && error !== null) {
    resultClass = 'error';
  } else if (score === outOf) {
    resultClass = 'correct';
  } else if ((score as number) > 0) {
    resultClass = 'incorrect';
  }

  return (
    <div aria-label="result" className={`evaluation feedback ${resultClass} my-1`}>
      <div className="result">
        <span aria-label="score" className="score">{score}</span>
        <span className="result-divider">/</span>
        <span aria-label="out of" className="out-of">{outOf}</span>
      </div>
      <HtmlContentModelRenderer text={error ? errorText : feedback} context={context} />
    </div>
  );

};
