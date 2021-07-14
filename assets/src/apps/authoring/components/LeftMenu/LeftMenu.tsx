import React from 'react';
import AdaptivityRuleList from '../AdaptivityRuleList/AdaptivityRuleList';
import SequenceEditor from '../SequenceEditor/SequenceEditor';

const LeftMenu: React.FC<any> = (props) => {
  return (
    <React.Fragment>
      <SequenceEditor />
      <AdaptivityRuleList />
    </React.Fragment>
  );
};

export default LeftMenu;
