import React, { useLayoutEffect, useMemo, useRef, useState } from 'react';
import ReactDOM from 'react-dom';
import { DeliveryElement, DeliveryElementProps } from '../DeliveryElement';
import { attachInteractiveBridge, createDeliveryHandler } from './deliveryBridge';
import manifest from './manifest.json';
import { createPreviewSession } from './previewSession';
import { InteractiveModelSchema } from './schema';

function bundleUrl(model: Pick<InteractiveModelSchema, 'bundle'>): URL | null {
  try {
    const url = new URL(model.bundle?.indexUrl ?? '');
    return ['https:', 'http:'].includes(url.protocol) && !url.username && !url.password
      ? url
      : null;
  } catch {
    return null;
  }
}

/** Embeds a static experience with capabilities bound to the current learner attempt. */
export function InteractiveExperience({
  model,
  delivery,
  preview,
}: {
  model: Pick<InteractiveModelSchema, 'bundle'>;
  delivery?: DeliveryElementProps<InteractiveModelSchema>;
  preview?: { partIds: string[]; readOnly?: boolean };
}) {
  const url = bundleUrl(model);
  const frame = useRef<HTMLIFrameElement>(null);
  const origin = url?.origin;
  const [height, setHeight] = useState(576);
  const managed =
    origin !== window.location.origin &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
      model.bundle?.buildId ?? '',
    );
  const src = managed
    ? `/interactives/runtime/${encodeURIComponent(model.bundle!.buildId)}`
    : url?.href;
  const previewIds = JSON.stringify(
    preview?.partIds ??
      (delivery?.mode === 'author_preview' || delivery?.mode === 'preview'
        ? delivery.state.parts.map((part) => String(part.partId))
        : null),
  );
  const previewReadOnly = preview?.readOnly ?? false;
  const previewSession = useMemo(
    () =>
      previewIds !== 'null'
        ? createPreviewSession(JSON.parse(previewIds), previewReadOnly)
        : undefined,
    [previewIds, previewReadOnly, model.bundle?.indexUrl, delivery?.state.attemptGuid],
  );
  const execute = useMemo(
    () => previewSession ?? (delivery ? createDeliveryHandler(delivery) : undefined),
    [previewSession, delivery],
  );
  const executeRef = useRef(execute);
  executeRef.current = execute;
  useLayoutEffect(() => {
    setHeight(576);
    if (frame.current && origin) {
      return attachInteractiveBridge(
        frame.current,
        origin,
        (request) =>
          executeRef.current
            ? executeRef.current(request)
            : Promise.reject(new Error('unavailable')),
        setHeight,
      );
    }
  }, [origin, model.bundle?.indexUrl, delivery?.state.attemptGuid]);
  if (!url) {
    return <p role="status">This interactive is not available yet.</p>;
  }

  // Keep the media origin for module scripts/fetches, but never combine both permissions
  // for same-origin content, which could otherwise remove its own sandbox.
  const sandbox =
    url.origin === window.location.origin ? 'allow-scripts' : 'allow-scripts allow-same-origin';

  return (
    <iframe
      ref={frame}
      key={`${url.href}:${delivery?.state.attemptGuid ?? ''}`}
      title="Interactive learning experience"
      src={src}
      sandbox={sandbox}
      referrerPolicy="no-referrer"
      height={height}
      onLoad={() =>
        frame.current?.contentWindow?.postMessage(
          { channel: 'torus.interactive.v1', type: 'measure' },
          origin === window.location.origin ? '*' : origin!,
        )
      }
      className="block w-full border-0"
    />
  );
}

export class InteractiveDelivery extends DeliveryElement<InteractiveModelSchema> {
  static get observedAttributes() {
    return [...super.observedAttributes, 'context', 'mode'];
  }

  disconnectedCallback() {
    this.connected = false;
    ReactDOM.unmountComponentAtNode(this.mountPoint);
  }

  render(mountPoint: HTMLDivElement, props: DeliveryElementProps<InteractiveModelSchema>) {
    ReactDOM.render(<InteractiveExperience model={props.model} delivery={props} />, mountPoint);
  }
}

window.customElements.define(manifest.delivery.element, InteractiveDelivery);
