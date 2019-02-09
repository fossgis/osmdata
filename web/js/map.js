
function open_layer(name) {
    return new ol.layer.Tile({
        source: new ol.source.XYZ({
            url: '/d/coastline/' + name + '/{z}/{x}/{-y}.png',
            minZoom: 1,
            maxZoom: 5,
            attributions: 'Data by <a href="https://openstreetmap.org/">OpenStreetMap</a>, under <a href="https://www.openstreetmap.org/copyright">ODbL</a>.',
            wrapX: false
        }),
        type: 'base',
        title: name,
        opacity: 0.5
    });
}

var layers = {
    'master':  open_layer('master'),
    'current': open_layer('current'),
    'diff':    open_layer('diff')
};

function update_opacity(name, value) {
    layers[name].setOpacity(value);
}

document.addEventListener('DOMContentLoaded', function() {
    map = new ol.Map({
        layers: [layers['master'], layers['current'], layers['diff']],
        target: 'map',
        controls: [new ol.control.Zoom, new ol.control.Attribution],
        view: new ol.View({
            center: ol.proj.transform([0.0, 20.0], 'EPSG:4326', 'EPSG:3857'),
            zoom: 2,
            minZoom: 1,
            maxZoom: 5
        })
    });

    var mouseposition = new ol.control.MousePosition({
        coordinateFormat: ol.coordinate.createStringXY(4),
        projection: 'EPSG:4326',
        undefinedHTML: ' ',
        targetx: 'position'
    });
    map.addControl(mouseposition);

    update_opacity('master', document.getElementById('slide-master').value);
    update_opacity('current', document.getElementById('slide-current').value);
    update_opacity('diff', document.getElementById('slide-diff').value);
});

