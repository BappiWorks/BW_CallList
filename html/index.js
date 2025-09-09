// Modernized UI logic while keeping existing NUI features
// Original: OMikkel#3217 (BW_CallList) — Updated styling + true refresh-in-place via rowId

$(document).ready(function () {
  const table = $('#callist').DataTable({
    processing: true,
    paging: false,
    info: false,
    searching: true,
    deferRender: true,
    scrollX: '56vh',
    language: {
      search: 'Søg opkald:',
      zeroRecords: "<span style='color: #9aa3b2;'>Ingen resultater fundet for din søgning.</span>",
      emptyTable: "<span style='color: #9aa3b2;'>Der er ingen aktive opkald.</span>"
    },
    // IMPORTANT: use object data + rowId so we can upsert reliably
    rowId: 'id',
    columns: [
      { data: 'date',   className: 'dateCol',  width: '15%' },
      { data: 'msg',    className: 'msgCol',   width: '40%' },
      { data: 'from',   className: 'fromCol',  width: '12%' },
      { data: 'locBtn', className: 'locCol',   width: '13%' },
      { data: 'takeBtn',className: 'answerCol',width: '13%' },
      { data: 'delBtn', className: 'delCol',   width: '7%'  }
    ],
    order: [[0, 'desc']],
    createdRow: function(row){
      $(row).find('td').css('white-space','nowrap');
    }
  });

  // Tweak wrapper look + search placeholder
  $(".dataTables_wrapper.no-footer .dataTables_scrollBody").css("border-bottom", "0");
  $('.dataTables_scrollBody').addClass('dt-scrollbar');
  $('.dataTables_filter input').attr('placeholder', 'Skriv her for at søge...');

  // --- Status time updater (Apple vibe) ---
  function pad(n){ return String(n).padStart(2, '0'); }
  function updateStatusTime(){
    const d = new Date();
    const t = pad(d.getHours()) + ':' + pad(d.getMinutes());
    $('#statusTime').text(t);
  }
  updateStatusTime();
  setInterval(updateStatusTime, 30 * 1000);

  // --- Sound toggle state ---
  let soundEnabled = localStorage.getItem('BW_SoundEnabled') !== 'false';
  function updateSoundButton(){
    const icon = $('#toggleSoundBtn i');
    if (soundEnabled) icon.removeClass('fa-bell-slash').addClass('fa-bell');
    else icon.removeClass('fa-bell').addClass('fa-bell-slash');
  }
  $('#toggleSoundBtn').on('click', function(){
    soundEnabled = !soundEnabled;
    localStorage.setItem('BW_SoundEnabled', soundEnabled);
    updateSoundButton();
  });
  updateSoundButton();

  // Coords store (separate from table data)
  const coordsTable = {};
  let userInitiatedClose = false;

  // Helpers
  function makeRowData({ id, date, message, number, taken }) {
    const takeBtn = (taken === 'none')
      ? `<button class="takeButton" name="${id}">Tag Opkald</button>`
      : `<button class="takenButton" name="${id}" disabled>${taken}</button>`;
    return {
      id,
      date,
      msg: message,
      from: number,
      locBtn:  `<button class="locButton" name="${id}">Sæt GPS</button>`,
      takeBtn: takeBtn,
      delBtn:  `<button class="delButton" name="${id}">Slet</button>`
    };
  }

  function upsertRow(obj) {
    const selector = '#' + obj.id; // because rowId:'id' sets <tr id="ID">
    if (table.row(selector).any()) {
      table.row(selector).data(obj).draw(false);
    } else {
      table.row.add(obj).draw(false);
    }
  }

  function markTaken(id, takenBy) {
    const selector = '#' + id;
    if (!table.row(selector).any()) return;
    const data = table.row(selector).data();
    data.takeBtn = `<button class="takenButton" name="${id}" disabled>${takenBy || 'Taget'}</button>`;
    table.row(selector).data(data).draw(false);
  }

  function removeRow(id) {
    const selector = '#' + id;
    if (table.row(selector).any()) {
      table.row(selector).remove().draw(false);
    }
    delete coordsTable[id];
  }

  // --- NUI message listeners ---
  window.addEventListener('message', function (event) {
    const item = event.data;
    if (item?.status === 'playSound' && soundEnabled) {
      const audio = document.getElementById('audio_new');
      audio.load();
      audio.volume = item.volume;
      audio.play();
    }
  });

  window.addEventListener('message', function (event) {
    const data = event.data;
    if (!data || !data.status) return;

    if (data.status === 'showCalls') {
      OpenMain();
      table.clear().draw(false);
      for (const k in coordsTable) delete coordsTable[k];
    }

    if (data.status === 'addRows') {
      const { id, date, message, number, coords, service, taken, job } = data;
      if (job === service) {
        coordsTable[id] = coords;
        upsertRow(makeRowData({ id, date, message, number, taken }));
      }
    }

    // Optional bulk set
    if (data.status === 'setRows' && Array.isArray(data.rows)) {
      table.clear();
      for (const r of data.rows) {
        const { id, date, message, number, coords, taken } = r;
        coordsTable[id] = coords;
        table.row.add(makeRowData({ id, date, message, number, taken }));
      }
      table.draw(false);
    }

    // Optional fine-grained updates
    if (data.status === 'removeRow') removeRow(data.id);
    if (data.status === 'markTaken') markTaken(data.id, data.taken);

    // Keep UI open on hideCalls unless explicitly closed by user
    if (data.status === 'hideCalls') {
      if (userInitiatedClose) {
        CloseMain();
        userInitiatedClose = false;
      } else {
        table.draw(false); // soft refresh
      }
    }
  });

  // Button actions — optimistic UI
  $('.app-content').on('click', '.takeButton', function () {
    const id = $(this).attr('name');
    markTaken(id, 'Taget');
    $.post('http://BW_CallList/takeCall', JSON.stringify({
      id,
      coords: coordsTable[id]
    }));
  });

  $('.app-content').on('click', '.locButton', function () {
    const id = $(this).attr('name');
    $.post('http://BW_CallList/setCall', JSON.stringify({
      id,
      coords: coordsTable[id]
    }));
  });

  $('.app-content').on('click', '.delButton', function () {
    const id = $(this).attr('name');
    removeRow(id);
    $.post('http://BW_CallList/deleteCall', JSON.stringify({
      id,
      coords: coordsTable[id]
    }));
  });

  $('#headerClose').on('click', function () {
    userInitiatedClose = true;
    CloseMain();
    $.post('http://BW_CallList/closeCalls', JSON.stringify({}));
  });
});

// ESC closes
document.onkeyup = function (e) {
  if (e.which === 27) {
    window.userInitiatedClose = true;
    CloseMain();
    $.post('http://BW_CallList/closeCalls', JSON.stringify({}));
  }
};

// Show/Hide root
function OpenMain() {
  document.body.classList.add('show');
  const table = $('#callist').DataTable();
  table.columns.adjust().draw(false);
  $('#app-root').css('display','grid');
}
function CloseMain() {
  document.body.classList.remove('show');
  $('#app-root').css('display','none');
}

// Utility date (kept)
function dateNow(seconds) {
  var d = new Date($.now());
  var day = (d.getDate()).toString();
  var month = ((d.getMonth() + 1)).toString();
  var year = (d.getFullYear()).toString();
  var hours = (d.getHours()).toString();
  var minutes = (d.getMinutes()).toString();
  var secs = (d.getSeconds()).toString();
  if (day.length === 1) { day = '0' + day; }
  if (month.length === 1) { month = '0' + month; }
  if (hours.length === 1) { hours = '0' + hours; }
  if (minutes.length === 1) { minutes = '0' + minutes; }
  if (secs.length === 1) { secs = '0' + secs; }
  if (seconds === true) {
    return day + '/' + month + '/' + year + ' ' + hours + ':' + minutes + ':' + secs;
  } else {
    return day + '/' + month + '/' + year + ' ' + hours + ':' + minutes;
  }
}






















































































































































