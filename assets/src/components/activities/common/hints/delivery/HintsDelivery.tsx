import React from 'react';
import { Hint } from 'components/activities/types';
import { Card } from 'components/misc/Card';
import { WriterContext } from 'data/content/writers/context';
import { HtmlContentModelRenderer } from 'data/content/writers/renderer';

interface Props {
  requestHintDisabled: boolean;
  hints: Hint[];
  hasMoreHints: boolean;
  context: WriterContext;
  onClick: () => void;
  shouldShow?: boolean;
}

export const HintsDelivery: React.FC<Props> = ({
  requestHintDisabled,
  hints,
  hasMoreHints,
  context,
  onClick,
  shouldShow = true,
}) => {
  if (!shouldShow) {
    return null;
  }
  // Display nothing if the question has no hints, meaning no hints have been requested so far
  // and there are no more available to be requested
  const noHintsRequested = hints.length === 0;
  if (noHintsRequested && !hasMoreHints) {
    return null;
  }
  return (
    <Card.Card className="hints !bg-delivery-hints-bg dark:!bg-delivery-hints-bg-dark !rounded !border-0 !shadow-none">
      <Card.Title>
        <span className="font-bold text-base leading-6 text-delivery-hints-text dark:text-delivery-hints-text-dark">
          Hints
        </span>
      </Card.Title>
      <Card.Content>
        <div className="flex flex-col items-start p-0 gap-2 self-stretch">
          {hints.map((hint, index) => (
            <div
              aria-label={`hint ${index + 1}`}
              key={hint.id}
              className="flex items-baseline text-base font-normal leading-6 text-delivery-hints-text dark:text-delivery-hints-text-dark"
            >
              <span className="mr-2 flex-shrink-0">{index + 1}.</span>
              <div className="flex-1">
                <HtmlContentModelRenderer
                  content={hint.content}
                  context={context}
                  direction={hint.textDirection}
                />
              </div>
            </div>
          ))}
          {hasMoreHints && (
            <button
              aria-label="request hint"
              onClick={onClick}
              disabled={requestHintDisabled}
              className="flex flex-row items-center p-0 gap-2 w-[90px] h-6"
            >
              <div className="flex flex-row items-center py-1 px-0 w-[90px] h-6">
                <span className="w-[90px] h-4 flex items-center justify-center font-bold text-sm leading-4 text-delivery-hints-button dark:text-delivery-hints-button-dark">
                  Request hint
                </span>
              </div>
            </button>
          )}
        </div>
      </Card.Content>
    </Card.Card>
  );
};
