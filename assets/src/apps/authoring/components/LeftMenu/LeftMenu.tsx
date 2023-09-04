import React, { useState } from 'react';
import AdaptiveRulesList from '../AdaptiveRulesList/AdaptiveRulesList';
import SequenceEditor from '../SequenceEditor/SequenceEditor';
import SequenceItemContextMenu from '../SequenceEditor/SequenceItemContextMenu';

const LeftMenu: React.FC = () => {
  const [displayContextMenu, setDisplayContextMenu] = useState(false);
  const [menuDetails, setMenuDetails] = useState();
  const [menuItemClicked, setMenuItemClicked] = useState<any>({});
  const toggleSequenceContextMenu = (showToast: boolean, itemDetails: any) => {
    console.log({ showToast });

    if (itemDetails) {
      setMenuDetails(itemDetails);
    }
    setDisplayContextMenu(showToast ? showToast : false);
  };

  const handleContextMenuItemClick = (itemDetails: any) => {
    console.log({ itemDetails });

    setMenuItemClicked(itemDetails);
  };
  return (
    <React.Fragment>
      <SequenceEditor
        menuItemClicked={menuItemClicked}
        contextMenuClicked={toggleSequenceContextMenu}
      />
      <AdaptiveRulesList />
      <SequenceItemContextMenu
        contextMenuClicked={toggleSequenceContextMenu}
        displayContextMenu={displayContextMenu}
        sequenceItemDetails={menuDetails}
        onMenuItemClick={handleContextMenuItemClick}
      ></SequenceItemContextMenu>
    </React.Fragment>
  );
};

export default LeftMenu;
