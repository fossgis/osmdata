
var map;

function open_layer(name) {
    return new ol.layer.Tile({
        source: new ol.source.XYZ({
            url: '/d/coastline/' + name + '/{z}/{x}/{-y}.png',
            minZoom: 1,
            maxZoom: 6,
            attributions: 'Data by <a href="https://openstreetmap.org/">OpenStreetMap</a>, under <a href="https://www.openstreetmap.org/copyright">ODbL</a>.',
            wrapX: false
        }),
        type: 'base',
        title: name
    });
}

var layers = {
    'good': open_layer('good'),
    'new':  open_layer('new'),
    'diff': open_layer('diff')
};

function update_opacity(name, value) {
    layers[name].setOpacity(parseInt(value));
}

document.addEventListener('DOMContentLoaded', function() {
    get_last_update('good', update_element_text);
    get_last_update('new', update_element_text);

    map = new ol.Map({
        layers: [layers['good'], layers['new'], layers['diff']],
        target: 'map',
        controls: [new ol.control.Zoom, new ol.control.Attribution],
        view: new ol.View({
            center: ol.proj.transform([0.0, 20.0], 'EPSG:4326', 'EPSG:3857'),
            zoom: 2,
            minZoom: 1,
            maxZoom: 6
        })
    });

    var mouseposition = new ol.control.MousePosition({
        coordinateFormat: ol.coordinate.createStringXY(4),
        projection: 'EPSG:4326',
        undefinedHTML: ' ',
        targetx: 'position'
    });
    map.addControl(mouseposition);

    update_opacity('good', document.getElementById('slide-good').value);
    update_opacity('new', document.getElementById('slide-new').value);
    update_opacity('diff', document.getElementById('slide-diff').value);
});

