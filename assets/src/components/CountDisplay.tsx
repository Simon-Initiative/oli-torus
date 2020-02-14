import * as React from 'react';
import { connect } from 'react-redux';
import * as Immutable from 'immutable';
import { Maybe } from 'tsmonad';
import { State, Dispatch } from 'state';
import { classNames } from 'utils/classNames';

export interface CountDisplayProps {
  className?: string;
  count: number;
  name: string;
  animals: Maybe<Immutable.List<string>>;
}

/**
 * CountDisplay React Stateless Component
 */
const CountDisplay = ({ className, count, name, animals }: CountDisplayProps) => {
  return (
    <div className={classNames(['CountDisplay', className])}>
      <h2>Hello {name}, The count is: {count}</h2>
      <div>
        {animals.caseOf({
          just: animals => animals.join(', '),
          nothing: () => 'No Animals',
        })}
      </div>
    </div>
  );
};

interface StateProps {
  count: number;
  animals: Maybe<Immutable.List<string>>;
}

interface DispatchProps {

}

type OwnProps = {
  className?: string;
  name: string;
};

const mapStateToProps = (state: State, ownProps: OwnProps): StateProps => {
  const { count, animals } = state.counter;

  return {
    count,
    animals,
  };
};

const mapDispatchToProps = (dispatch: Dispatch, ownProps: OwnProps): DispatchProps => {
  return {

  };
};

export const controller = connect<StateProps, DispatchProps, OwnProps>(
  mapStateToProps,
  mapDispatchToProps,
)(CountDisplay);

export { controller as CountDisplay };
