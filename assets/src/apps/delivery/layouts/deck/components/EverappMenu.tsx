import { toggleEverapp } from 'apps/delivery/store/features/page/actions/toggleEverapp';
import React, { useState } from 'react';
import { useDispatch } from 'react-redux';
import { Everapp } from './EverappRenderer';

export interface IEverappMenuProps {
  apps: Everapp[];
  isLegacyTheme: boolean;
}

const EverappMenu: React.FC<IEverappMenuProps> = ({ apps, isLegacyTheme }) => {
  const dispatch = useDispatch();
  const [isOpen, setIsOpen] = useState<boolean>(false);

  const handleItemClick = (app: Everapp) => {
    setIsOpen(false);
    dispatch(toggleEverapp({ id: app.id }));
  };

  return (
    <div className={`${!isLegacyTheme ? 'theme-header-beagle' : 'beagleToggleContainer'}`}>
      <button
        className={`${!isLegacyTheme ? 'theme-header-beagle__toggle' : 'beagleAppListToggle'}`}
        title="Toggle Everapp Menu"
        aria-label="Toggle Everapp menu"
        onClick={() => setIsOpen(!isOpen)}
      >
        {!isLegacyTheme ? (
          <span>
            <div className="theme-header-beagle__icon"></div>
            <span className="theme-header-beagle__label">Apps</span>{' '}
          </span>
        ) : (
          <div className="icon-beagle"></div>
        )}
      </button>
      <div
        className={`${!isLegacyTheme ? 'theme-header-beagle__panel' : 'beagleAppPanel'}
        ${isOpen ? '' : 'displayNone'}`}
      >
        <div className="beagleAppListView">
          <div className="beagleAppListWrapper">
            <div className="beagleAppList">
              {apps
                .filter((app) => app.isVisible)
                .map((app) => (
                  <div
                    key={app.id}
                    className="beagleAppItemView"
                    onClick={() => handleItemClick(app)}
                  >
                    <div className={`beagleAppItem beagleAppItem-${app.id}`}>
                      <div className="beagleAppItemContentWrapper">
                        <div className="beagleAppItemContent">
                          <div className="appIcon">
                            <img src={app.iconUrl} />
                          </div>
                          <div className="appName">{app.name}</div>
                        </div>
                      </div>
                    </div>
                  </div>
                ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default EverappMenu;
