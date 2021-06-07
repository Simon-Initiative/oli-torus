/* eslint-disable react/prop-types */
import { setRestartLesson } from '../../../store/features/adaptivity/slice';
import React, { Fragment, useState } from 'react';
import { useDispatch } from 'react-redux';

const HistoryNavigation: React.FC = () => {
  const enableHistory = false;
  // const currentPage: AdaptivePage = useSelector(selectCurrentPage);
  // enableHistory = !!currentPage?.custom?.enableHistory;

  //const currentEnsemble: SequenceEntry = useSelector(selectCurrentEnsemble);

  const [minimized, setMinimized] = useState(true);

  const dispatch = useDispatch();

  const restartHandler = () => {
    dispatch(setRestartLesson({ restartLesson: true }));
  };

  // const nextHandler = () => {
  //   dispatch(navigateToNextEnsemble());
  // };

  // const prevHandler = () => {
  //   dispatch(navigateToPrevEnsemble());
  // };

  // const minimizeHandler = () => {
  //   setMinimized(!minimized);
  // };

  // TODO this is actually driven by the student's history IF you are a student
  // and the toc otherwise
  // const historyItems =
  //     currentPage.sequence
  //         .filter((entry) => !entry.custom?.isLayer)
  //         .map((entry) => {
  //             return {
  //                 id: entry.id,
  //                 // TODO: pull all ensembles in sequence and get their names?
  //                 // maybe need a history state to track this instead!
  //                 name: entry.custom?.sequenceName || entry.id,
  //             };
  //         }) || [];
  // const currentEnsembleIndex = historyItems.findIndex(
  //     (item) => item.id === currentEnsemble.id
  // );
  // const isFirst = currentEnsembleIndex === 0;
  // const isLast = currentEnsembleIndex === historyItems.length - 1;

  return (
    <Fragment>
      {/* {enableHistory ? (
                <div className="historyStepView pullLeftInCheckContainer">
                    <div className="historyStepContainer">
                        <button
                            onClick={prevHandler}
                            className="backBtn historyStepButton"
                            aria-label="Previous screen"
                            disabled={isFirst}
                        >
                            <span className="icon-chevron-left" />
                        </button>
                        <button
                            onClick={nextHandler}
                            className="nextBtn historyStepButton"
                            aria-label="Next screen"
                            disabled={isLast}
                        >
                            <span className="icon-chevron-right" />
                        </button>
                    </div>
                </div>
            ) : null} */}
      <div
        className={[
          'navigationContainer',
          enableHistory ? undefined : 'pullLeftInCheckContainer',
        ].join(' ')}
      >
        <aside className={minimized ? 'minimized' : undefined}>
          {/* {enableHistory ? (
                        <Fragment>
                            <button
                                onClick={minimizeHandler}
                                className="navigationToggle"
                                aria-label="Show lesson history"
                                aria-haspopup="true"
                                aria-controls="theme-history-panel"
                                aria-pressed="false"
                            />

                            <HistoryPanel
                                items={historyItems}
                                onMinimize={minimizeHandler}
                                onRestart={restartHandler}
                            />
                        </Fragment>
                    )  */}
          <button onClick={restartHandler} className="theme-no-history-restart">
            <span>
              <div className="theme-no-history-restart__icon" />
              <span className="theme-no-history-restart__label">Restart Lesson</span>
            </span>
          </button>
        </aside>
      </div>
    </Fragment>
  );
};

export default HistoryNavigation;
