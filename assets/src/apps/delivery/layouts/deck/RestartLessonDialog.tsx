import { setRestartLesson } from '../../store/features/adaptivity/slice';
import React, { Fragment, useContext, useState } from 'react';
import { useDispatch } from 'react-redux';
import {
    navigateToFirstActivity
  } from '../../store/features/groups/actions/deck';
//import { CapiVariableTypes } from '../../store/features/variables/variablesSlice';

const RestartLessonDialog = () => {

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
        //resetState();
    };

    // const resetState = () => {
    //     //stateService.reset();

    //     let session: any = {};
    //     if (props.session && typeof props.session === 'string') {
    //         try {
    //             session = JSON.parse(props.session);
    //         } catch (e) {
    //             console.warn('session was invalid json string');
    //         }
    //     }
    //     // stateService.set([
    //     //     // the following user related values are NOT stored in SS state normally
    //     //     {
    //     //         id: 'session.userName',
    //     //         key: 'userName',
    //     //         type: CapiVariableTypes.STRING,
    //     //         value: session.userName,
    //     //     },
    //     //     {
    //     //         id: 'session.user.role',
    //     //         key: 'role',
    //     //         type: CapiVariableTypes.NUMBER,
    //     //         value: session.userRole ? parseInt(session.userRole, 10) : 1,
    //     //     },
    //     //     // TODO: where does attemptNumber come from?
    //     //     {
    //     //         id: 'session.attemptNumber',
    //     //         key: 'attemptNumber',
    //     //         type: CapiVariableTypes.NUMBER,
    //     //         value: 0,
    //     //     },
    //     //     {
    //     //         id: 'session.tutorialScore',
    //     //         key: 'tutorialScore',
    //     //         type: CapiVariableTypes.NUMBER,
    //     //         value: 0,
    //     //     },
    //     //     {
    //     //         id: 'session.currentQuestionScore',
    //     //         key: 'currentQuestionScore',
    //     //         type: CapiVariableTypes.NUMBER,
    //     //         value: 0,
    //     //     },
    //     //     {
    //     //         id: 'session.timeOnQuestion',
    //     //         key: 'timeOnQuestion',
    //     //         type: CapiVariableTypes.NUMBER,
    //     //         value: 0,
    //     //     },
    //     //     {
    //     //         id: 'session.questionTimeExceeded',
    //     //         key: 'questionTimeExceeded',
    //     //         type: CapiVariableTypes.BOOLEAN,
    //     //         value: false,
    //     //     },
    //     //     {
    //     //         id: 'session.timeStartQuestion',
    //     //         key: 'timeStartQuestion',
    //     //         type: CapiVariableTypes.NUMBER,
    //     //         value: Date.now(),
    //     //     },
    //     // ]);
    // }
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
