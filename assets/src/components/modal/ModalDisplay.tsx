import * as React from 'react';
import { ModalState } from 'state/modal';
import { connect } from 'react-redux';
import { State, Dispatch } from 'state';

type ModalDisplayProps = {
  modal: ModalState;
};

const ModalDisplay = (props: ModalDisplayProps): JSX.Element => {
  const modals = props.modal
    .toArray()
    .reverse()
    .map((component, i) => <div key={i}>{component}</div>);

  return <div>{modals}</div>;
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
