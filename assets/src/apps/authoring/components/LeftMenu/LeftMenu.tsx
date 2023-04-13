import React from 'react';
import AdaptiveRulesList from '../AdaptiveRulesList/AdaptiveRulesList';
import SequenceEditor from '../SequenceEditor/SequenceEditor';

const LeftMenu: React.FC = () => {
  return (
    <React.Fragment>
      <SequenceEditor />
      <AdaptiveRulesList />
    </React.Fragment>
  );
};

export default LeftMenu;
