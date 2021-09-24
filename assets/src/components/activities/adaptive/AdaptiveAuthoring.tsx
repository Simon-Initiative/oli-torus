import { AnyPartComponent } from 'components/parts/types/parts';
import React, { useCallback, useEffect, useState } from 'react';
import ReactDOM from 'react-dom';
import { AuthoringElement, AuthoringElementProps } from '../AuthoringElement';
import * as ActivityTypes from '../types';
import LayoutEditor from './components/authoring/LayoutEditor';
import { AdaptiveModelSchema } from './schema';

const Adaptive = (
  props: AuthoringElementProps<AdaptiveModelSchema> & { hostRef?: HTMLElement },
) => {
  const [selectedPartId, setSelectedPartId] = useState('');
  const [parts, setParts] = useState<any[]>(props.model?.content?.partsLayout || []);

  // this effect keeps the local parts state in sync with the props
  useEffect(() => {
    setParts(props.model?.content?.partsLayout || []);
  }, [props.model?.content?.partsLayout]);

  // this effect sets the selection from the outside based on authoring context
  useEffect(() => {
    if (props.authoringContext) {
      setSelectedPartId(props.authoringContext.selectedPartId);
    }
  }, [props.authoringContext]);

  const handleLayoutChange = useCallback(
    async (parts: AnyPartComponent[]) => {
      console.log('Layout Change!', parts);
    },
    [props.model],
  );

  const handlePartSelect = useCallback(
    async (partId: string) => {
      if (!props.editMode || selectedPartId === partId) {
        return;
      }
      setSelectedPartId(partId);
      if (props.onCustomEvent) {
        const result = await props.onCustomEvent('selectPart', { id: partId });
        console.log('got result from onSelect', result);
      }
    },
    [props.onCustomEvent, props.editMode, selectedPartId],
  );

  return (
    <LayoutEditor
      id={props.model.id || ''}
      hostRef={props.hostRef}
      width={props.model.content?.custom?.width || 1000}
      height={props.model.content?.custom?.height || 500}
      backgroundColor={props.model.content?.custom?.palette.backgroundColor || '#fff'}
      selected={selectedPartId}
      parts={parts}
      onChange={handleLayoutChange}
      onSelect={handlePartSelect}
    />
  );
};

export class AdaptiveAuthoring extends AuthoringElement<AdaptiveModelSchema> {
  props() {
    const superProps = super.props();
    return {
      ...superProps,
      hostRef: this,
    };
  }

  render(mountPoint: HTMLDivElement, props: AuthoringElementProps<AdaptiveModelSchema>) {
    ReactDOM.render(<Adaptive {...props} />, mountPoint);
  }
}
// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.authoring.element, AdaptiveAuthoring);
