import React from 'react';
import * as Persistence from 'data/persistence/activity';
import { removeEmpty } from 'utils/common';
import produce from 'immer';
export const xdefaultState = (model) => {
    const parts = model.authoring.parts.map((p) => ({
        attemptNumber: 1,
        attemptGuid: p.id,
        dateEvaluated: null,
        score: null,
        outOf: null,
        response: null,
        feedback: null,
        hints: [],
        hasMoreHints: removeEmpty(p.hints).length > 0,
        hasMoreAttempts: true,
        partId: p.id,
    }));
    return {
        attemptNumber: 1,
        attemptGuid: 'testmode',
        dateEvaluated: null,
        score: null,
        outOf: null,
        hasMoreAttempts: true,
        parts,
    };
};
function initHints(model) {
    return model.authoring.parts.reduce((m, p) => {
        m[p.id] = 0;
        return m;
    }, {});
}
export class TestModeHandler extends React.Component {
    constructor(props) {
        super(props);
        this.state = {
            model: props.model,
            hints: initHints(props.model),
        };
        this.ref = React.createRef();
    }
    getPart(id) {
        return this.state.model.authoring.parts.find((p) => p.id === id);
    }
    componentDidMount() {
        this.setUpHandler('submitPart', this.handleSubmit.bind(this));
        this.setUpHandler('submitActivity', this.handleSubmit.bind(this));
        this.setUpHandler('requestHint', this.handleHint.bind(this));
        this.setUpHandler('resetActivity', this.handleReset.bind(this));
        this.setUpHandler('submitEvaluations', this.handleSubmitEvaluations.bind(this));
    }
    // Helper function to isolate the setting up and handling of the custom event listener
    setUpHandler(name, handler) {
        if (this.ref !== null) {
            this.ref.current.addEventListener(name, (e) => {
                e.preventDefault();
                e.stopPropagation();
                handler(e.detail.continuation, e.detail.partAttemptGuid, e.detail.payload);
            });
        }
    }
    // we can handle individual part and activity submits in a unified manner
    handleSubmit(continuation, partId, partInputs) {
        Persistence.evaluate(this.state.model, partInputs).then((result) => {
            const actions = result.evaluations.map((e) => {
                return {
                    type: 'FeedbackAction',
                    error: e.error,
                    attempt_guid: e.part_id,
                    out_of: e.result.out_of,
                    score: e.result.score,
                    feedback: e.feedback,
                };
            });
            continuation({ type: 'success', actions }, undefined);
        });
    }
    handleSubmitEvaluations(continuation, attemptGuid, clientEvaluations) {
        const evaluatedParts = clientEvaluations.map((e) => {
            return {
                type: 'EvaluatedPart',
                out_of: e.out_of,
                score: e.score,
                feedback: e.feedback,
            };
        });
        continuation({ type: 'success', actions: evaluatedParts }, undefined);
    }
    handleHint(continuation, partId) {
        const index = this.state.hints[partId];
        const hints = removeEmpty(this.getPart(partId).hints);
        const hasMoreHints = hints.length > index + 1;
        const hint = hints[index];
        const response = {
            type: 'success',
            hint,
            hasMoreHints,
        };
        this.setState(produce(this.state, (draftState) => {
            draftState.hints[partId] = index + 1;
        }));
        continuation(response, undefined);
    }
    handleReset(continuation) {
        Persistence.transform(this.props.model).then((result) => {
            const model = result.transformed === null ? this.props.model : result.transformed;
            this.setState(produce(this.state, (draftState) => {
                draftState.model = model;
                draftState.hints = initHints(model);
            }));
            const attemptState = xdefaultState(model);
            continuation({ type: 'success', model, attemptState }, undefined);
        });
    }
    render() {
        return (<div className="test-mode-handler delivery" ref={this.ref}>
        {this.props.children}
      </div>);
    }
}
//# sourceMappingURL=TestModeHandler.jsx.map