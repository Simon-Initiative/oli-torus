import React, { useState } from 'react';
import AdaptiveRulesList from '../AdaptiveRulesList/AdaptiveRulesList';
import SequenceEditor from '../SequenceEditor/SequenceEditor';
import SequenceItemContextMenu from '../SequenceEditor/SequenceItemContextMenu';

const LeftMenu: React.FC = () => {
  const [displayContextMenu, setDisplayContextMenu] = useState(false);
  const [menuDetails, setMenuDetails] = useState();
  const toggleSequenceContextMenu = (showToast: boolean, itemDetails: any) => {
    if (itemDetails) {
      setMenuDetails(itemDetails);
    }
    setDisplayContextMenu(showToast ? showToast : false);
  };
  return (
    <React.Fragment>
      <SequenceEditor contextMenuClicked={toggleSequenceContextMenu} />
      <AdaptiveRulesList />
      <SequenceItemContextMenu
        contextMenuClicked={toggleSequenceContextMenu}
        displayContextMenu={displayContextMenu}
        sequenceItemDetails={menuDetails}
      ></SequenceItemContextMenu>
    </React.Fragment>
  );
};

export default LeftMenu;
