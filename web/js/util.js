
function get_last_update(which, func) {
    var request = new XMLHttpRequest();
    if (!request) {
        return;
    }

    var id = which;
    request.onreadystatechange = function() {
        if (request.readyState === XMLHttpRequest.DONE && request.status === 200) {
            func(id, request.responseText);
        }
    };

    if (which === 'good') {
        which = 'download';
    }

    request.open('GET', '/' + which + '/last-update');
    request.send();
}

function update_element_text(which, text) {
    document.getElementById('tstamp-' + which).innerText = text;
}

