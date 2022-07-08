import React, { useEffect, useState } from 'react';
import { CustomDnDSchema } from './schema';
import guid from 'utils/guid';

export type ResetListener = () => void;

export type DragCanvasProps = {
  model: CustomDnDSchema;
  onSubmitPart: (partId: string, value: string) => void;
  onFocusChange: (partId: string) => void;
  initialState: Record<string, string>;
  editMode: boolean;
  activityAttemptGuid: string;
  onRegisterResetCallback: (listener: ResetListener) => void;
};

export const DragCanvas: React.FC<DragCanvasProps> = (props: DragCanvasProps) => {
  const [id] = useState(guid());

  useEffect(() => {
    renderRawContent(id, props);
  }, []);

  useEffect(() => {
    updateDropHandler(id, props);
  }, [props.activityAttemptGuid]);

  useEffect(() => {
    setEditMode(props.editMode, id);
  }, [props.editMode]);

  return (
    <div style={{ height: props.model.height, width: props.model.width }} id={id}>
      {id}
    </div>
  );
};

function resetAnyChildren(container: any, element: any) {
  while (element.childNodes.length > 0) {
    container.appendChild(element.childNodes[0]);
  }
}

function getTarget(shadowRoot: any, inputVal: string) {
  let item = null;
  shadowRoot.querySelectorAll('.target').forEach((element: any) => {
    if (element.getAttribute('input_ref') === inputVal) {
      item = element;
    }
  });

  return item;
}

function getDroppable(shadowRoot: any, inputVal: string) {
  let item = null;
  shadowRoot.querySelectorAll('.initiator').forEach((element: any) => {
    if (element.getAttribute('input_val') === inputVal) {
      item = element;
    }
  });

  return item;
}

function changeFocus(shadowRoot: any, partId: string, props: DragCanvasProps) {
  shadowRoot.querySelectorAll('.target').forEach((element: any) => {
    element.style['border-width'] = '1px';
  });
  const target = getTarget(shadowRoot, partId);
  if (target !== null) {
    (target as any).style['border-width'] = '3px';
  }
  props.onFocusChange(partId);
}

function createTargetDropHandler(shadowRoot: any, props: DragCanvasProps) {
  return (ev: DragEvent) => {
    if (ev !== null && (ev.currentTarget as any).classList.contains('target')) {
      (ev as any).dataTransfer.dropEffect = 'move';

      const inputVal = (ev as any).dataTransfer.getData('text/plain');
      resetAnyChildren(shadowRoot.querySelector('.input_source'), ev.currentTarget);

      const droppable = getDroppable(shadowRoot, inputVal);
      (ev.currentTarget as any).appendChild(droppable);
      const newlyDropped = (ev.currentTarget as any).children[0];
      newlyDropped.style.left = '0px';
      newlyDropped.style.top = '0px';
      newlyDropped.style.position = 'relative';

      const partId = (ev.currentTarget as any).getAttribute('input_ref');
      changeFocus(shadowRoot, partId, props);
      props.onSubmitPart(partId, inputVal);

      ev.stopPropagation();
    }
  };
}

function updateDropHandler(id: string, props: DragCanvasProps) {
  const shadowRoot = (document.getElementById(id) as any).shadowRoot;

  const targetDropHandler = createTargetDropHandler(shadowRoot, props);

  shadowRoot.querySelectorAll('.target').forEach((element: any) => {
    element.removeEventListener('drop', element.lastHandler);
    element.addEventListener('drop', targetDropHandler);
    element.lastHandler = targetDropHandler;
  });
}

function setEditMode(editMode: boolean, id: string) {
  const shadowRoot = (document.getElementById(id) as any).shadowRoot;
  shadowRoot.querySelectorAll('.initiator').forEach((element: any) => {
    element.draggable = editMode;
  });
}

function renderRawContent(id: string, props: DragCanvasProps) {
  const { model } = props;

  const shadow = (document.getElementById(id) as any).attachShadow({ mode: 'open' });
  const shadowRoot = (document.getElementById(id) as any).shadowRoot;
  const style = document.createElement('style');
  style.textContent = model.layoutStyles;

  const targetWrapper = document.createElement('div');
  targetWrapper.className = 'component';
  targetWrapper.innerHTML = model.targetArea;

  const initiatorsWrapper = document.createElement('div');
  initiatorsWrapper.className = 'input_source';
  initiatorsWrapper.innerHTML = model.initiators;

  shadow.appendChild(style);
  shadow.appendChild(targetWrapper);
  shadow.appendChild(initiatorsWrapper);

  const targetClickHandler = (ev: any) => {
    if (ev.currentTarget.getAttribute('input_ref')) {
      changeFocus(shadowRoot, ev.currentTarget.getAttribute('input_ref'), props);
    }
  };

  const dragStartHandler = (ev: DragEvent) => {
    if (ev !== null) {
      const inputVal = (ev as any).target.getAttribute('input_val');
      (ev as any).dataTransfer.setData('text/plain', inputVal);
      (ev as any).dataTransfer.dropEffect = 'move';
    }
  };

  const dragEndHandler = (ev: DragEvent) => {
    if (ev !== null) {
      (ev as any).dataTransfer.setData('text/plain', (ev as any).target.input_val);
      (ev as any).dataTransfer.dropEffect = 'move';
    }
  };

  const rootDropHandler = (ev: DragEvent) => {
    if (ev !== null) {
      const inputVal = (ev as any).dataTransfer.getData('text/plain');
      shadowRoot.querySelectorAll('.initiator').forEach((element: HTMLElement) => {
        if (element.getAttribute('input_val') === inputVal) {
          if (element.parentElement?.classList.contains('target')) {
            initiatorsWrapper.appendChild(element);
          }
        }
      });
    }
  };

  const dragOverHandler = (ev: DragEvent) => {
    if (ev !== null) {
      ev.preventDefault();
      (ev as any).dataTransfer.dropEffect = 'move';
    }
  };

  // Set the initial state, thus restoring the state of a partially (or entirely) completed attempt
  let firstRestoredPart: string | null = null;
  shadowRoot.querySelectorAll('.target').forEach((element: any) => {
    const partId = element.getAttribute('input_ref');
    if (props.initialState[partId] !== undefined) {
      const droppable = getDroppable(shadowRoot, props.initialState[partId]);

      element.appendChild(droppable);
      if (firstRestoredPart === null) {
        firstRestoredPart = partId;
      }
    }
  });

  // If we restored state to at least one part, set the focus to the first part that
  // we restored state to.  This allows that parts feedback to be initially displayed as well
  if (firstRestoredPart !== null) {
    changeFocus(shadowRoot, firstRestoredPart, props);
  }

  shadowRoot.querySelectorAll('.initiator').forEach((element: any) => {
    element.posx = element.style.top;
    element.posy = element.style.left;

    element.draggable = props.editMode;
    element.addEventListener('dragstart', dragStartHandler);
    element.addEventListener('dragend', dragEndHandler);
  });

  const targetDropHandler = createTargetDropHandler(shadowRoot, props);
  shadowRoot.querySelectorAll('.target').forEach((element: any) => {
    element.addEventListener('drop', targetDropHandler);
    element.lastHandler = targetDropHandler;
    element.addEventListener('dragover', dragOverHandler);
    element.addEventListener('click', targetClickHandler);
  });

  shadow.addEventListener('drop', rootDropHandler);

  props.onRegisterResetCallback(() => {
    shadowRoot.querySelectorAll('.target').forEach((element: any) => {
      resetAnyChildren(shadowRoot, element);
    });
  });

  return shadow;
}
