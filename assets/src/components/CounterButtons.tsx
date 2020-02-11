import * as React from 'react';
import { connect } from 'react-redux';
import { State, Dispatch } from 'state';
import { classNames } from 'utils/classNames';
import { updateCount, clearCount } from 'state/counter';

export interface CounterButtonsProps {
  className?: string;
  count: number;
  onUpdateCount: (count: number) => void;
  onClearCount: () => void;
};

/**
 * CounterButtons React Stateless Component
 */
const CounterButtons = ({
  className, count, onUpdateCount, onClearCount,
}: CounterButtonsProps) => {
  return (
    <div className={classNames(['CounterButtons', className])}>
      <button className="ui secondary basic button"onClick={() => onUpdateCount(count + 1)}>+1</button>
      <button className="ui secondary basic button"onClick={() => onUpdateCount(count - 1)}>-1</button>
      <button className="ui secondary basic button" onClick={() => onClearCount()}>Clear</button>
    </div>
  );
};

interface StateProps {
  count: number;
}

interface DispatchProps {
  onUpdateCount: (count: number) => void;
  onClearCount: () => void;
}

type OwnProps = {
  className?: string;
};

const mapStateToProps = (state: State, ownProps: OwnProps): StateProps => {
  const { count } = state.counter;

  return {
    count
  };
};

const mapDispatchToProps = (dispatch: Dispatch, ownProps: OwnProps): DispatchProps => {
  return {
    onUpdateCount: (count) => dispatch(updateCount(count)),
    onClearCount: () => dispatch(clearCount()),
  };
};

export const controller = connect<StateProps, DispatchProps, OwnProps>(
  mapStateToProps,
  mapDispatchToProps,
)(CounterButtons);

export { controller as CounterButtons };
