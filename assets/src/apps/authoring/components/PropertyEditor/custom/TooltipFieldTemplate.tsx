import React, { useEffect, useRef } from 'react';
import { Form } from 'react-bootstrap';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
import ReactDOM from 'react-dom';
import { FieldTemplateProps } from '@rjsf/core';

const TooltipFieldTemplate: React.FC<FieldTemplateProps> = (props) => {
  const iconContainerRef = useRef<HTMLSpanElement | null>(null);
  const containerRef = useRef<HTMLDivElement | null>(null);
  const tooltipText = props.uiSchema?.['ui:tooltip'] as string | undefined;

  // Debug: Log every render to verify component is being called
  console.log('TooltipFieldTemplate render:', {
    id: props.id,
    label: props.label,
    hasTooltip: !!tooltipText,
    tooltipText,
    uiSchema: props.uiSchema,
  });

  useEffect(() => {
    if (!tooltipText) {
      return;
    }

    console.log('TooltipFieldTemplate: Attempting to inject icon for', props.id);

    // Use multiple attempts with increasing delays to find the label
    let attemptCount = 0;
    const maxAttempts = 20;

    const tryInjectIcon = () => {
      attemptCount++;

      // Find the container element - try multiple ways
      const container =
        containerRef.current ||
        document.getElementById(props.id) ||
        document.querySelector(`[id="${props.id}"]`) ||
        document.querySelector(`#${props.id}`);

      if (!container) {
        if (attemptCount < maxAttempts) {
          setTimeout(tryInjectIcon, 100);
        } else {
          console.log(
            'TooltipFieldTemplate: Container not found after',
            maxAttempts,
            'attempts for',
            props.id,
          );
        }
        return;
      }

      // Find the label element - try multiple selectors and search more broadly
      let label = container.querySelector('label.form-label');
      if (!label) {
        label = container.querySelector('label');
      }
      if (!label) {
        label = container.querySelector('.form-label');
      }
      // Also try searching in parent elements
      if (!label && container.parentElement) {
        label =
          container.parentElement.querySelector('label.form-label') ||
          container.parentElement.querySelector('label');
      }

      if (!label) {
        if (attemptCount < maxAttempts) {
          setTimeout(tryInjectIcon, 100);
        } else {
          console.log(
            'TooltipFieldTemplate: Label not found after',
            maxAttempts,
            'attempts for',
            props.id,
            'container HTML:',
            container.outerHTML.substring(0, 200),
          );
        }
        return;
      }

      // Check if icon already exists
      if (label.querySelector('.tooltip-icon-container') || iconContainerRef.current) {
        return;
      }

      console.log('TooltipFieldTemplate: Found label, injecting icon for', props.id);

      // Create container for the icon
      const iconContainer = document.createElement('span');
      iconContainer.className = 'tooltip-icon-container';
      iconContainer.style.marginLeft = '0px';
      iconContainer.style.display = 'inline-block';
      iconContainer.style.verticalAlign = 'top';

      // Insert icon container after the label text
      label.appendChild(iconContainer);
      iconContainerRef.current = iconContainer;

      // Render tooltip icon using ReactDOM.render (React 17 compatible)
      ReactDOM.render(
        <OverlayTrigger
          placement="top"
          delay={{ show: 150, hide: 150 }}
          overlay={
            <Tooltip id={`tooltip-${props.id}`} style={{ fontSize: '12px', maxWidth: '300px' }}>
              {tooltipText}
            </Tooltip>
          }
        >
          <i className="fa fa-info-circle tooltip-info-icon" aria-label="More information" />
        </OverlayTrigger>,
        iconContainer,
      );
    };

    // Start with a small delay, then retry
    const timeoutId = setTimeout(tryInjectIcon, 100);

    // Cleanup function
    return () => {
      clearTimeout(timeoutId);
      if (iconContainerRef.current) {
        ReactDOM.unmountComponentAtNode(iconContainerRef.current);
        if (iconContainerRef.current.parentNode) {
          iconContainerRef.current.parentNode.removeChild(iconContainerRef.current);
        }
        iconContainerRef.current = null;
      }
    };
  }, [tooltipText, props.id]);

  // Render the field using Form.Group structure like RJSF Bootstrap-4 does
  if (props.hidden) {
    return <></>;
  }

  // If we have a tooltip, we need to modify the children to inject the icon
  // RJSF Bootstrap-4 renders the label inside children, so we need to intercept it
  const childrenWithTooltip = tooltipText ? (
    <div ref={containerRef} id={props.id}>
      {props.children}
    </div>
  ) : (
    props.children
  );

  return (
    <Form.Group className="mb-0" ref={containerRef} id={props.id}>
      {childrenWithTooltip}
      {props.rawHelp && props.rawErrors?.length < 1 && (
        <Form.Text
          className={props.rawErrors?.length > 0 ? 'text-danger' : 'text-muted'}
          id={props.id}
        >
          {props.rawHelp}
        </Form.Text>
      )}
    </Form.Group>
  );
};

export default TooltipFieldTemplate;
