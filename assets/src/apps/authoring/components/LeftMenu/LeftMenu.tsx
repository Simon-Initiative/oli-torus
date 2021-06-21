import React from 'react';
import AdaptivityEditor from '../AdaptivityEditor/AdaptivityEditor';
import SequenceEditor from '../SequenceEditor/SequenceEditor';

const LeftMenu: React.FC<any> = (props) => {
  return (
    <React.Fragment>
      <SequenceEditor />
      <AdaptivityEditor />
    </React.Fragment>
  );
};

export default LeftMenu;
