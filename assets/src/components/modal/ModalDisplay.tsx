import * as React from 'react';
import { connect } from 'react-redux';
import { Dispatch, State } from 'state';
import { ModalState } from 'state/modal';

type ModalDisplayProps = {
  modal: ModalState;
};

const ModalDisplay = (props: ModalDisplayProps): JSX.Element => {
  return props.modal.caseOf({
    just: (modal) => <>{modal}</>,
    nothing: () => <></>,
  });
};

interface StateProps {
  modal: ModalState;
}
// eslint-disable-next-line
interface OwnProps {}
// eslint-disable-next-line
interface DispatchProps {}

const mapStateToProps = (state: State, _ownProps: OwnProps): StateProps => {
  const { modal } = state;

  return {
    modal,
  };
};

const w = window as any;
w.init_count = w.init_count || 0;

const mapDispatchToProps = (dispatch: Dispatch, _ownProps: OwnProps): DispatchProps => {
  window.oliDispatch = dispatch;

  return {};
};

export const controller = connect<StateProps, DispatchProps, OwnProps>(
  mapStateToProps,
  mapDispatchToProps,
)(ModalDisplay);

export { controller as ModalDisplay };

declare global {
  interface Window {
    oliDispatch: Dispatch;
    $: typeof $;
  }
}
