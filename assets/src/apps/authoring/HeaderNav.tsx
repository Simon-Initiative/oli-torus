/* eslint-disable @typescript-eslint/no-var-requires */
import React from 'react';
import {
  ImageIcon,
  VideoIcon,
  TextIcon,
  ComponentListIcon,
  NavButtonIcon,
  MultiChoiceIcon,
  UserInputIcon,
  PreviewIcon,
  PublishIcon,
} from './icons';

interface HeaderNavProps {
  content: any;
  isVisible: boolean;
}

const HeaderNav: React.FC<HeaderNavProps> = (props: HeaderNavProps) => {
  const { content, isVisible } = props;
  return (
    <nav
      className={`aa-header-nav top-panel${
        isVisible ? ' open' : ''
      } d-flex justify-content-between`}
      style={{ alignItems: 'center' }}
    >
      <div>{content.title}</div>
      <div className="btn-toolbar" role="toolbar" aria-label="Toolbar with button groups">
        <div className="btn-group me-2" role="group" aria-label="First group">
          <div className="px-2">
            <TextIcon></TextIcon>
          </div>
          <div className="px-2">
            <ImageIcon></ImageIcon>
          </div>
          <div className="px-2">
            <VideoIcon></VideoIcon>
          </div>
        </div>
        <div className="btn-group me-2" role="group" aria-label="Second group">
          <div className="px-2">
            <NavButtonIcon></NavButtonIcon>
          </div>
          <div className="px-2">
            <MultiChoiceIcon></MultiChoiceIcon>
          </div>
          <div className="px-2">
            <UserInputIcon></UserInputIcon>
          </div>
        </div>
        <div className="btn-group" role="group" aria-label="Third group">
          <div className="px-2">
            <ComponentListIcon></ComponentListIcon>
          </div>
        </div>
      </div>
      <div>
        <div className="btn-group" role="group" aria-label="Third group">
          <div className="px-2">
            <PreviewIcon></PreviewIcon>
          </div>
          <div className="px-2">
            <PublishIcon></PublishIcon>
          </div>
        </div>
      </div>
    </nav>
  );
};

export default HeaderNav;
