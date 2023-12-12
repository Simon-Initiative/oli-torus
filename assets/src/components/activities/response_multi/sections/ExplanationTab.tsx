import React from 'react';
import { Explanation } from 'components/activities/common/explanation/ExplanationAuthoring';
import { MultiInput } from 'components/activities/multi_input/schema';

interface Props {
  input: MultiInput;
}

export const ExplanationTab: React.FC<Props> = (props) => {
  return <Explanation key={props.input.partId} partId={props.input.partId} />;
};
