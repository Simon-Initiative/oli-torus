import React from 'react';
import { useSelector } from 'react-redux';
import { DeliveryMode } from 'components/activities/types';
import { Modal, ModalSize } from 'components/modal/Modal';
import { modalActions } from 'actions/modal';
import { ActivityDeliveryState, isEvaluated } from 'data/activities/DeliveryState';
import { ScoreAsYouGoIcon } from './utils';

interface Props {
  onSubmit: () => void;
  onReset: () => unknown;
  mode: DeliveryMode;
}

interface ModalProps {
  onDone: () => unknown;
  onCancel: () => void;
  message: React.ReactNode;
}
export const ResetModal = ({ onDone, onCancel, message }: ModalProps) => {
  const [busy, setBusy] = React.useState(false);

  const handleOk = () => {
    if (busy) return;
    setBusy(true);
    Promise.resolve(onDone()).finally(() => setBusy(false));
  };

  return (
    <Modal
      title="Reset this question?"
      size={ModalSize.MEDIUM}
      contentClassName="!bg-Background-bg-primary !text-Text-text-high"
      headerClassName="!border-0 !px-6 sm:!px-8 !pt-6 sm:!pt-8 !pb-4"
      titleClassName="font-open-sans !text-[18px] !font-semibold !leading-[24px] text-Text-text-high"
      bodyClassName="!px-6 sm:!px-8 !py-0"
      footerClassName="!border-0 !px-6 sm:!px-8 !pt-6 !pb-6 sm:!pb-8 !gap-4"
      okLabel={busy ? 'Resetting…' : 'Reset'}
      okClassName="m-0 inline-flex min-w-[64px] items-center justify-center rounded-md bg-Fill-Buttons-fill-primary px-4 py-2 font-open-sans text-[14px] font-semibold leading-[16px] text-white hover:bg-Fill-Buttons-fill-primary-hover disabled:cursor-not-allowed disabled:opacity-60"
      cancelLabel="Cancel"
      cancelClassName="m-0 inline-flex min-w-[64px] items-center justify-center rounded-md border border-Border-border-bold bg-Background-bg-primary px-4 py-2 font-open-sans text-[14px] font-semibold leading-[16px] text-Specially-Tokens-Text-text-button-secondary hover:no-underline"
      onCancel={() => onCancel()}
      onOk={handleOk}
      disableOk={busy}
    >
      {message}
    </Modal>
  );
};

interface Score {
  score: number;
  outOf: number;
}

const numberFormat = (value: number | null | undefined) => {
  if (value === null || value === undefined) {
    return '';
  }

  return Number.isInteger(value) ? value.toString() : value.toFixed(2);
};

const percentage = ({ score, outOf }: Score) => (outOf === 0 ? 0 : score / outOf);

export function getDisplayedScore(uiState: ActivityDeliveryState): Score {
  const { activityContext, attemptState } = uiState;
  const current = {
    score: attemptState.score || 0,
    outOf: attemptState.outOf || 0,
  };
  const aggregate =
    activityContext.aggregateScore === null ||
    activityContext.aggregateScore === undefined ||
    activityContext.aggregateOutOf === null ||
    activityContext.aggregateOutOf === undefined
      ? null
      : {
          score: activityContext.aggregateScore,
          outOf: activityContext.aggregateOutOf,
        };

  if (activityContext.aggregateIncludesCurrentAttempt && aggregate) {
    return aggregate;
  }

  if (!aggregate || attemptState.attemptNumber <= 1) {
    return current;
  }

  switch (activityContext.scoringStrategyId) {
    case 2:
      return percentage(current) >= percentage(aggregate) ? current : aggregate;
    case 3:
      return current;
    default: {
      const previousAttempts = attemptState.attemptNumber - 1;
      const outOf = Math.max(aggregate.outOf, current.outOf);
      const averagePercentage =
        (percentage(aggregate) * previousAttempts + percentage(current)) /
        attemptState.attemptNumber;

      return { score: averagePercentage * outOf, outOf };
    }
  }
}

export function buildConfirmMessage(uiState: ActivityDeliveryState): React.ReactNode {
  const { activityContext, attemptState } = uiState;
  const displayedScore = getDisplayedScore(uiState);
  const score = `${numberFormat(displayedScore.score)}/${numberFormat(displayedScore.outOf)}`;
  const multipleAttempts = attemptState.attemptNumber > 1;
  const attemptsRemaining =
    activityContext.maxAttempts > 0
      ? Math.max(activityContext.maxAttempts - attemptState.attemptNumber, 0)
      : null;
  const hasReplacement = activityContext.replacementStrategy === 'dynamic';

  const scoreLabel =
    activityContext.scoringStrategyId === 2 ? 'Your best score' : 'Your current score';
  const attemptsDescription = multipleAttempts
    ? activityContext.scoringStrategyId === 1
      ? ` (average of ${attemptState.attemptNumber} attempts)`
      : ` (${attemptState.attemptNumber} attempts)`
    : '';

  const scoreImpact =
    activityContext.scoringStrategyId === 2 ? (
      <>
        Your best score will be kept. You can try again to improve your score; a lower score will
        not reduce your current best.
      </>
    ) : activityContext.scoringStrategyId === 3 ? (
      <>
        Your next attempt will replace your current score. Scoring below {score} will lower your
        score.
      </>
    ) : (
      <>Your score is the average of all attempts. Scoring below {score} will lower your score.</>
    );

  return (
    <div className="font-open-sans text-[14px] font-normal leading-[21px] text-Text-text-high">
      <p className="mb-1">
        <strong>{scoreLabel}: </strong>
        <strong>{score} points</strong>
        {attemptsDescription}
      </p>
      {attemptsRemaining !== null && (
        <p className="mb-1">
          <strong>Attempts Remaining: {attemptsRemaining}</strong>
          {attemptsRemaining === 1 && ' (last attempt)'}
        </p>
      )}
      <p className="mb-1">
        Resetting {hasReplacement ? 'may give you a ' : 'will clear your answer and '}
        {hasReplacement && <strong>new version of this question</strong>}
        {hasReplacement && ' and '}
        count as another attempt.
      </p>
      <p className="mb-0">{scoreImpact}</p>
    </div>
  );
}

const isResetDisabled = (uiState: ActivityDeliveryState, mode: DeliveryMode) => {
  const { maxAttempts } = uiState.activityContext;
  const { attemptNumber } = uiState.attemptState;

  return mode !== 'delivery' || (maxAttempts > 0 && attemptNumber >= maxAttempts);
};

const isSubmitDisabled = (uiState: ActivityDeliveryState, mode: DeliveryMode) => {
  const { maxAttempts } = uiState.activityContext;
  const { attemptNumber } = uiState.attemptState;

  return mode !== 'delivery' || (maxAttempts > 0 && attemptNumber > maxAttempts);
};

export const ScoreAsYouGoSubmitReset: React.FC<Props> = ({ onSubmit, onReset, mode }) => {
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  const { attemptState } = uiState;
  const didConfirmRef = React.useRef(false);
  const resetButtonRef = React.useRef<HTMLButtonElement>(null);
  const [modalOpen, setModalOpen] = React.useState(false);

  const closeModal = () => {
    setModalOpen(false);
    window.oliDispatch(modalActions.dismiss());
    window.setTimeout(() => resetButtonRef.current?.focus(), 0);
  };

  if (uiState.activityContext.graded) {
    if (isEvaluated(uiState)) {
      if (!uiState.activityContext.batchScoring) {
        const pointsDisplay =
          (attemptState.outOf === undefined || attemptState.outOf === null) && mode === 'review' ? (
            <i>hidden</i>
          ) : (
            numberFormat(attemptState.score) + ' / ' + numberFormat(attemptState.outOf)
          );

        return (
          <div className="mt-3 flex w-full items-center justify-between gap-4">
            <button
              ref={resetButtonRef}
              type="button"
              className="inline-flex items-center p-0 bg-transparent border-0"
              disabled={isResetDisabled(uiState, mode)}
              onClick={() => {
                if (modalOpen) return; // debounce: ignore if modal is already open
                setModalOpen(true);
                window.oliDispatch(
                  modalActions.display(
                    <ResetModal
                      onDone={async () => {
                        if (didConfirmRef.current) return; // one-shot protection
                        didConfirmRef.current = true;
                        closeModal();
                        try {
                          await onReset();
                        } finally {
                          didConfirmRef.current = false;
                        }
                      }}
                      onCancel={() => {
                        didConfirmRef.current = false;
                        closeModal();
                      }}
                      message={buildConfirmMessage(uiState)}
                    />,
                  ),
                );
              }}
            >
              <span
                className={`inline-flex items-center gap-2 font-open-sans text-[14px] font-semibold leading-[21px] tracking-[-0.14px] ${
                  isResetDisabled(uiState, mode)
                    ? 'cursor-not-allowed text-[#B0B4BF] dark:text-[#3B3740]'
                    : 'text-[#CE2C31] dark:text-[#FF8787]'
                }`}
              >
                <i className="fa-solid fa-rotate-right mr-2"></i>Reset Question
              </span>
            </button>
            <div className="flex items-center gap-1.5 whitespace-nowrap">
              <span className="font-open-sans text-[16px] font-normal leading-[24px] tracking-[-0.16px] text-Text-text-low">
                Points:
              </span>
              <ScoreAsYouGoIcon />
              <span className="font-open-sans text-[16px] font-bold leading-[16px] tracking-[-0.3125px] text-Text-text-accent-green">
                {pointsDisplay}
              </span>
            </div>
          </div>
        );
      }
    } else if (!uiState.activityContext.batchScoring) {
      return (
        <div className="flex justify-center">
          <button
            disabled={isSubmitDisabled(uiState, mode)}
            className="btn btn-primary"
            onClick={() => onSubmit()}
          >
            Submit Response
          </button>
        </div>
      );
    }
  }

  return null;
};
