import React, { useCallback } from 'react';

import { useDispatch, useSelector } from 'react-redux';
import { Button } from '../../components/misc/Button';
import { getError } from './schedule-selectors';
import { dismissError } from './scheduler-slice';

export const ErrorDisplay: React.FC = () => {
  const error = useSelector(getError);
  const dispatch = useDispatch();
  const onDismissError = useCallback(() => {
    dispatch(dismissError());
  }, [dispatch]);
  if (!error) {
    return null;
  }

  return (
    <div
      className="bg-red-100 text-red-700 align-middle py-2 px-6 mb-1 text-base fixed-top flex flex-row justify-between shadow-lg"
      role="alert"
    >
      <span>
        <i className="fa fa-circle-exclamation"></i>
      </span>
      <h3 className="pt-1">{error}</h3>
      <Button onClick={onDismissError}>Dismiss</Button>
    </div>
  );
};
