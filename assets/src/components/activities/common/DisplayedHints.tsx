import React from 'react';
import * as ActivityTypes from '../types';
import { HtmlContentModelRenderer } from 'data/content/writers/renderer';

interface DisplayedHintProps {
  hint: ActivityTypes.Hint;
}

const DisplayedHint = ({ hint }: DisplayedHintProps) => {
  return (
    <div key={hint.id}
      style={{
        display: 'inline-flex',
        alignItems: 'top',
        borderWidth: '2px 2px 4px',
        padding: '12px 16px',
        borderRadius: '16px',
        borderStyle: 'solid',
        borderColor: '#e5e5e5',
        backgroundColor: 'transparent',
      }}>
      <HtmlContentModelRenderer text={hint.content} />
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
  return (
    <div className="question-hints" style={{
      padding: '16px',
      border: '1px solid rgba(34,36,38,.15)',
      borderRadius: '5px',
      boxShadow: '0 1px 2px 0 rgba(34,36,38,.15)',
      position: 'relative',
    }}>
      <div style={{
        position: 'absolute',
        left: '0',
        bottom: '-3px',
        borderTop: '1px solid rgba(34,36,38,.15)',
        height: '6px',
        width: '100%',
      }}></div>
        <h6><b>Hints</b></h6>
        <div style={{
          display: 'grid',
          flex: '1',
          alignItems: 'center',
          gridTemplateRows: 'min-content 1fr',
          gridGap: '8px',
        }}>
          {props.hints.map(hint => <DisplayedHint hint={hint}/>)}
        </div>
        <button
          onClick={props.onClick}
          disabled={props.isEvaluated || !props.hasMoreHints}
          className="btn btn-primary muted">Request Hint</button>
    </div>
  );
};
