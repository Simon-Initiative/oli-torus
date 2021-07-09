import { Checkbox } from 'components/misc/icons/checkbox/Checkbox';
import { ChoiceId, Manifest } from 'components/activities/types';
import { isCorrect } from 'data/content/activities/activityUtils';
import {
  ActivityDeliveryState,
  initializeState,
  isEvaluated,
  setSelection,
  activityDeliverySlice,
  resetAction,
} from 'data/content/activities/DeliveryState';
import React, { useEffect } from 'react';
import ReactDOM from 'react-dom';
import { Provider, useDispatch, useSelector } from 'react-redux';
import { configureStore } from 'state/store';
import {
  DeliveryElement,
  DeliveryElementProps,
  DeliveryElementProvider,
  useDeliveryElementContext,
} from '../DeliveryElement';
import { ResetButtonConnected } from 'components/activities/common/delivery/resetButton/ResetButtonConnected';
import { SubmitButtonConnected } from 'components/activities/common/delivery/submitButton/SubmitButtonConnected';
import { HintsDeliveryConnected } from 'components/activities/common/hints/delivery/HintsDeliveryConnected';
import { EvaluationConnected } from 'components/activities/common/delivery/evaluation/EvaluationConnected';
import { GradedPointsConnected } from 'components/activities/common/delivery/gradedPoints/GradedPointsConnected';
import { StemDeliveryConnected } from 'components/activities/common/stem/delivery/StemDeliveryConnected';
import { ChoicesDeliveryConnected } from 'components/activities/common/choices/delivery/ChoicesDeliveryConnected';
import { valueOr } from 'utils/common';
import { CATASchema } from 'components/activities/check_all_that_apply/schema';
import { Maybe } from 'tsmonad';
import { cataV1toV2 } from 'components/activities/check_all_that_apply/transformations/v2';

export const CheckAllThatApplyComponent: React.FC = () => {
  const {
    state: activityState,
    onResetActivity,
    onSaveActivity,
  } = useDeliveryElementContext<CATASchema>();
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  const dispatch = useDispatch();

  useEffect(() => {
    dispatch(
      initializeState(
        activityState,
        valueOr(
          activityState.parts[0]?.response?.input
            ?.split(' ')
            .reduce((ids: string[], id: string) => ids.concat([id]), [] as ChoiceId[]),
          [],
        ),
      ),
    );
  }, []);

  // First render initializes state
  if (!uiState.selection) {
    return null;
  }

  return (
    <div className={`activity cata-activity ${isEvaluated(uiState) ? 'evaluated' : ''}`}>
      <div className="activity-content">
        <StemDeliveryConnected />
        <GradedPointsConnected />
        <ChoicesDeliveryConnected
          unselectedIcon={<Checkbox.Unchecked disabled={isEvaluated(uiState)} />}
          selectedIcon={
            !isEvaluated(uiState) ? (
              <Checkbox.Checked />
            ) : isCorrect(uiState.attemptState) ? (
              <Checkbox.Correct />
            ) : (
              <Checkbox.Incorrect />
            )
          }
          onSelect={(id) => dispatch(setSelection(id, onSaveActivity, 'multiple'))}
        />
        <ResetButtonConnected onReset={() => dispatch(resetAction(onResetActivity, []))} />
        <SubmitButtonConnected />
        <HintsDeliveryConnected />
        <EvaluationConnected />
      </div>
    </div>
  );
};

// Defines the web component, a simple wrapper over our React component above
export class CheckAllThatApplyDelivery extends DeliveryElement<CATASchema> {
  migrateModelVersion(model: any): CATASchema {
    return Maybe.maybe(model.authoring.version).caseOf({
      just: (v2) => model,
      nothing: () => cataV1toV2(model),
    });
  }

  render(mountPoint: HTMLDivElement, props: DeliveryElementProps<CATASchema>) {
    const store = configureStore({}, activityDeliverySlice.reducer);
    ReactDOM.render(
      <Provider store={store}>
        <DeliveryElementProvider {...props}>
          <CheckAllThatApplyComponent />
        </DeliveryElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}

// Register the web component:
// eslint-disable-next-line
const manifest = require('./manifest.json') as Manifest;
window.customElements.define(manifest.delivery.element, CheckAllThatApplyDelivery);
