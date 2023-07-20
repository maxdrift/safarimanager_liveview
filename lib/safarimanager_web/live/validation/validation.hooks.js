import OpenSeadragon from "openseadragon";

let initViewer = () => {
    window.viewer = window.viewer || OpenSeadragon({
        id: "openseadragon-viewer",
        prefixUrl: "/images/openseadragon/",
        showNavigator: true,
        maxZoomPixelRatio: 2,
        zoomInButton: "zoom-in",
        zoomOutButton: "zoom-out",
        showRotationControl: true,
        rotateLeftButton: "rotate-left",
        rotateRightButton: "rotate-right",
        gestureSettingsTouch: {
            pinchRotate: true
        },
        homeButton: "home",
        fullPageButton: "full-page",
        sequenceMode: false,
        showSequenceControl: false,
        pixelsPerArrowPress: 0,
        navigatorSizeRatio: 0.1,
        debugMode: false,
    });
};

let setBindings = () => {
    document.getElementById("zoom-100").onclick = function () {
        var tiledImage = viewer.world.getItemAt(0); // Assuming we just have a single image in the viewer
        var targetZoom = tiledImage.source.dimensions.x / viewer.viewport.getContainerSize().x;
        viewer.viewport.zoomTo(targetZoom, null, false);
    };

    window.addEventListener("OpenSeadragon.Viewer.html#.event:open", event => {
        console.log('event', event);
    });
};

let handleNewImage = (context) => {
    context.handleEvent("new-image", ({ options: { image_url } }) => {
        window.viewer.open({
            type: 'image',
            url: image_url,
            buildPyramid: false
        });
        // Reset rotation
        window.viewer.viewport.rotateTo(0, null, true);
    });
};

let Lightbox = {
    mounted() {
        console.log('mounted');
        initViewer();
        setBindings();
        handleNewImage(this);
    },
    beforeUpdate() {
        console.log('beforeUpdate');
    },
    updated() {
        console.log('updated');
    },
    destroyed() {
        window.viewer.destroy();
        window.viewer = null;
        console.log('destroyed');
    },
    disconnected() { console.log('disconnected'); },
    reconnected() { console.log('reconnected'); }
}

export { Lightbox }
