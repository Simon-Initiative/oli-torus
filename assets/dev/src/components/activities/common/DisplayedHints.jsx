import React from 'react';
import { HtmlContentModelRenderer } from 'data/content/writers/renderer';
const DisplayedHint = ({ hint, context, index }) => {
    return (<div key={hint.id} aria-label={`hint ${index + 1}`} className="hint mb-2 d-flex">
      <i className="fas fa-lightbulb"></i>
      <div className="flex-fill ml-2">
        <HtmlContentModelRenderer content={hint.content} context={context}/>
      </div>
    </div>);
};
export const Hints = (props) => {
    const noHintsRequested = props.hints.length === 0;
    // Display nothing if the question has no hints, meaning no hints have been requested so far
    // and there are no more available to be requested
    if (noHintsRequested && !props.hasMoreHints) {
        return null;
    }
    return (<div className="hints my-2">
      <div className="hints-adornment"></div>
      <h6>Hints</h6>
      <div className="hints-list">
        {props.hints.map((hint, index) => (<DisplayedHint index={index} key={hint.id} hint={hint} context={props.context}/>))}
      </div>
      {props.hasMoreHints && (<button aria-label="request hint" onClick={props.onClick} disabled={props.isEvaluated || !props.hasMoreHints} className="btn btn-sm btn-primary muted mt-2">
          Request Hint
        </button>)}
    </div>);
};
//# sourceMappingURL=DisplayedHints.jsx.map