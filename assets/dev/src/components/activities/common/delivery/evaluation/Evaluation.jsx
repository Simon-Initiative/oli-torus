import { makeContent, makeFeedback } from 'components/activities/types';
import { HtmlContentModelRenderer } from 'data/content/writers/renderer';
import React from 'react';
import guid from 'utils/guid';
export const Evaluation = ({ shouldShow = true, attemptState, context }) => {
    var _a;
    const { score, outOf, parts } = attemptState;
    if (!shouldShow || outOf === null || score === null) {
        return null;
    }
    const errorText = makeContent('There was an error processing this response');
    const totalScoreText = [
        {
            type: 'p',
            children: [{ text: 'Total Score', strong: true }],
            id: guid(),
        },
    ];
    if (parts.length === 1) {
        const error = parts[0].error;
        const feedback = (_a = parts[0].feedback) === null || _a === void 0 ? void 0 : _a.content;
        return (<Component resultClass={resultClass(score, outOf, parts[0].error)} score={score} outOf={outOf}>
        <HtmlContentModelRenderer content={error ? errorText.content : feedback ? feedback : makeFeedback('').content} context={context}/>
      </Component>);
    }
    return (<>
      <Component resultClass={resultClass(score, outOf, undefined)} score={score} outOf={outOf}>
        <HtmlContentModelRenderer content={totalScoreText} context={context}/>
      </Component>
      {parts.map((partState) => {
            var _a;
            if (!partState.score && !partState.outOf) {
                return null;
            }
            const error = partState.error;
            const feedback = (_a = partState.feedback) === null || _a === void 0 ? void 0 : _a.content;
            return (<Component key={partState.partId} resultClass={resultClass(partState.score, partState.outOf, partState.error)} score={partState.score} outOf={partState.outOf}>
            <HtmlContentModelRenderer content={error ? errorText.content : feedback ? feedback : makeFeedback('').content} context={context}/>
          </Component>);
        })}
    </>);
};
const Component = (props) => {
    return (<div aria-label="result" className={`evaluation feedback ${props.resultClass} my-1`}>
      <div className="result">
        <span aria-label="score" className="score">
          {props.score}
        </span>
        <span className="result-divider">/</span>
        <span aria-label="out of" className="out-of">
          {props.outOf}
        </span>
      </div>
      {props.children}
    </div>);
};
const resultClass = (score, outOf, error) => {
    if (typeof error === 'string' || outOf === null || score === null) {
        return 'error';
    }
    if (score === outOf) {
        return 'correct';
    }
    if (score === 0) {
        return 'incorrect';
    }
    if (score > 0) {
        return 'partially-correct';
    }
    return '';
};
//# sourceMappingURL=Evaluation.jsx.map