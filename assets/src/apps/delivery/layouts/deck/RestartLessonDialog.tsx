/* eslint-disable react/prop-types */
import { setRestartLesson } from '../../store/features/adaptivity/slice';
import React, { Fragment, useState } from 'react';
import { useDispatch } from 'react-redux';
import {
    navigateToFirstActivity
  } from '../../store/features/groups/actions/deck';

interface RestartLessonDialogProps {
    onRestart: () => void;
  }
const RestartLessonDialog: React.FC<RestartLessonDialogProps> = ({
    onRestart,
    }) => {

    const [isOpen, setIsOpen] = useState(true)

    const handleCloseModalClick = () => {
        setIsOpen(false);
        dispatch(setRestartLesson({ restartLesson: false }));
    };
    const dispatch = useDispatch();
    const handleRestart = () => {
        dispatch(navigateToFirstActivity());
        dispatch(setRestartLesson({ restartLesson: false }));
        setIsOpen(false);
        onRestart();
    };

    return (
        <Fragment>
            <div
                className="modal-backdrop in"
                style={{ display: isOpen ? 'block' : 'none',opacity: 0.5 }}
            ></div>

            <div
                className="RestartLessonDialog modal in"
                data-keyboard="false"
                aria-hidden={!isOpen}
                style={{display: isOpen ? 'block' : 'none', top: '20%', left:'50%'}}
            >
                <div className="modal-header">
                    <button
                        type="button"
                        className="close"
                        title="Close Restart Lesson window"
                        aria-label="Close Restart Lesson window"
                        data-dismiss="modal"
                        onClick={handleCloseModalClick}
                    >
                        ×
                    </button>
                    <h3>Restart Lesson</h3>
                </div>

                <div className="modal-body">
                    <div className="type"></div>
                    <div className="message">
                        <p>
                            Are you sure you want to restart and begin from the
                            first screen?
                        </p>
                    </div>
                </div>
                <div className="modal-footer">
                    <button className="btn " name="OK"
                        onClick={handleRestart}>
                        OK
                    </button>
                    <button className="btn " name="CANCEL"
                        onClick={handleCloseModalClick}>
                        Cancel
                    </button>
                </div>
            </div>
        </Fragment>
    );
};

export default RestartLessonDialog;
