import React, { useState } from 'react';

interface HeaderNavProps {
  content: any;
  isVisible: boolean;
}

const HeaderNav: React.FC<HeaderNavProps> = (props: HeaderNavProps) => {
  const { content, isVisible } = props;
  return (
    <nav className={`aa-header-nav top-panel${isVisible ? ' open' : ''}`}>{content.title}</nav>
  );
};

export default HeaderNav;
