import React, { useEffect, useState } from 'react';
import { CustomDnDSchema } from './schema';
import guid from 'utils/guid';

export type ResetListener = () => void;

export type DragCanvasProps = {
  model: CustomDnDSchema;
  onSubmitPart: (targetId: string, draggableId: string) => void;
  onFocusChange: (targetId: string, draggableId: string | null) => void;
  onDetach: (targetId: string, draggableId: string) => void;
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

  // When the current activity attempt guid changes, the user has initiated a "reset" to
  // get another attempt.  We must reset the drop handlers on all drop targets so that
  // these functions close over the most up to date 'onSubmitPart` handler, which allows
  // the parent CustomDnDDelivery component to issue part submissions with the correct
  // part attempt guids.
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

function resetChildDraggables(shadowRoot: any, target: any, props: DragCanvasProps | null) {
  const inputRoot = shadowRoot.querySelector('.input_source');
  target.querySelectorAll('.initiator').forEach((draggable: any) => {
    inputRoot.appendChild(draggable);
    // notify parent. allow null props to suppress notification, as during reset callback
    if (props)
      props.onDetach(target.getAttribute('input_ref'), draggable.getAttribute('input_val'));
  });
}

function getTarget(shadowRoot: any, inputVal: string): HTMLElement | null {
  let item = null;
  shadowRoot.querySelectorAll('.target').forEach((element: any) => {
    if (element.getAttribute('input_ref') === inputVal) {
      item = element;
    }
  });

  return item;
}

function getDraggable(shadowRoot: any, inputVal: string): HTMLElement | null {
  let item = null;
  shadowRoot.querySelectorAll('.initiator').forEach((element: any) => {
    if (element.getAttribute('input_val') === inputVal) {
      item = element;
    }
  });

  return item;
}

function getParentTargetId(draggable: HTMLElement | null): string | null {
  const parentId = draggable?.parentElement?.getAttribute('input_ref');
  return parentId || null;
}

function changeFocus(shadowRoot: any, targetId: string, props: DragCanvasProps) {
  shadowRoot.querySelectorAll('.target').forEach((element: any) => {
    element.style['border-width'] = '1px';
  });
  const target = getTarget(shadowRoot, targetId);
  if (target !== null) {
    (target as any).style['border-width'] = '3px';
  }
  // notification should also include contained draggable, null if none
  const draggableId = target?.querySelector('.initiator')?.getAttribute('input_val');
  props.onFocusChange(targetId, draggableId || null);
}

function createTargetDropHandler(shadowRoot: any, props: DragCanvasProps) {
  return (ev: DragEvent) => {
    if (ev !== null && (ev.currentTarget as any).classList.contains('target')) {
      ev.preventDefault();
      ev.stopPropagation();

      (ev as any).dataTransfer.dropEffect = 'move';
      const inputVal = (ev as any).dataTransfer.getData('text/plain');

      // bump any existing draggable out of target
      resetChildDraggables(shadowRoot, ev.currentTarget, props);

      const draggable = getDraggable(shadowRoot, inputVal);
      //  notify if draggable to be dropped is detaching from another target
      const prevTargetId = getParentTargetId(draggable);
      if (prevTargetId) props.onDetach(prevTargetId, inputVal);

      (ev.currentTarget as any).appendChild(draggable);
      const newlyDropped = (ev.currentTarget as any).children[0];
      newlyDropped.style.left = '0px';
      newlyDropped.style.top = '0px';
      newlyDropped.style.position = 'relative';

      const targetId = (ev.currentTarget as any).getAttribute('input_ref');
      changeFocus(shadowRoot, targetId, props);
      props.onSubmitPart(targetId, inputVal);
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
          const parentTargetId = getParentTargetId(element);
          if (parentTargetId) {
            props.onDetach(parentTargetId, inputVal);
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
  let firstRestoredTarget: string | null = null;
  shadowRoot.querySelectorAll('.target').forEach((element: any) => {
    const targetId = element.getAttribute('input_ref');
    if (props.initialState[targetId] !== undefined) {
      const draggableId = props.initialState[targetId];
      const draggable = getDraggable(shadowRoot, draggableId);

      element.appendChild(draggable);
      if (firstRestoredTarget === null) {
        firstRestoredTarget = targetId;
      }
    }
  });

  // If we restored state to at least one target, set the focus to the first target that we
  // restored state to.  This allows associated part's feedback to be initially displayed as well
  if (firstRestoredTarget !== null) {
    changeFocus(shadowRoot, firstRestoredTarget, props);
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
      resetChildDraggables(shadowRoot, element, null);
    });
  });

  return shadow;
}
