import OpenSeadragon from "openseadragon";

let initViewer = () => {
    window.viewer = window.viewer || OpenSeadragon({
        id: "openseadragon-viewer",
        prefixUrl: "/images/openseadragon/",
        showNavigator: true,
        maxZoomPixelRatio: 2,
        zoomInButton: "zoom-in",
        zoomOutButton: "zoom-out",
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
    });
};

let Lightbox = {
    mounted() {
        initViewer();
        setBindings();
        handleNewImage(this);
    },
    destroyed() {
        window.viewer.destroy();
        window.viewer = null;
        console.log('destroyed');
    }
}

export { Lightbox }
