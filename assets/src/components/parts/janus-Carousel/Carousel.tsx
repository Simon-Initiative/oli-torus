import React, { createRef, CSSProperties, useCallback, useEffect, useState } from 'react';
import SwiperCore, { A11y, Keyboard, Navigation, Pagination, Zoom } from 'swiper';
import { Swiper, SwiperSlide } from 'swiper/react';
import { CapiVariableTypes } from '../../../adaptivity/capi';
import {
  NotificationType,
  subscribeToNotification,
} from '../../../apps/delivery/components/NotificationContext';
import { PartComponentProps } from '../types/parts';
import './Carousel.css';
import { CarouselModel } from './schema';

interface CarouselImageModel {
  url: string;
  caption: string;
  alt: string;
}

const Carousel: React.FC<PartComponentProps<CarouselModel>> = (props) => {
  const [ready, setReady] = useState<boolean>(false);
  const id: string = props.id;
  const [images, setImages] = useState<CarouselImageModel[]>(props.model.images || []);
  const [imagesLoaded, setImagesLoaded] = useState(false);
  const [currentSlide, setCurrentSlide] = useState(0);
  const [viewedSlides, setViewedSlides] = useState<any[]>([]);
  const [captionRefs, setCaptionRefs] = useState<any[]>([]);
  const [carouselZoom, setCarouselZoom] = useState<boolean>(true);
  const [cssClass, setCssClass] = useState('');

  // initialize the swiper
  SwiperCore.use([Navigation, Pagination, A11y, Keyboard, Zoom]);

  const initialize = useCallback(async (pModel) => {
    // set defaults
    const dZoom = typeof pModel.zoom === 'boolean' ? pModel.zoom : carouselZoom;
    setCarouselZoom(dZoom);

    const dCssClass = pModel.customCssClass || cssClass;
    setCssClass(dCssClass);

    const dImages = pModel.images || images;
    setImages(dImages);

    const initResult = await props.onInit({
      id,
      responses: [
        {
          key: 'customCssClass',
          type: CapiVariableTypes.STRING,
          value: dCssClass,
        },
        {
          key: 'zoom',
          type: CapiVariableTypes.BOOLEAN,
          value: dZoom,
        },
      ],
    });

    // result of init has a state snapshot with latest (init state applied)
    const currentStateSnapshot = initResult.snapshot;

    const sZoom = currentStateSnapshot[`stage.${id}.zoom`];
    if (sZoom !== undefined) {
      setCarouselZoom(sZoom);
    }

    const sCssClass = currentStateSnapshot[`stage.${id}.customCssClass`];
    if (sCssClass !== undefined) {
      setCssClass(sCssClass);
    }

    setReady(true);
  }, []);

  useEffect(() => {
    if (!props.notify) {
      return;
    }
    const notificationsHandled = [
      NotificationType.CHECK_STARTED,
      NotificationType.CHECK_COMPLETE,
      NotificationType.CONTEXT_CHANGED,
      NotificationType.STATE_CHANGED,
    ];
    const notifications = notificationsHandled.map((notificationType: NotificationType) => {
      const handler = (payload: any) => {
        /* console.log(`${notificationType.toString()} notification handled [Carousel]`, payload); */
        switch (notificationType) {
          case NotificationType.CHECK_STARTED:
            // nothing to do
            break;
          case NotificationType.CHECK_COMPLETE:
            // nothing to do
            break;
          case NotificationType.STATE_CHANGED:
            {
              const { mutateChanges: changes } = payload;

              const sZoom = changes[`stage.${id}.zoom`];
              if (sZoom !== undefined) {
                setCarouselZoom(sZoom);
              }
            }
            break;
          case NotificationType.CONTEXT_CHANGED:
            {
              const { initStateFacts: changes } = payload;

              const sZoom = changes[`stage.${id}.zoom`];
              if (sZoom !== undefined) {
                setCarouselZoom(sZoom);
              }
            }
            break;
        }
      };
      const unsub = subscribeToNotification(props.notify, notificationType, handler);
      return unsub;
    });
    return () => {
      notifications.forEach((unsub) => {
        unsub();
      });
    };
  }, [props.notify]);

  useEffect(() => {
    initialize(props.model);
  }, [props.model]);

  useEffect(() => {
    if (!ready) {
      return;
    }
    props.onReady({ id, responses: [] });
  }, [ready]);

  const { z = 0, width, height, fontSize = 16 } = props.model;

  const MAGIC_NUMBER = 64;
  const PAGINATION_HEIGHT = 32;

  const styles: CSSProperties = {
    fontSize: `${fontSize}px`,
    zIndex: z,
    overflow: 'hidden',
    display: 'flex',
  };

  const imgStyles: CSSProperties = {
    maxWidth: `calc(${width}px - ${MAGIC_NUMBER}px)`,
    maxHeight: imagesLoaded
      ? `calc(${height}px - ${captionRefs[currentSlide]?.current?.clientHeight}px - ${PAGINATION_HEIGHT}px)`
      : `calc(${height} - ${MAGIC_NUMBER}px)`,
  };

  useEffect(() => {
    // when images[] load, refs are set on captions in order to calc() max-height for each image later
    if (images && images.length > 0) {
      setCaptionRefs((captionRefs) =>
        Array(images.length)
          .fill(images.length)
          .map((_, i) => captionRefs[i] || createRef()),
      );
    }
  }, [images]);

  const saveState = ({ carouselZoom }: { carouselZoom: boolean }) => {
    const vars: any = [];
    const viewedImagesCount = [...new Set(viewedSlides)].length;
    const currentImage = currentSlide + 1;

    vars.push({
      key: `Current Image`,
      type: CapiVariableTypes.NUMBER,
      value: currentImage,
    });
    vars.push({
      key: `Viewed Images Count`,
      type: CapiVariableTypes.NUMBER,
      value: viewedImagesCount,
    });
    vars.push({
      key: `zoom`,
      type: CapiVariableTypes.BOOLEAN,
      value: carouselZoom,
    });
    props.onSave({
      id: `${id}`,
      responses: vars,
    });
  };

  useEffect(() => {
    saveState({
      carouselZoom,
    });
  }, [currentSlide]);

  const handleSlideChange = (currentSlide: any) => {
    setViewedSlides((viewedSlides) => [...viewedSlides, currentSlide]);
    setCurrentSlide(currentSlide);
  };

  return ready ? (
    <div data-janus-type={tagName} className={`janus-image-carousel`} style={styles}>
      {images.length > 0 && (
        <Swiper
          slidesPerView={1}
          loop
          navigation
          zoom={carouselZoom ? { maxRatio: 3 } : false}
          keyboard={{ enabled: true }}
          pagination={{ clickable: true }}
          onSwiper={(swiper) => {
            setCurrentSlide(swiper.realIndex);
          }}
          onSlideChange={(swiper) => {
            handleSlideChange(swiper.realIndex);
          }}
          onImagesReady={() => {
            setImagesLoaded(true);
          }}
        >
          {images.map((image: any, index: number) => (
            <SwiperSlide key={index} zoom={carouselZoom}>
              <figure className="swiper-zoom-container">
                <img style={imgStyles} src={image.url} alt={image.alt ? image.alt : undefined} />
                <figcaption ref={captionRefs[index]}>{image.caption}</figcaption>
              </figure>
            </SwiperSlide>
          ))}
        </Swiper>
      )}
      {images.length <= 0 && <div className="no-images">No images to display</div>}
    </div>
  ) : null;
};

export const tagName = 'janus-image-carousel';

export default Carousel;
