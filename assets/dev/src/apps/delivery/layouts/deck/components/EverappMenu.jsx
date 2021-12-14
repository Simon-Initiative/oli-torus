import { toggleEverapp } from 'apps/delivery/store/features/page/actions/toggleEverapp';
import React, { useState } from 'react';
import { useDispatch } from 'react-redux';
const EverappMenu = ({ apps }) => {
    const dispatch = useDispatch();
    const [isOpen, setIsOpen] = useState(false);
    const handleItemClick = (app) => {
        setIsOpen(false);
        dispatch(toggleEverapp({ id: app.id }));
    };
    return (<div className="beagleToggleContainer">
      <button className="beagleAppListToggle" title="Toggle Everapp Menu" aria-label="Toggle Everapp menu" onClick={() => setIsOpen(!isOpen)}>
        <div className="icon-beagle"></div>
      </button>
      <div className="beagleAppPanel">
        <div className={`beagleAppListView ${isOpen ? '' : 'displayNone'}`}>
          <div className="beagleAppListWrapper">
            <div className="beagleAppList">
              {apps
            .filter((app) => app.isVisible)
            .map((app) => (<div key={app.id} className="beagleAppItemView" onClick={() => handleItemClick(app)}>
                    <div className={`beagleAppItem beagleAppItem-${app.id}`}>
                      <div className="beagleAppItemContentWrapper">
                        <div className="beagleAppItemContent">
                          <div className="appIcon">
                            <img src={app.iconUrl}/>
                          </div>
                          <div className="appName">{app.name}</div>
                        </div>
                      </div>
                    </div>
                  </div>))}
            </div>
          </div>
        </div>
      </div>
    </div>);
};
export default EverappMenu;
//# sourceMappingURL=EverappMenu.jsx.map