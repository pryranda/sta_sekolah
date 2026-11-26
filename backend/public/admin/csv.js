'use strict';

window.STA = window.STA || {};

(function (STA) {
  const { esc, toast, openModal, closeModal } = STA.ui;

  function detectDelimiter(firstLine) {
    const tabs = (firstLine.match(/\t/g) || []).length;
    const semis = (firstLine.match(/;/g) || []).length;
    const commas = (firstLine.match(/,/g) || []).length;
    if (tabs >= semis && tabs >= commas && tabs > 0) return '\t';
    if (semis > commas) return ';';
    return ',';
  }

  function parseCsvMatrix(rawText, forcedDelimiter) {
    const text = String(rawText || '').replace(/^\uFEFF/, '').replace(/\r\n/g, '\n').replace(/\r/g, '\n');
    const firstNonEmpty = text.split('\n').find((l) => l.trim().length > 0) || '';
    const delimiter = forcedDelimiter || detectDelimiter(firstNonEmpty);

    const rows = [];
    let row = [];
    let field = '';
    let inQuotes = false;

    for (let i = 0; i < text.length; i += 1) {
      const ch = text[i];
      if (inQuotes) {
        if (ch === '"') {
          if (text[i + 1] === '"') {
            field += '"';
            i += 1;
          } else {
            inQuotes = false;
          }
        } else {
          field += ch;
        }
      } else if (ch === '"') {
        inQuotes = true;
      } else if (ch === delimiter) {
        row.push(field.trim());
        field = '';
      } else if (ch === '\n') {
        row.push(field.trim());
        if (row.some((cell) => cell !== '')) rows.push(row);
        row = [];
        field = '';
      } else {
        field += ch;
      }
    }
    row.push(field.trim());
    if (row.some((cell) => cell !== '')) rows.push(row);

    return { delimiter, rows };
  }

  function normalizeHeader(h) {
    return String(h || '')
      .trim()
      .toLowerCase()
      .replace(/[^\w]+/g, '_')
      .replace(/^_+|_+$/g, '');
  }

  function parseTableToObjects(rawText, aliasMap = {}) {
    const { delimiter, rows } = parseCsvMatrix(rawText);
    if (rows.length < 2) {
      return { delimiter, headers: [], items: [], error: 'Minimal harus ada baris header dan 1 baris data.' };
    }
    const rawHeaders = rows[0];
    const headers = rawHeaders.map((h) => {
      const key = normalizeHeader(h);
      return aliasMap[key] || key;
    });

    const items = rows.slice(1).map((cols, idx) => {
      const obj = { _rowNumber: idx + 2 };
      headers.forEach((key, colIdx) => {
        if (!key) return;
        obj[key] = cols[colIdx] !== undefined ? cols[colIdx].trim() : '';
      });
      return obj;
    });

    return { delimiter, headers, items, error: null };
  }

  function csvCell(val) {
    const s = String(val ?? '');
    if (/[",\n\r;]/.test(s)) return `"${s.replace(/"/g, '""')}"`;
    return s;
  }

  function downloadCsv(filename, headers, rows) {
    const lines = [
      headers.map(csvCell).join(','),
      ...rows.map((r) => headers.map((h) => csvCell(r[h])).join(',')),
    ];
    const blob = new Blob(['\uFEFF' + lines.join('\r\n')], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    a.remove();
    URL.revokeObjectURL(url);
  }

  function openImportWizard(opts) {
    const {
      title,
      description,
      templateFilename,
      templateHeaders,
      sampleRows,
      aliasMap,
      extraControlsHtml = '',
      validateAndNormalize,
      submitRows,
      onComplete,
    } = opts;

    const wrap = document.createElement('div');
    wrap.innerHTML = `
      <div class="alert alert-info" style="margin-bottom:14px;">
        <strong>${esc(description)}</strong><br/>
        <span class="hint">Mendukung file <code>.csv</code> (koma <code>,</code> atau titik koma <code>;</code> dari Excel) maupun copy-paste langsung tabel dari Excel / Google Sheets.</span>
      </div>

      <div class="toolbar" style="margin-bottom:12px;">
        <div class="toolbar-actions">
          <button type="button" class="btn btn-soft btn-sm" id="imp-dl-tpl">Unduh Template CSV</button>
        </div>
        <span id="imp-detected" class="hint"></span>
      </div>

      <div id="imp-dropzone" class="dropzone" tabindex="0">
        <input id="imp-file" type="file" accept=".csv,.tsv,.txt" class="hidden" />
        <div style="font-weight:700;">Klik atau seret file CSV ke sini</div>
        <div class="hint" style="margin-top:4px;">Atau paste isi tabel di kolom teks di bawah ini</div>
      </div>

      <div class="form-group" style="margin-top:12px;">
        <label for="imp-raw">Data CSV / Paste dari Excel</label>
        <textarea id="imp-raw" rows="5" placeholder="Tempel baris dari Excel atau pilih file .csv..."></textarea>
      </div>

      ${extraControlsHtml ? `<div id="imp-extra" class="form-grid" style="margin-top:12px;">${extraControlsHtml}</div>` : ''}

      <div id="imp-preview-area" class="hidden" style="margin-top:14px;">
        <div class="toolbar" style="margin-bottom:8px;">
          <strong id="imp-summary-text">Preview Data</strong>
          <span class="hint">Baris berstatus error tidak akan diunggah jika Anda lanjutkan, atau perbaiki file terlebih dahulu.</span>
        </div>
        <div class="table-wrap" style="max-height:260px;">
          <table id="imp-preview-table"></table>
        </div>
      </div>

      <div id="imp-progress-wrap" class="hidden" style="margin-top:14px;">
        <div id="imp-progress-label" class="hint">Mengunggah...</div>
        <div class="progress-bar-wrap"><div id="imp-progress-bar" class="progress-bar-fill"></div></div>
      </div>

      <div id="imp-result-area" class="hidden" style="margin-top:14px;"></div>

      <div class="modal-footer">
        <button type="button" class="btn btn-outline" id="imp-cancel">Tutup</button>
        <button type="button" class="btn btn-outline" id="imp-preview-btn">Preview Data</button>
        <button type="button" class="btn btn-primary" id="imp-submit-btn" disabled>Mulai Upload</button>
      </div>
    `;

    openModal(title, wrap, { large: true });

    const fileInput = wrap.querySelector('#imp-file');
    const dropzone = wrap.querySelector('#imp-dropzone');
    const rawArea = wrap.querySelector('#imp-raw');
    const previewArea = wrap.querySelector('#imp-preview-area');
    const previewTable = wrap.querySelector('#imp-preview-table');
    const summaryText = wrap.querySelector('#imp-summary-text');
    const detectedEl = wrap.querySelector('#imp-detected');
    const submitBtn = wrap.querySelector('#imp-submit-btn');
    const progressWrap = wrap.querySelector('#imp-progress-wrap');
    const progressLabel = wrap.querySelector('#imp-progress-label');
    const progressBar = wrap.querySelector('#imp-progress-bar');
    const resultArea = wrap.querySelector('#imp-result-area');

    let validRows = [];

    wrap.querySelector('#imp-cancel').onclick = closeModal;
    wrap.querySelector('#imp-dl-tpl').onclick = () => {
      downloadCsv(templateFilename, templateHeaders, sampleRows);
      toast('Template CSV diunduh', 'success');
    };

    dropzone.onclick = () => fileInput.click();
    dropzone.ondragover = (e) => {
      e.preventDefault();
      dropzone.classList.add('dragover');
    };
    dropzone.ondragleave = () => dropzone.classList.remove('dragover');
    dropzone.ondrop = (e) => {
      e.preventDefault();
      dropzone.classList.remove('dragover');
      if (e.dataTransfer.files && e.dataTransfer.files[0]) {
        readFile(e.dataTransfer.files[0]);
      }
    };
    fileInput.onchange = () => {
      if (fileInput.files && fileInput.files[0]) readFile(fileInput.files[0]);
    };

    function readFile(file) {
      const reader = new FileReader();
      reader.onload = () => {
        rawArea.value = String(reader.result || '');
        buildPreview();
      };
      reader.readAsText(file, 'UTF-8');
    }

    function buildPreview() {
      resultArea.classList.add('hidden');
      const raw = rawArea.value.trim();
      if (!raw) {
        previewArea.classList.add('hidden');
        submitBtn.disabled = true;
        validRows = [];
        return;
      }

      const parsed = parseTableToObjects(raw, aliasMap);
      if (parsed.error) {
        toast(parsed.error, 'error');
        previewArea.classList.add('hidden');
        submitBtn.disabled = true;
        return;
      }

      const delimLabel = parsed.delimiter === '\t' ? 'Tab (Excel)' : parsed.delimiter === ';' ? 'Titik koma (;)' : 'Koma (,)';
      detectedEl.textContent = `Pemisah terdeteksi: ${delimLabel}`;

      const checked = validateAndNormalize(parsed.items, wrap);
      validRows = checked.filter((r) => !r._error).map((r) => r.payload);
      const errCount = checked.length - validRows.length;

      summaryText.textContent = `Total ${checked.length} baris (${validRows.length} siap diupload, ${errCount} error)`;
      submitBtn.disabled = validRows.length === 0;
      submitBtn.textContent = `Upload ${validRows.length} Data Valid`;

      const displayCols = templateHeaders.slice(0, 6);
      previewTable.innerHTML = `
        <thead>
          <tr>
            <th>#</th>
            ${displayCols.map((c) => `<th>${esc(c)}</th>`).join('')}
            <th>Status</th>
          </tr>
        </thead>
        <tbody>
          ${checked.slice(0, 100).map((r, idx) => `
            <tr>
              <td>${idx + 1}</td>
              ${displayCols.map((c) => `<td>${esc(r.preview[c] ?? '')}</td>`).join('')}
              <td>${r._error
                ? `<span class="badge badge-red">${esc(r._error)}</span>`
                : `<span class="badge badge-green">Siap</span>`}</td>
            </tr>
          `).join('')}
        </tbody>
      `;
      previewArea.classList.remove('hidden');
    }

    wrap.querySelector('#imp-preview-btn').onclick = buildPreview;
    rawArea.addEventListener('paste', () => setTimeout(buildPreview, 50));
    const extraEl = wrap.querySelector('#imp-extra');
    if (extraEl) {
      extraEl.addEventListener('change', () => {
        if (rawArea.value.trim()) buildPreview();
      });
      extraEl.addEventListener('input', () => {
        if (rawArea.value.trim()) buildPreview();
      });
    }

    submitBtn.onclick = async () => {
      if (!validRows.length) return;
      submitBtn.disabled = true;
      progressWrap.classList.remove('hidden');
      progressBar.style.width = '10%';
      progressLabel.textContent = `Mengunggah ${validRows.length} baris...`;

      try {
        const res = await submitRows(validRows, wrap, (done, total) => {
          const pct = Math.max(10, Math.round((done / total) * 100));
          progressBar.style.width = `${pct}%`;
          progressLabel.textContent = `Memproses ${done} / ${total} baris...`;
        });
        progressBar.style.width = '100%';
        progressLabel.textContent = `Selesai: ${res.berhasil} berhasil, ${res.gagal} gagal.`;

        const errRows = (res.results || []).filter((x) => x.status === 'error');
        resultArea.innerHTML = `
          <div class="alert ${res.gagal ? 'alert-info' : 'alert-success'}">
            <strong>Import Selesai:</strong> ${res.berhasil} berhasil, ${res.gagal} gagal dari ${res.total} baris.
            ${errRows.length ? `<button type="button" class="btn btn-outline btn-sm" id="imp-dl-err" style="margin-left:8px;">Unduh Laporan Hasil</button>` : ''}
          </div>
          ${errRows.length ? `
            <div class="table-wrap" style="max-height:180px; margin-top:8px;">
              <table>
                <thead><tr><th>Baris</th><th>Status</th><th>Keterangan</th></tr></thead>
                <tbody>
                  ${errRows.map((e) => `
                    <tr>
                      <td>${e.row}</td>
                      <td><span class="badge badge-red">Gagal</span></td>
                      <td>${esc(e.message)}</td>
                    </tr>
                  `).join('')}
                </tbody>
              </table>
            </div>
          ` : ''}
        `;
        resultArea.classList.remove('hidden');

        const dlErr = resultArea.querySelector('#imp-dl-err');
        if (dlErr) {
          dlErr.onclick = () => {
            downloadCsv(
              'hasil-import.csv',
              ['row', 'status', 'message'],
              res.results || []
            );
          };
        }

        toast(`Upload selesai: ${res.berhasil} berhasil`, res.berhasil > 0 ? 'success' : 'error');
        if (res.berhasil > 0 && typeof onComplete === 'function') {
          onComplete(res);
        }
      } catch (err) {
        toast(err.message || 'Gagal melakukan upload', 'error');
      } finally {
        submitBtn.disabled = false;
      }
    };
  }

  STA.csv = {
    parseTableToObjects,
    downloadCsv,
    openImportWizard,
  };
})(window.STA);
