import React from 'react';
import { useSelector } from 'react-redux';
import { DeliveryMode } from 'components/activities/types';
import { Modal, ModalSize } from 'components/modal/Modal';
import { modalActions } from 'actions/modal';
import { ActivityDeliveryState, isEvaluated } from 'data/activities/DeliveryState';
import { ScoreAsYouGoIcon } from './utils';

interface Props {
  onSubmit: () => void;
  onReset: () => void;
  mode: DeliveryMode;
}

interface ModalProps {
  onDone: () => void;
  onCancel: () => void;
  message: any;
}
export const ResetModal = ({ onDone, onCancel, message }: ModalProps) => {
  return (
    <Modal
      title="Reset Question"
      size={ModalSize.MEDIUM}
      okLabel="Ok"
      cancelLabel="Cancel"
      onCancel={() => onCancel()}
      onOk={() => onDone()}
    >
      {message}
    </Modal>
  );
};

function buildConfirmMessage(uiState: ActivityDeliveryState): any {
  const { activityContext } = uiState;

  let scoringDesc = 'average';
  switch (activityContext.scoringStrategyId) {
    case 1:
      scoringDesc = 'average';
      break;
    case 2:
      scoringDesc = 'best';
      break;
    case 3:
      scoringDesc = 'most recent';
      break;
  }

  return (
    <div>
      <p>
        Are you sure you want to reset <strong>Question #{activityContext.ordinal}</strong>? If you
        choose to reset this question, <strong>a new question may be generated</strong>. Your
        overall score on this question will be the <strong>{scoringDesc} of all attempts</strong> of
        all your attempts.
      </p>
      <p className="mt-3">
        If you do not answer the question after resetting, your score could be affected
      </p>
    </div>
  );
}

export const ScoreAsYouGoSubmitReset: React.FC<Props> = ({ onSubmit, onReset, mode }) => {
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  const { attemptState } = uiState;

  const numberFormat = (value: number | null) => {
    if (value === null) {
      return '';
    }
    // If the number is an integer, return it as is
    if (Number.isInteger(value)) {
      return value.toString();
    }
    // Otherwise, return it with two decimal places
    return value.toFixed(2);
  };

  if (uiState.activityContext.graded) {
    if (isEvaluated(uiState)) {
      if (!uiState.activityContext.batchScoring) {
        const pointsDisplay =
          (attemptState.score === undefined || attemptState.score === null) && mode === 'review' ? (
            <i>hidden</i>
          ) : (
            numberFormat(attemptState.score) + ' / ' + numberFormat(attemptState.outOf)
          );

        return (
          <div className="mt-3 flex justify-between">
            <button
              disabled={
                mode != 'delivery' ||
                (uiState.activityContext.maxAttempts > 0 &&
                  attemptState.attemptNumber >= uiState.activityContext.maxAttempts)
              }
              onClick={() => {
                window.oliDispatch(
                  modalActions.display(
                    <ResetModal
                      onDone={() => {
                        window.oliDispatch(modalActions.dismiss());
                        onReset();
                      }}
                      onCancel={() => window.oliDispatch(modalActions.dismiss())}
                      message={buildConfirmMessage(uiState)}
                    />,
                  ),
                );
              }}
            >
              <span className="text-red-700">
                <i className="fa-solid fa-rotate-right mr-2"></i>Reset Question
              </span>
            </button>
            <div className="text-green-500 dark:text-green-300">
              <span>
                <ScoreAsYouGoIcon /> Points:{' '}
              </span>
              <span>{pointsDisplay}</span>
            </div>
          </div>
        );
      }
    } else if (!uiState.activityContext.batchScoring || uiState.activityContext.oneAtATime) {
      return (
        <div className="flex justify-center">
          <button
            disabled={
              mode != 'delivery' ||
              (uiState.activityContext.maxAttempts > 0 &&
                attemptState.attemptNumber > uiState.activityContext.maxAttempts)
            }
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
