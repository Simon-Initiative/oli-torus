/* eslint-disable react/prop-types */
import React, { CSSProperties } from 'react';
import { renderFlow } from '../janus-text-flow/TextFlow';
import { JanusHubSpokeProperties } from './schema';

const SpokeItemContentComponent: React.FC<any> = ({ itemId, nodes, state }) => {
  return (
    <div style={{ position: 'relative', overflow: 'hidden' }}>
      {nodes.map((subtree: any) => {
        const style: any = {};
        if (subtree.tag === 'p') {
          const hasImages = subtree.children.some((child: { tag: string }) => child.tag === 'img');
          if (hasImages) {
            style.display = 'inline-block';
          }
        }
        return renderFlow(`${itemId}-root`, subtree, style, state);
      })}
    </div>
  );
};

const SpokeItemContent = React.memo(SpokeItemContentComponent);

export const SpokeItems: React.FC<JanusHubSpokeProperties> = ({
  nodes,
  state,
  itemId,
  layoutType,
  totalItems,
  idx,
  overrideHeight,
  columns = 1,
  index,
  verticalGap = 0,
}) => {
  const spokeItemStyles: CSSProperties = {};
  if (layoutType === 'horizontalLayout') {
    if (columns === 1) {
      spokeItemStyles.width = `calc(${Math.floor(100 / totalItems)}% - 6px)`;
    } else {
      spokeItemStyles.width = `calc(100% / ${columns} - 6px)`;
    }
    if (idx !== 0) {
      spokeItemStyles.left = `calc(${(100 / totalItems) * idx}% - 6px)`;
    }
    spokeItemStyles.position = `absolute`;

    spokeItemStyles.display = `inline-block`;
  }
  if (layoutType === 'verticalLayout' && overrideHeight) {
    spokeItemStyles.height = `calc(${100 / totalItems}%)`;
  }
  if (layoutType === 'verticalLayout' && verticalGap && index > 0) {
    spokeItemStyles.marginTop = `${verticalGap}px`;
  }
  return (
    <React.Fragment>
      <div style={spokeItemStyles} className={` hub-spoke-item`}>
        <button type="button" style={{ width: '100%' }} className="btn btn-primary">
          <SpokeItemContent itemId={itemId} nodes={nodes} state={state} />
        </button>
      </div>
      {layoutType !== 'horizontalLayout' && <br style={{ padding: '0px' }} />}
    </React.Fragment>
  );
};
