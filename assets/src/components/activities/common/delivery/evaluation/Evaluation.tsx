import { ActivityState, makeContent, makeFeedback, RichText } from 'components/activities/types';
import { WriterContext } from 'data/content/writers/context';
import { HtmlContentModelRenderer } from 'data/content/writers/renderer';
import React from 'react';
import guid from 'utils/guid';

interface Props {
  shouldShow?: boolean;
  attemptState: ActivityState;
  context: WriterContext;
}
export const Evaluation: React.FC<Props> = ({ shouldShow = true, attemptState, context }) => {
  const { score, outOf, parts } = attemptState;
  if (!shouldShow || outOf === null || score === null) {
    return null;
  }

  const errorText = makeContent('There was an error processing this response');
  const totalScoreText: RichText = {
    model: [
      {
        type: 'p',
        children: [{ text: 'Total Score', strong: true }],
        id: guid(),
      },
    ],
    selection: null,
  };

  if (parts.length === 1) {
    const error = parts[0].error;
    const feedback = parts[0].feedback?.content;
    return (
      <Component
        resultClass={resultClass(score, outOf, parts[0].error)}
        score={score}
        outOf={outOf}
      >
        <HtmlContentModelRenderer
          text={error ? errorText.content : feedback ? feedback : makeFeedback('').content}
          context={context}
        />
      </Component>
    );
  }

  return (
    <>
      <Component resultClass={resultClass(score, outOf, undefined)} score={score} outOf={outOf}>
        <HtmlContentModelRenderer text={totalScoreText} context={context} />
      </Component>
      {parts.map((partState) => {
        if (!partState.score && !partState.outOf) {
          return null;
        }
        const error = partState.error;
        const feedback = partState.feedback?.content;
        return (
          <Component
            key={partState.partId}
            resultClass={resultClass(partState.score, partState.outOf, partState.error)}
            score={partState.score}
            outOf={partState.outOf}
          >
            <HtmlContentModelRenderer
              text={error ? errorText.content : feedback ? feedback : makeFeedback('').content}
              context={context}
            />
          </Component>
        );
      })}
    </>
  );
};

interface ComponentProps {
  resultClass: string;
  score: number | null;
  outOf: number | null;
}
const Component: React.FC<ComponentProps> = (props) => {
  return (
    <div aria-label="result" className={`evaluation feedback ${props.resultClass} my-1`}>
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
    </div>
  );
};

const resultClass = (score: number | null, outOf: number | null, error: string | undefined) => {
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
