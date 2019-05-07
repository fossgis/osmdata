
function get_file_change_date(file) {
    var request = new XMLHttpRequest();
    if (!request) {
        return;
    }

    request.onreadystatechange = function() {
        if (request.readyState === XMLHttpRequest.DONE && request.status === 200) {
            var date = new Date(request.getResponseHeader('Last-Modified'));
            var text = date.toISOString().split(':').slice(0, 2).join(':');
            document.getElementById('last-change-' + file).innerText = 'Last update: ' + text;
        }
    };

    request.open('HEAD', '/download/' + file);
    request.send();
}

