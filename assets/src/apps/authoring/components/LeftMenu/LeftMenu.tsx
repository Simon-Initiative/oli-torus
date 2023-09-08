import React, { useState } from 'react';
import AdaptiveRuleContextMenu from '../AdaptiveRulesList/AdaptiveRuleContextMenu';
import AdaptiveRulesList from '../AdaptiveRulesList/AdaptiveRulesList';
import SequenceEditor from '../SequenceEditor/SequenceEditor';
import SequenceItemContextMenu from '../SequenceEditor/SequenceItemContextMenu';

const LeftMenu: React.FC = () => {
  const [displaySequenceContextMenu, setDisplaySequenceContextMenu] = useState(false);
  const [sequenceItemDetails, setSequenceItemDetails] = useState();
  const [sequenceMenuItemClicked, setSequenceMenuItemClicked] = useState<any>({});

  const [displayAdaptivRuleContextMenu, setDisplayAdaptivRuleContextMenu] = useState(false);
  const [adaptivRuleDetails, setAdaptivRuleDetails] = useState();
  const [adaptivRuleMenuItemClicked, setAdaptivRuleMenuItemClicked] = useState<any>({});

  const toggleSequenceContextMenu = (showToast: boolean, itemDetails: any) => {
    if (itemDetails) {
      setSequenceItemDetails(itemDetails);
    }
    setDisplaySequenceContextMenu(showToast || false);
  };

  const handleSequenceContextMenuItemClick = (itemDetails: any) => {
    setSequenceMenuItemClicked(itemDetails);
  };

  const toggleAdaptivRuleContextMenu = (showToast: boolean, itemDetails: any) => {
    if (itemDetails) {
      setAdaptivRuleDetails(itemDetails);
    }
    setDisplayAdaptivRuleContextMenu(showToast || false);
  };

  const handleAdaptivRuleContextMenuItemClick = (itemDetails: any) => {
    setAdaptivRuleMenuItemClicked(itemDetails);
  };
  return (
    <React.Fragment>
      <SequenceEditor
        menuItemClicked={sequenceMenuItemClicked}
        contextMenuClicked={toggleSequenceContextMenu}
      />
      <AdaptiveRulesList
        menuItemClicked={adaptivRuleMenuItemClicked}
        contextMenuClicked={toggleAdaptivRuleContextMenu}
      />
      <SequenceItemContextMenu
        contextMenuClicked={toggleSequenceContextMenu}
        displayContextMenu={displaySequenceContextMenu}
        sequenceItemDetails={sequenceItemDetails}
        onMenuItemClick={handleSequenceContextMenuItemClick}
      ></SequenceItemContextMenu>

      <AdaptiveRuleContextMenu
        contextMenuClicked={toggleAdaptivRuleContextMenu}
        displayContextMenu={displayAdaptivRuleContextMenu}
        adaptiveRuleDetails={adaptivRuleDetails}
        onMenuItemClick={handleAdaptivRuleContextMenuItemClick}
      ></AdaptiveRuleContextMenu>
    </React.Fragment>
  );
};

export default LeftMenu;
