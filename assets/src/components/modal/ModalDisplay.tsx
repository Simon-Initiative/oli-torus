import * as React from 'react';
import { ModalState } from 'state/modal';
import { connect } from 'react-redux';
import { State, Dispatch } from 'state';

type ModalDisplayProps = {
  modal: ModalState;
};

const ModalDisplay = (props: ModalDisplayProps) : JSX.Element => {

  const modals = props.modal
    .toArray()
    .reverse()
    .map((component, i) => <div key={i}>{component}</div>);

  return (
    <div>
      {modals}
    </div>
  );

};

interface StateProps { modal: ModalState; }
interface OwnProps {}
interface DispatchProps {}

const mapStateToProps = (state: State, ownProps: OwnProps): StateProps => {
  const { modal } = state;

  return {
    modal,
  };
};

const mapDispatchToProps = (dispatch: Dispatch, ownProps: OwnProps): DispatchProps => {

  (window as any).oliDispatch = dispatch;

  return {

  };
};

export const controller = connect<StateProps, DispatchProps, OwnProps>(
  mapStateToProps,
  mapDispatchToProps,
)(ModalDisplay);

export { controller as ModalDisplay };
