import React from 'react';
import * as ActivityTypes from '../types';
import { HtmlContentModelRenderer } from 'data/content/writers/renderer';
import { fromText } from './utils';

export const Evaluation = ({ attemptState } : { attemptState : ActivityTypes.ActivityState}) => {

  const { score, outOf, parts } = attemptState;
  const error = parts[0].error;
  const feedback = parts[0].feedback.content;

  const errorText = fromText('There was an error processing this response');

  let backgroundColor = '#f0b4b4';
  if (error !== undefined) {
    backgroundColor = 'orange';
  } else if (score === outOf) {
    backgroundColor = '#a7e695';
  } else if ((score as number) > 0) {
    backgroundColor = '#f0e8b4';
  }

  return (
    <div key="evaluation"
      style={{
        display: 'inline-flex',
        alignItems: 'top',
        borderWidth: '2px 2px 4px',
        padding: '12px 16px',
        borderRadius: '2px',
        borderStyle: 'none',
        backgroundColor,
      }}>
        <span style={{
          display: 'inline-flex',
          alignItems: 'center',
          justifyContent: 'center',
          border: '2px solid #e5e5e5',
          borderRadius: '8px',
          color: '#afafaf',
          height: '30px',
          width: '60px',
          fontWeight: 'bold',
          marginRight: '16px',
        }}>{score + ' / ' + outOf}</span>
      <HtmlContentModelRenderer text={error ? errorText : feedback} />
    </div>
  );

};
