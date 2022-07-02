import { MultiInputActions } from 'components/activities/vlab/actions';
import { friendlyVlabParameter } from 'components/activities/vlab/utils';
import { VlabValue, VlabSchema } from 'components/activities/vlab/schema';
import React from 'react';

interface Props {
  input: VlabValue;
}
export const VlabParameterSelector: React.FC<Props> = (props) => {
  return (
    <div>The currently selected parameter is {friendlyVlabParameter(props.input.parameter)}.</div>
  );
};
