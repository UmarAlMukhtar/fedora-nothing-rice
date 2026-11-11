async function diagnostic(stage, details = {}) {
  await chrome.storage.local.set({desktopPipDiagnostic: {time: new Date().toISOString(), stage, ...details}});
}

// Native auto-PiP reacts to tab changes; a temporary tab bridges desktop changes.
let desktopAway = null;

async function reconcile() {
  const windows = (await chrome.windows.getAll({windowTypes: ['normal']})).map(w => ({...w, focused: desktopAway === null ? w.focused : !desktopAway}));
  const {hold} = await chrome.storage.session.get('hold');
  await diagnostic('focus-check', {windows: windows.map(w => ({id:w.id, focused:w.focused})), hold:hold || null});
  if (hold) {
    const browser = windows.find(w => w.id === hold.windowId);
    let source, temporary;
    try { source = await chrome.tabs.get(hold.sourceId); } catch {}
    try { temporary = await chrome.tabs.get(hold.temporaryId); } catch {}
    if (!source || !temporary || !browser || browser.focused) {
      // Do not change a different tab the user deliberately selected on return.
      if (source && temporary?.active && browser?.focused) {
        await chrome.tabs.update(source.id, {active: true});
      }
      if (temporary) await chrome.tabs.remove(temporary.id);
      await chrome.storage.session.set({hold: null});
    }
    return;
  }
  if (windows.some(w => w.focused)) return;
  for (const browser of windows) {
    const [tab] = await chrome.tabs.query({windowId: browser.id, active: true});
    await diagnostic('tab-check', {windowId:browser.id, tabId:tab?.id, audible:tab?.audible, secureSite:tab?.url?.startsWith('https://')});
    if (!tab?.audible || !tab.url?.startsWith('https://')) continue;
    let results;
    try {
      results = await chrome.scripting.executeScript({
        target: {tabId: tab.id},
        func: () => [...document.querySelectorAll('video')].some(v => !v.paused && !v.ended && v.readyState >= 2 && !v.muted)
      });
    } catch (error) { await diagnostic('script-error',{error:error.message}); continue; }
    await diagnostic('playback-check',{playing:results.some(r => r.result === true)});
    if (!results.some(r => r.result === true)) continue;
    if (desktopAway !== true && (await chrome.windows.getAll({windowTypes: ['normal']})).some(w => w.focused)) return;
    const [current] = await chrome.tabs.query({windowId: browser.id, active: true});
    if (current?.id !== tab.id) return;
    const temporary = await chrome.tabs.create({windowId: browser.id, active: true, url: chrome.runtime.getURL('standby.html')});
    await chrome.storage.session.set({hold: {windowId: browser.id, sourceId: tab.id, temporaryId: temporary.id}});
    await diagnostic('temporary-tab-opened');
    return;
  }
}

let queue = Promise.resolve();
let timer;
function schedule() {
  clearTimeout(timer);
  timer = setTimeout(() => {
    queue = queue.then(reconcile).catch(error => diagnostic('error',{error:error.message}));
  }, 200);
}
chrome.windows.onFocusChanged.addListener(schedule);
chrome.tabs.onActivated.addListener(schedule);
chrome.tabs.onRemoved.addListener(schedule);

diagnostic('worker-loaded');

let desktopPort;
function connectDesktop() {
  desktopPort = chrome.runtime.connectNative('io.github.bspwm.brave_pip');
  desktopPort.onMessage.addListener(message => {
    if (typeof message.away !== 'boolean') return;
    desktopAway = message.away;
    schedule();
  });
  desktopPort.onDisconnect.addListener(() => {
    diagnostic('desktop-helper-disconnected', {error: chrome.runtime.lastError?.message || 'Disconnected'});
    desktopAway = null;
    setTimeout(connectDesktop, 5000);
  });
}
connectDesktop();
