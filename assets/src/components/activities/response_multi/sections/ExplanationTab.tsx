import React from 'react';
import { Explanation } from 'components/activities/common/explanation/ExplanationAuthoring';
import { ResponseMultiInput } from 'components/activities/response_multi/schema';

interface Props {
  input: ResponseMultiInput;
}

export const ExplanationTab: React.FC<Props> = (props) => {
  return <Explanation key={props.input.partId} partId={props.input.partId} />;
};
