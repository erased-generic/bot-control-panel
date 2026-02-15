const statusCols = new Set();

function createMissingColumn(columnName) {
  const headerRow = document.getElementById('status-header');
  headerRow.insertCell().textContent = columnName;
  for (const row of document.querySelectorAll('#status-body tr')) {
    const td = row.insertCell();
    td.classList.add(`col-${columnName}`);
  }
  statusCols.add(columnName);
}

function createMissingColumns(status) {
  for (const [botName, data] of Object.entries(status)) {
    for (const key of Object.keys(data)) {
      if (!statusCols.has(key)) {
        createMissingColumn(key);
      }
    }
  }
}

function fillStatus(status) {
  createMissingColumns(status);
  for (const [botName, data] of Object.entries(status)) {
    const row = document.querySelector(`tr[data-bot="${botName}"]`);
    if (!row) {
      continue;
    }
    for (const [key, value] of Object.entries(data)) {
      const cell = row.querySelector(`.col-${key}`);
      cell.textContent = value;
    }
  }
}

function fetchWithParams(url) {
  url = new URL(url, window.location);
  url.search = window.location.search;
  return fetch(url);
}

function fetchStatus() {
  fetchWithParams(`/status`)
    .then(response => response.json())
    .then(fillStatus);
}

fetchStatus();
setInterval(fetchStatus, 5000);

function fetchLogs() {
  fetchWithParams('/logs')
    .then(response => response.json())
    .then(logs => {
      for (const [botName, botLogs] of Object.entries(logs.logs)) {
        const logBox = document.querySelector(`pre#logs[data-bot="${botName}"]`);
        if (logBox) {
          logBox.innerText = botLogs;
        }
      }
      document.getElementById('dashboard_logs').innerText = logs.dashboard_logs;
    });
}

fetchLogs();
setInterval(fetchLogs, 5000);

function refresh() {
  fetchStatus();
  fetchLogs();
}
