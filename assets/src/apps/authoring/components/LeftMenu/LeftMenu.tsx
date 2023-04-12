import AdaptiveRulesList from '../AdaptiveRulesList/AdaptiveRulesList';
import SequenceEditor from '../SequenceEditor/SequenceEditor';
import React from 'react';

const LeftMenu: React.FC = () => {
  return (
    <React.Fragment>
      <SequenceEditor />
      <AdaptiveRulesList />
    </React.Fragment>
  );
};

export default LeftMenu;
