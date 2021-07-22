/* eslint-disable react/prop-types */
import React, { useCallback, useEffect, useState } from 'react';
import { fabric } from 'fabric';

const FabricCanvas: React.FC<any> = (props) => {
  const { width = 1000, height = 500 } = props;
  const [canvas, setCanvas] = useState<any>(null);
  const canvasRef = useCallback((el) => {
    if (el !== null) {
      const fc = new fabric.Canvas(el);
      setCanvas(fc);
    }
  }, []);

  const renderObjects = useCallback(
    async (items) => {
      const groupObjects = items.map((item: any) => {
        const promise = new Promise((resolve, reject) => {
          const { x, y, z, width: w = 100, height: h = 50 } = item.custom;

          const groupConfig = {
            top: y,
            left: x,
            width: w,
            height: h,
            zIndex: z,
          };

          const idLabel = new fabric.Text(item.id, {
            top: 2,
            left: 2,
            fontSize: 16,
          });
          const typeLabel = new fabric.Text(item.type, {
            top: 16,
            left: 2,
            fontSize: 16,
            fill: 'magenta',
          });
          if (item.type === 'janus-image') {
            fabric.Image.fromURL(item.custom.src, (img: any) => {
              img.set({ top: 0, left: 0, width: w, height: h });
              const groupObj = new fabric.Group([img, idLabel, typeLabel], groupConfig);
              groupObj.on('mousedown', (e: any) => {
                props.onObjectClicked(e, item);
              });
              resolve(groupObj);
            });
          } else {
            const rect = new fabric.Rect({
              top: 0,
              left: 0,
              width: w,
              height: h,
              fill: 'grey',
            });
            const groupObj = new fabric.Group([rect, idLabel, typeLabel], groupConfig);
            groupObj.on('mousedown', (e: any) => {
              props.onObjectClicked(e, item);
            });
            resolve(groupObj);
          }
        });
        return promise;
      });
      const objs = await Promise.all(groupObjects);
      canvas.add(...objs);
    },
    [props.items],
  );

  useEffect(() => {
    if (!canvas || !props.items || !props.items.length) {
      return;
    }

    canvas.clear().renderAll();
    renderObjects(props.items);
  }, [canvas, props.items]);

  return (
    <div className="aa-canvas-inner">
      <canvas ref={canvasRef} width={width} height={height}></canvas>
    </div>
  );
};

export default FabricCanvas;
