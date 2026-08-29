/**
 * dsh-sidebar-archive — client half.
 *
 * Adds a one-click "archive" (×) button to every session row in the Web
 * sidebar, next to the existing ⋯ row menu. Clicking it commits the same
 * `workspace.archiveSession` action the row menu's "Archive session" entry
 * performs (non-destructive: the session log remains; the row disappears
 * from every grouping surface when the host echo lands).
 *
 * Why DOM injection: the session rows are rendered internally by
 * `dsh-client-ui-workspace` and declare no slot for per-row affordances, so a
 * third-party plugin cannot slot-register into them. This plugin therefore
 * observes the sidebar DOM, decorates each rendered row, and resolves the row
 * to a session id against the same stores the browser UI reads
 * (`sessions.list` / `workspaces.list`). If a row cannot be resolved
 * unambiguously, no button is shown for it — the plugin never guesses.
 *
 * UI-generation pinning: selectors and the ungrouped-group heuristic target
 * the 0.1.0-rc.6 Web UI. Every lookup is guarded, so a newer UI that drops
 * the expected classes degrades to "no buttons", never to a broken sidebar.
 */
window.__ModuleLoader__.load({
  id: "dsh-sidebar-archive",
  factory: (require) => {
    var module = { exports: {} };
    var exports = module.exports;
    Object.defineProperty(exports, Symbol.toStringTag, { value: "Module" });

    var NAME = "dsh-sidebar-archive";

    // ── UI-generation selectors (dsh-client-ui-workspace, 0.1.0-rc.6) ──────
    var ROW_SEL = '[class*="_sessionRow"]';
    var ACTIONS_SEL = '[class*="_rowActions"]';
    var TITLE_SEL = '[class*="_title"]';
    var TIME_SEL = '[class*="_time"]';
    var GROUP_SEL = '[class*="_groupSection"]';
    var PROJECT_ROW_SEL = '[class*="_projectRow"]';

    var BUTTON_CLASS = "dsh-archive-x";
    var STYLE_TAG_ID = "dsh-sidebar-archive";

    var SVG_X =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" width="16" height="16" ' +
      'fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" aria-hidden="true">' +
      '<path d="M4.35 4.35l7.3 7.3M11.65 4.35l-7.3 7.3"/></svg>';

    // ── pure helpers (exported for the node test harness) ───────────────────
    /**
     * Compact relative-time bucket, mirrored from the sidebar's own row
     * renderer (ui-workspace `relativeTime`).
     * @param {number} updatedAt - epoch ms of the session's last activity.
     * @param {number} now - current epoch ms.
     * @returns {{unit: string, n: number}}
     */
    function relativeTime(updatedAt, now) {
      var MIN = 6e4;
      var HOUR = 36e5;
      var DAY = 864e5;
      var diff = Math.max(0, now - updatedAt);
      if (diff < MIN) return { unit: "now", n: 0 };
      if (diff < HOUR) return { unit: "minutes", n: Math.floor(diff / MIN) };
      if (diff < DAY) return { unit: "hours", n: Math.floor(diff / HOUR) };
      if (diff < 30 * DAY) return { unit: "days", n: Math.floor(diff / DAY) };
      if (diff < 365 * DAY) return { unit: "months", n: Math.floor(diff / (30 * DAY)) };
      return { unit: "years", n: Math.floor(diff / (365 * DAY)) };
    }

    /**
     * The row's localized time label for a bucket, in both shipped locales
     * (en / zh). A row matches a candidate when its visible time text equals
     * either rendering.
     * @param {{unit: string, n: number}} bucket
     * @param {"en"|"zh"} locale
     * @returns {string}
     */
    function timeLabelFor(bucket, locale) {
      if (bucket.unit === "now") return locale === "zh" ? "刚刚" : "now";
      var SUFFIX = {
        en: { minutes: "min", hours: "h", days: "d", months: "mo", years: "y" },
        zh: { minutes: "分钟", hours: "小时", days: "天", months: "个月", years: "年" },
      };
      return String(bucket.n) + SUFFIX[locale][bucket.unit];
    }

    /**
     * Resolve one rendered row to exactly one session id.
     *
     * @param {{title: string, timeText: string, group: {title: string, iconButtons: number}|null}} rowInfo
     * @param {object} sessionState - SessionListState snapshot ({ byId }).
     * @param {object} workspaceState - WorkspaceListState snapshot ({ items, archivedSessionIds }).
     * @param {number} now - epoch ms.
     * @returns {{id: string}|null} - null when no candidate or ambiguous.
     */
    function resolveBinding(rowInfo, sessionState, workspaceState, now) {
      var byId = (sessionState && sessionState.byId) || {};
      var archived = new Set(((workspaceState && workspaceState.archivedSessionIds) || []));
      var items = ((workspaceState && workspaceState.items) || []);

      // session id -> owning workspace title (first account wins)
      var wsTitleBySession = new Map();
      for (var i = 0; i < items.length; i++) {
        var ws = items[i];
        var sids = ws.sessionIds || [];
        for (var j = 0; j < sids.length; j++) {
          if (!wsTitleBySession.has(sids[j])) wsTitleBySession.set(sids[j], ws.title);
        }
      }

      var title = rowInfo.title;
      if (!title) return null;

      var candidates = [];
      for (var key in byId) {
        var s = byId[key];
        if (!s || s.blank) continue;
        if (archived.has(s.id)) continue;
        if (s.displayTitle === title) candidates.push(s);
      }
      if (candidates.length === 0) return null;
      if (candidates.length === 1) return { id: candidates[0].id };

      // Disambiguate by the row's group header (grouped view only).
      var scoped = candidates;
      if (rowInfo.group) {
        var gTitle = rowInfo.group.title;
        var isRealGroup = rowInfo.group.iconButtons >= 2; // ⋯ menu + ＋ = real workspace
        scoped = candidates.filter(function (s) {
          var wsTitle = wsTitleBySession.get(s.id);
          return isRealGroup ? wsTitle === gTitle : wsTitle === undefined;
        });
        if (scoped.length === 1) return { id: scoped[0].id };
      }

      // Disambiguate by the visible relative-time bucket.
      var timeText = rowInfo.timeText;
      if (timeText) {
        var timed = scoped.filter(function (s) {
          var bucket = relativeTime(s.updatedAt, now);
          return timeLabelFor(bucket, "en") === timeText || timeLabelFor(bucket, "zh") === timeText;
        });
        if (timed.length === 1) return { id: timed[0].id };
      }

      return null; // still ambiguous: better no button than the wrong archive
    }

    // ── DOM glue ─────────────────────────────────────────────────────────────
    function injectStyle(doc) {
      if (doc.getElementById(STYLE_TAG_ID)) return;
      var css =
        "button." + BUTTON_CLASS + "{" +
        "cursor:pointer;width:16px;height:16px;flex:none;padding:0;" +
        "color:var(--dsw-alias-label-tertiary,#adb2b8);background:transparent;border:none;border-radius:4px;" +
        "display:inline-flex;align-items:center;justify-content:center;" +
        "}" +
        "button." + BUTTON_CLASS + ":hover{color:var(--dsw-alias-label-primary,#e6e8ea);}" +
        "button." + BUTTON_CLASS + ":disabled{opacity:.45;cursor:default;}" +
        "button." + BUTTON_CLASS + " svg{display:block;pointer-events:none;}";
      var tag = doc.createElement("style");
      tag.id = STYLE_TAG_ID;
      tag.dataset.plugin = NAME; // HMR driver bookkeeping: removed on fiber teardown
      tag.textContent = css;
      doc.head.appendChild(tag);
    }

    function readRow(row) {
      var titleEl = row.querySelector(TITLE_SEL);
      var timeEl = row.querySelector(TIME_SEL);
      var groupSection = row.closest ? row.closest(GROUP_SEL) : null;
      var group = null;
      if (groupSection) {
        var projectRow = groupSection.querySelector(PROJECT_ROW_SEL);
        if (projectRow) {
          var gTitleEl = projectRow.querySelector(TITLE_SEL);
          var gActions = projectRow.querySelector(ACTIONS_SEL);
          var iconButtons = gActions ? gActions.querySelectorAll("button").length : 0;
          group = {
            title: gTitleEl ? (gTitleEl.textContent || "").trim() : "",
            iconButtons: iconButtons,
          };
        }
      }
      return {
        title: titleEl ? (titleEl.textContent || "").trim() : "",
        timeText: timeEl ? (timeEl.textContent || "").trim() : "",
        group: group,
      };
    }

    function install(ctx) {
      var doc = globalThis.document;
      if (!doc || !doc.body || !doc.head) return function () {};
      var sessions = ctx.sessions;
      var workspaces = ctx.workspaces;
      if (!sessions || !workspaces || typeof workspaces.archiveSession !== "function") {
        console.warn(NAME + ": sessions/workspaces services unavailable; plugin inactive");
        return function () {};
      }

      var sessionState = sessions.list.getSnapshot();
      var workspaceState = workspaces.list.getSnapshot();

      var seenRows = new Set(); // rows with a decorated button
      var rowButtons = new Map(); // row -> button

      function bindingFor(row) {
        return resolveBinding(readRow(row), sessionState, workspaceState, Date.now());
      }

      function syncButton(row) {
        var btn = rowButtons.get(row);
        if (!btn) return;
        var hit = bindingFor(row);
        if (hit) {
          btn.hidden = false;
          btn.disabled = false;
          if (btn.dataset.sessionId !== hit.id) btn.dataset.sessionId = hit.id;
        } else {
          btn.hidden = true;
          btn.disabled = true;
          delete btn.dataset.sessionId;
        }
      }

      function undecorate(row) {
        var btn = rowButtons.get(row);
        if (btn && btn.parentNode) btn.parentNode.removeChild(btn);
        seenRows.delete(row);
        rowButtons.delete(row);
      }

      function decorate(row) {
        if (seenRows.has(row)) return;
        var actions = row.querySelector(ACTIONS_SEL);
        if (!actions) return; // blank placeholder row: no menu, no archive
        var btn = doc.createElement("button");
        btn.type = "button";
        btn.className = BUTTON_CLASS;
        btn.setAttribute("aria-label", "Archive session");
        btn.title = "Archive session";
        btn.draggable = false;
        btn.innerHTML = SVG_X;
        // Swallow the pointer/click path before it reaches the row's own
        // open-on-click handler and the HoverCard wrapper.
        ["pointerdown", "mousedown"].forEach(function (type) {
          btn.addEventListener(type, function (e) {
            e.stopPropagation();
          });
        });
        btn.addEventListener("click", function (e) {
          e.preventDefault();
          e.stopPropagation();
          var id = btn.dataset.sessionId;
          if (!id || btn.disabled) return;
          btn.disabled = true; // hold until the archive-set echo (or failure)
          Promise.resolve(workspaces.archiveSession(id)).catch(function (reason) {
            console.warn(NAME + ": archive rejected:", reason);
            btn.disabled = false;
          });
        });
        actions.appendChild(btn);
        seenRows.add(row);
        rowButtons.set(row, btn);
        syncButton(row);
      }

      function sweep() {
        // Prune decorations on rows React replaced or unmounted.
        for (var row of Array.from(seenRows)) {
          if (!doc.body.contains(row)) undecorate(row);
        }
        // Decorate live rows we have not seen yet.
        var rows = doc.querySelectorAll(ROW_SEL);
        for (var i = 0; i < rows.length; i++) {
          if (!seenRows.has(rows[i])) decorate(rows[i]);
        }
      }

      function resyncAll() {
        for (var row of seenRows) syncButton(row);
      }

      var onStoreChange = function () {
        sessionState = sessions.list.getSnapshot();
        workspaceState = workspaces.list.getSnapshot();
        resyncAll();
      };
      var unsubSessions = sessions.list.subscribe(onStoreChange);
      var unsubWorkspaces = workspaces.list.subscribe(onStoreChange);

      var observer = new MutationObserver(sweep);
      observer.observe(doc.body, { childList: true, subtree: true });
      injectStyle(doc);
      sweep();

      return function cleanup() {
        observer.disconnect();
        try { unsubSessions(); } catch (_) {}
        try { unsubWorkspaces(); } catch (_) {}
        for (var row of Array.from(seenRows)) undecorate(row);
        seenRows.clear();
        rowButtons.clear();
        var style = doc.getElementById(STYLE_TAG_ID);
        if (style && style.parentNode) style.parentNode.removeChild(style);
      };
    }

    // ── plugin entry ────────────────────────────────────────────────────────
    exports.name = NAME;
    exports.inject = ["sessions", "workspaces"];
    exports.apply = function (ctx) {
      // Fiber-scoped: the disposer runs on HMR teardown / entry refresh.
      ctx.effect(function () {
        return install(ctx);
      }, NAME + ": install");
    };

    // Test-only surface (the node harness materializes the factory and
    // exercises the pure resolver without a DOM).
    exports.__internal = {
      resolveBinding: resolveBinding,
      relativeTime: relativeTime,
      timeLabelFor: timeLabelFor,
    };

    return module.exports;
  },
});
