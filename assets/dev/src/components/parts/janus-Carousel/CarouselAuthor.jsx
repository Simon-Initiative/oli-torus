import React, { useEffect } from 'react';
import { Swiper, SwiperSlide } from 'swiper/react';
const CarouselAuthor = (props) => {
    const { model } = props;
    const { z = 0, width, height, fontSize = 16, images } = model;
    const styles = {
        fontSize: `${fontSize}px`,
        zIndex: z,
        overflow: 'hidden',
        display: 'flex',
    };
    const imgStyles = {
        maxWidth: `calc(${width}px - ${64}px)`,
        maxHeight: `calc(${height}px - ${32}px)`,
    };
    useEffect(() => {
        // all activities *must* emit onReady
        props.onReady({
            id: `${props.id}
    `,
        });
    }, []);
    return (<div data-janus-type={tagName} className={`janus-image-carousel`} style={styles}>
      {images.length > 0 && (<Swiper loop navigation slidesPerView={1} zoom={{ maxRatio: 3 }} keyboard={{ enabled: true }} pagination={{ clickable: true }} enabled={false}>
          {images.map((image, index) => (<SwiperSlide key={index} zoom={true}>
              <figure className="swiper-zoom-container">
                <img style={imgStyles} src={image.url} alt={image.alt ? image.alt : undefined}/>
                <figcaption>{image.caption}</figcaption>
              </figure>
            </SwiperSlide>))}
        </Swiper>)}
      {images.length <= 0 && <div className="no-images">No images to display</div>}
    </div>);
};
export const tagName = 'janus-image-carousel';
export default CarouselAuthor;
//# sourceMappingURL=CarouselAuthor.jsx.map