import React from 'react';
import { ActivityModelSchema, PartResponse } from 'components/activities/types';
import * as Persistence from 'data/persistence/activity';
import { RequestHintResponse } from 'components/activities/DeliveryElement';
import produce from 'immer';


export const defaultState = (model: ActivityModelSchema) => {

  const parts = model.authoring.parts.map((p: any) =>
    ({
      attemptNumber: 1,
      attemptGuid: p.id,
      dateEvaluated: null,
      score: null,
      outOf: null,
      response: null,
      feedback: null,
      hints: [],
      hasMoreHints: p.hints.length > 0,
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


export interface TestModelHandlerProps {
  children: any;
  model: ActivityModelSchema;
}

type DeliveredHints = { [index: string]: number };

export interface TestModelHandlerState {
  model: ActivityModelSchema;
  hints: DeliveredHints;
}

type Continuation = (success: any, error: any) => void;

function initHints(model: ActivityModelSchema) {
  return model.authoring.parts.reduce((m: any, p: any) => {
    m[p.id] = 0;
    return m;
  }, {});
}

export class TestModeHandler extends React.Component<TestModelHandlerProps, TestModelHandlerState> {

  ref: any;

  constructor(props: TestModelHandlerProps) {
    super(props);

    this.state = {
      model: props.model,
      hints: initHints(props.model),
    };

    this.ref = React.createRef();
  }

  getPart(id: string) : any {
    return this.state.model.authoring.parts.find((p: any) => p.id === id);
  }

  componentDidMount() {
    this.setUpHandler('submitPart', this.handleSubmit.bind(this));
    this.setUpHandler('submitActivity', this.handleSubmit.bind(this));
    this.setUpHandler('requestHint', this.handleHint.bind(this));
    this.setUpHandler('resetActivity', this.handleReset.bind(this));
  }

  // Helper function to isolate the setting up and handling of the custom event listener
  setUpHandler(name: string, handler: (continuation: Continuation,
    partId: string, payload: any) => void) {

    if (this.ref !== null) {
      this.ref.current.addEventListener(name, (e : CustomEvent) => {
        e.preventDefault();
        e.stopPropagation();
        handler(e.detail.continuation, e.detail.partAttemptGuid, e.detail.payload);
      });
    }
  }


  // we can handle individual part and activity submits in a unified manner
  handleSubmit(continuation: Continuation, partId: string, partInputs: PartResponse[]) {
    Persistence.evaluate(this.state.model, partInputs)
    .then((result: Persistence.Evaluated) => {

      const evaluations = result.evaluations
        .map((e : any) => {
          return {
            type: 'EvaluatedPart',
            error: e.error,
            attempt_guid: e.part_id,
            out_of: e.result.out_of,
            score: e.result.score,
            feedback: e.feedback,
          };
        });

      continuation({ type: 'success', evaluations }, undefined);
    });
  }

  handleHint(continuation: Continuation, partId: string) {
    const index = this.state.hints[partId];
    const hasMoreHints = this.getPart(partId).hints.length > index + 1;
    const hint = this.getPart(partId).hints[index];
    const response : RequestHintResponse = {
      type: 'success',
      hint,
      hasMoreHints,
    };

    this.setState(produce(this.state, (draftState) => {
      draftState.hints[partId] = index + 1;
    }));

    continuation(response, undefined);
  }

  handleReset(continuation: Continuation) {

    Persistence.transform(this.props.model)
    .then((result: Persistence.Transformed) => {
      const model = result.transformed === null ? this.props.model : result.transformed;
      this.setState(produce(this.state, (draftState) => {
        draftState.model = model;
        draftState.hints = initHints(model);
      }));

      const attemptState = defaultState(model);
      continuation({ type: 'success', model, attemptState }, undefined);
    });
  }

  render() {
    return (
      <div className="delivery" ref={this.ref}>
        {this.props.children}
      </div>
    );
  }
}
