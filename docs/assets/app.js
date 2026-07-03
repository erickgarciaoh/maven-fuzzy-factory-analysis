/* =====================================================================
   Maven Fuzzy Factory — data-story runtime
   Loads the four analysis JSON exports, computes every displayed number
   from them (nothing hard-coded), renders six ECharts, and drives the
   scroll narrative. Theme-aware; charts re-render on toggle.
   ===================================================================== */
(function () {
  'use strict';

  var root = document.documentElement;
  var REDUCED = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  /* ---- Repo links --------------------------------------------------
     Canonical repository URL. The repo is published in Phase 8 (deploy);
     this page goes live at the same time, so the link resolves then.
     /blob/HEAD/ resolves to the default branch regardless of its name. */
  var REPO_URL = 'https://github.com/erickgarciaoh/maven-fuzzy-factory-analysis';
  (function wireRepo() {
    var repo = document.getElementById('repo-link');
    var sql = document.getElementById('sql-link');
    if (repo) repo.href = REPO_URL;
    if (sql) sql.href = REPO_URL + '/blob/HEAD/src/07_create_analysis_views.sql';
  })();

  /* ---- Formatting (en-US) ------------------------------------------ */
  var nf0 = new Intl.NumberFormat('en-US');
  function pct(x, d) { return (x * 100).toFixed(d == null ? 1 : d) + '%'; }
  function ppSigned(x, d) { var v = x * 100; return (v >= 0 ? '+' : '−') + Math.abs(v).toFixed(d == null ? 2 : d) + 'pp'; }
  function num(x, d) { return (x >= 0 ? '' : '−') + Math.abs(x).toFixed(d == null ? 2 : d); }
  function money(x) {
    if (x >= 1e6) return '$' + (x / 1e6).toFixed(2) + 'M';
    if (x >= 1e3) return '$' + Math.round(x / 1e3) + 'K';
    return '$' + Math.round(x);
  }
  function setNum(key, val) { document.querySelectorAll('[data-num="' + key + '"]').forEach(function (el) { el.textContent = val; }); }
  function setTxt(key, val) { document.querySelectorAll('[data-txt="' + key + '"]').forEach(function (el) { el.textContent = val; }); }

  function quarterLabel(iso) { // "2014-10-01T..." -> "Q4 2014"
    var y = iso.slice(0, 4), m = parseInt(iso.slice(5, 7), 10);
    return 'Q' + (Math.floor((m - 1) / 3) + 1) + ' ' + y;
  }
  function periodLabel(p) { return p.replace(/(\d{4})-Q(\d)/, 'Q$2 $1'); }

  /* ---- Theme palette (read leaf tokens, derive theme-dependent) ---- */
  function cv(name) { return getComputedStyle(root).getPropertyValue(name).trim(); }
  function palette() {
    var dark = root.getAttribute('data-theme') === 'dark';
    return {
      dark: dark,
      focal: dark ? cv('--accent-on-dark') : cv('--accent'),
      focalText: cv('--amber-text'),   /* AA-safe amber for chart text labels */
      text: dark ? cv('--canvas-200') : cv('--ink-900'),
      sub: dark ? cv('--canvas-500') : cv('--canvas-700'),
      grid: dark ? cv('--ink-600') : cv('--canvas-300'),
      axis: dark ? cv('--canvas-500') : cv('--canvas-700'),
      neutral: dark ? cv('--ink-300') : cv('--ink-400'),
      neutralSoft: dark ? cv('--ink-500') : cv('--canvas-400'),
      surface: dark ? cv('--ink-800') : cv('--canvas-50'),
      success: dark ? cv('--success') : cv('--success'),
      error: dark ? cv('--error') : cv('--error'),
      tipBg: dark ? cv('--ink-950') : cv('--ink-900'),
      tipFg: cv('--canvas-200'),
      d1: cv('--data-1'), d2: cv('--data-2'), d3: cv('--data-3'),
      d4: cv('--data-4'), d5: cv('--data-5'), d6: cv('--data-6'), d7: cv('--data-7')
    };
  }

  function baseTooltip(p) {
    return {
      backgroundColor: p.tipBg,
      borderWidth: 0,
      padding: [8, 12],
      textStyle: { color: p.tipFg, fontFamily: cv('--font-ui'), fontSize: 12 },
      extraCssText: 'border-radius:6px;box-shadow:0 6px 24px rgba(0,0,0,.28);'
    };
  }
  function axisLabelStyle(p) { return { color: p.axis, fontFamily: cv('--font-ui'), fontSize: 11 }; }

  var ANIM = REDUCED ? { animation: false } : { animation: true, animationDuration: 550, animationEasing: 'cubicOut', animationDelay: function (i) { return i * 40; } };

  /* ---- Chart registry (theme re-render + resize) ------------------- */
  var charts = {}; // id -> echarts instance
  var renderers = {}; // id -> function(instance)
  function mount(id) {
    var el = document.getElementById(id);
    if (!el || !window.echarts) return null;
    if (!charts[id]) charts[id] = window.echarts.init(el, null, { renderer: 'canvas' });
    return charts[id];
  }
  function draw(id, fn) {
    renderers[id] = fn;
    var inst = mount(id);
    if (inst) fn(inst, palette());
  }
  function redrawAll() {
    var p = palette();
    Object.keys(renderers).forEach(function (id) { var inst = charts[id]; if (inst) renderers[id](inst, p); });
  }
  var rzT;
  window.addEventListener('resize', function () {
    clearTimeout(rzT);
    rzT = setTimeout(function () { Object.keys(charts).forEach(function (id) { charts[id].resize(); }); }, 120);
  });

  function errState(id) { var s = document.getElementById('state-' + id); if (s) s.classList.add('is-error'); }

  /* ================================================================= */
  /*  DATA LOAD                                                         */
  /* ================================================================= */
  function loadJSON(name) { return fetch('data/' + name + '.json', { cache: 'no-cache' }).then(function (r) { if (!r.ok) throw new Error(name); return r.json(); }); }

  var DATA = {};
  Promise.allSettled([
    loadJSON('channel_economics'),
    loadJSON('funnel_conversion'),
    loadJSON('ab_test_results'),
    loadJSON('cvr_decomposition')
  ]).then(function (res) {
    DATA.eco = res[0].status === 'fulfilled' ? res[0].value : null;
    DATA.funnel = res[1].status === 'fulfilled' ? res[1].value : null;
    DATA.ab = res[2].status === 'fulfilled' ? res[2].value : null;
    DATA.decomp = res[3].status === 'fulfilled' ? res[3].value : null;

    if (window.echarts) boot();
    else { var t = setInterval(function () { if (window.echarts) { clearInterval(t); boot(); } }, 60); }
  });

  function boot() {
    initHero();
    initFunnel();
    initAB();
    initDecomp();
    initEconomics();
    initScroll();
  }

  /* ================================================================= */
  /*  HERO                                                             */
  /* ================================================================= */
  function initHero() {
    if (DATA.eco) {
      var ch = DATA.eco.filter(function (r) { return r.grain === 'channel'; });
      var tot = ch.reduce(function (a, r) { a.s += r.sessions; a.o += r.orders; a.rev += r.revenue_usd; return a; }, { s: 0, o: 0, rev: 0 });
      setNum('kpi-sessions', nf0.format(tot.s));
      setNum('kpi-orders', nf0.format(tot.o));
      setNum('kpi-revenue', money(tot.rev));
      setNum('kpi-aov', money(tot.rev / tot.o));

      // quarterly CVR sparkline
      var byQ = {};
      ch.forEach(function (r) { (byQ[r.period] = byQ[r.period] || { s: 0, o: 0 }); byQ[r.period].s += r.sessions; byQ[r.period].o += r.orders; });
      var periods = Object.keys(byQ).sort();
      var spark = periods.map(function (p) { return +(byQ[p].o / byQ[p].s * 100).toFixed(2); });
      drawSpark(periods, spark);
    } else { errState('spark'); }

    if (DATA.decomp) {
      var T = DATA.decomp.find(function (r) { return r.channel_group === 'TOTAL'; });
      if (T) {
        setNum('cvr-2012', pct(T.cvr_2012, 2));
        setNum('cvr-2015', pct(T.cvr_2015, 2));
        var delta = (T.cvr_2015 - T.cvr_2012) / T.cvr_2012;
        var deltaEl = document.querySelector('[data-num="cvr-delta"]');
        if (deltaEl) deltaEl.firstChild && (deltaEl.childNodes[1].textContent = ' +' + Math.round(delta * 100) + '% ');
      }
    }
  }

  function drawSpark(periods, vals) {
    draw('chart-spark', function (inst, p) {
      inst.setOption({
        grid: { left: 2, right: 8, top: 12, bottom: 4, containLabel: true },
        xAxis: { type: 'category', data: periods.map(periodLabel), boundaryGap: false, axisLine: { show: false }, axisTick: { show: false }, axisLabel: { show: false } },
        yAxis: { type: 'value', scale: true, splitLine: { show: false }, axisLabel: { show: false } },
        tooltip: Object.assign({ trigger: 'axis' }, baseTooltip(p), {
          formatter: function (a) { return periodLabel(periods[a[0].dataIndex]) + '<br><b style="font-size:14px">' + a[0].value.toFixed(2) + '%</b> conversion'; }
        }),
        series: [{
          type: 'line', data: vals, smooth: 0.35, symbol: 'circle', symbolSize: 5,
          showSymbol: false, lineStyle: { color: p.focal, width: 2.5 },
          itemStyle: { color: p.focal },
          areaStyle: { color: new window.echarts.graphic.LinearGradient(0, 0, 0, 1, [{ offset: 0, color: hexA(p.focal, 0.22) }, { offset: 1, color: hexA(p.focal, 0) }]) },
          markPoint: {
            symbol: 'circle', symbolSize: 8, data: [{ coord: [periods.length - 1, vals[vals.length - 1]] }],
            itemStyle: { color: p.focal, borderColor: p.surface, borderWidth: 2 },
            label: { show: true, position: 'top', formatter: vals[vals.length - 1].toFixed(2) + '%', color: p.focalText, fontFamily: cv('--font-ui'), fontWeight: 600, fontSize: 12 }
          }
        }],
        animation: !REDUCED, animationDuration: 700, animationEasing: 'cubicOut'
      }, true);
    });
  }

  /* ================================================================= */
  /*  ACT 01 — FUNNEL                                                  */
  /* ================================================================= */
  var STEP_LABELS = { '01_landing': 'Landing', '02_products_page': 'Products', '03_product_detail': 'Product detail', '04_cart': 'Cart', '05_shipping': 'Shipping', '06_billing': 'Billing', '07_thank_you': 'Thank-you' };
  var funnelQuarters = [], funnelDevice = 'mobile', funnelQi = 11;

  function initFunnel() {
    if (!DATA.funnel) { errState('funnel'); return; }
    funnelQuarters = Array.from(new Set(DATA.funnel.map(function (r) { return r.quarter_start; }))).sort();
    var range = document.getElementById('quarter-range');
    range.max = String(funnelQuarters.length - 1);
    funnelQi = funnelQuarters.length - 2; // default Q4 2014 (second-to-last of 13)
    range.value = String(funnelQi);
    updateQuarterOut();

    range.addEventListener('input', function () { funnelQi = +range.value; updateQuarterOut(); drawFunnel(); updateFunnelFinding(); buildFunnelTable(); });
    document.querySelectorAll('.segmented [data-device]').forEach(function (btn) {
      btn.addEventListener('click', function () {
        funnelDevice = btn.getAttribute('data-device');
        document.querySelectorAll('.segmented [data-device]').forEach(function (b) { b.setAttribute('aria-pressed', String(b === btn)); });
        drawFunnel(); updateFunnelFinding();
      });
    });

    drawFunnel(); updateFunnelFinding(); buildFunnelTable();
  }

  function updateQuarterOut() { var o = document.getElementById('quarter-out'); o.textContent = quarterLabel(funnelQuarters[funnelQi]); }

  function funnelRows(device) {
    var q = funnelQuarters[funnelQi];
    return DATA.funnel.filter(function (r) { return r.quarter_start === q && r.device_type === device; }).sort(function (a, b) { return a.step_order - b.step_order; });
  }

  function drawFunnel() {
    var emph = funnelRows(funnelDevice);
    var other = funnelRows(funnelDevice === 'mobile' ? 'desktop' : 'mobile');
    var steps = emph.map(function (r) { return STEP_LABELS[r.step_name]; });
    var emphVals = emph.map(function (r) { return +(r.pct_of_step1 * 100).toFixed(1); });
    var otherVals = other.map(function (r) { return +(r.pct_of_step1 * 100).toFixed(1); });
    var emphLabel = funnelDevice === 'mobile' ? 'Mobile' : 'Desktop';
    var otherLabel = funnelDevice === 'mobile' ? 'Desktop' : 'Mobile';

    draw('chart-funnel', function (inst, p) {
      inst.setOption({
        grid: { left: 4, right: 44, top: 8, bottom: 24, containLabel: true },
        legend: { data: [emphLabel, otherLabel], top: 0, right: 0, icon: 'roundRect', itemWidth: 12, itemHeight: 12, textStyle: { color: p.sub, fontFamily: cv('--font-ui'), fontSize: 12 } },
        tooltip: Object.assign({ trigger: 'axis', axisPointer: { type: 'shadow' } }, baseTooltip(p), {
          formatter: function (arr) {
            var out = '<b>' + arr[0].axisValue + '</b>';
            arr.forEach(function (a) { out += '<br>' + a.marker + a.seriesName + ': <b>' + a.value + '%</b> of entries'; });
            return out;
          }
        }),
        xAxis: { type: 'value', max: 100, splitLine: { lineStyle: { color: p.grid, opacity: 0.5 } }, axisLabel: Object.assign({ formatter: '{value}%' }, axisLabelStyle(p)), axisLine: { show: false }, axisTick: { show: false } },
        yAxis: { type: 'category', inverse: true, data: steps, axisLine: { lineStyle: { color: p.grid } }, axisTick: { show: false }, axisLabel: { color: p.text, fontFamily: cv('--font-ui'), fontSize: 12, fontWeight: 500 } },
        series: [
          { name: emphLabel, type: 'bar', data: emphVals, barGap: '10%', barCategoryGap: '36%', itemStyle: { color: p.focal, borderRadius: [0, 3, 3, 0] }, label: { show: true, position: 'right', formatter: '{c}%', color: p.text, fontFamily: cv('--font-ui'), fontWeight: 600, fontSize: 11 }, z: 3 },
          { name: otherLabel, type: 'bar', data: otherVals, itemStyle: { color: p.neutral, borderRadius: [0, 3, 3, 0] }, label: { show: true, position: 'right', formatter: '{c}%', color: p.sub, fontFamily: cv('--font-ui'), fontSize: 11 } }
        ],
        animation: !REDUCED, animationDuration: 500, animationEasing: 'cubicOut', animationDelay: function (i) { return REDUCED ? 0 : i * 45; }
      }, true);
    });
  }

  function endToEnd(device) { var rows = funnelRows(device); var last = rows[rows.length - 1]; return last ? last.pct_of_step1 : null; }
  function updateFunnelFinding() {
    setTxt('funnel-quarter', quarterLabel(funnelQuarters[funnelQi]));
    var d = endToEnd('desktop'), m = endToEnd('mobile');
    if (d != null) setNum('funnel-desktop', pct(d, 1));
    if (m != null) setNum('funnel-mobile', pct(m, 1));
  }

  function buildFunnelTable() {
    var t = document.getElementById('table-funnel'); if (!t) return;
    var dk = funnelRows('desktop'), mb = funnelRows('mobile');
    var head = '<thead><tr><th>Step</th><th>Desktop</th><th>Mobile</th></tr></thead>';
    var body = '<tbody>' + dk.map(function (r, i) {
      return '<tr><td>' + STEP_LABELS[r.step_name] + '</td><td>' + pct(r.pct_of_step1, 1) + '</td><td>' + (mb[i] ? pct(mb[i].pct_of_step1, 1) : '—') + '</td></tr>';
    }).join('') + '</tbody>';
    t.innerHTML = '<caption>Funnel by step — ' + quarterLabel(funnelQuarters[funnelQi]) + ', share of step 1</caption>' + head + body;
  }

  /* ================================================================= */
  /*  ACT 02 — A/B EXPERIMENTS                                         */
  /* ================================================================= */
  var AB_META = {
    billing_vs_billing2: { label: 'Billing vs. billing-2', scope: 'Checkout' },
    lander2_vs_lander5_desktop: { label: 'Lander-2 vs. lander-5', scope: 'Landing · desktop' },
    lander2_vs_lander4_desktop: { label: 'Lander-2 vs. lander-4', scope: 'Landing · desktop' },
    home_vs_lander1: { label: 'Home vs. lander-1', scope: 'Landing' }
  };
  function ci95(p, n) { var se = Math.sqrt(p * (1 - p) / n); return [Math.max(0, p - 1.96 * se), p + 1.96 * se]; }

  function abTests() {
    var byTest = {};
    DATA.ab.forEach(function (r) { (byTest[r.test_name] = byTest[r.test_name] || {})[r.row_type === 'result' ? 'result' : r.arm] = r; });
    return Object.keys(byTest).map(function (k) {
      var t = byTest[k];
      return {
        key: k, meta: AB_META[k] || { label: k, scope: '' },
        control: t.control, variant: t.variant, res: t.result,
        cCi: ci95(t.control.cvr, t.control.sessions),
        vCi: ci95(t.variant.cvr, t.variant.sessions)
      };
    }).sort(function (a, b) { return Math.abs(b.res.z_score) - Math.abs(a.res.z_score); });
  }

  function initAB() {
    if (!DATA.ab) { errState('ab'); return; }
    var tests = abTests();

    // findings
    var bill = tests.find(function (t) { return t.key === 'billing_vs_billing2'; });
    var l4 = tests.find(function (t) { return t.key === 'lander2_vs_lander4_desktop'; });
    if (bill) { setNum('ab-billing-lift', ppSigned(bill.res.lift_pp, 1)); setNum('ab-billing-z', num(bill.res.z_score, 2)); setNum('ab-billing-rev', money(bill.res.annualized_revenue_lift_usd)); }
    if (l4) { setNum('ab-lander4-lift', ppSigned(l4.res.lift_pp, 2)); setNum('ab-lander4-z', num(l4.res.z_score, 2)); }

    drawAB(tests);
    buildABTable(tests);
  }

  function variantColor(t, p) {
    if (t.key === 'billing_vs_billing2') return p.focal;      // the focal winner (amber, scarce)
    if (t.res.lift_pp < 0) return p.error;                    // the loser, shown in red
    if (t.res.significant_95) return p.success;               // other significant win
    return p.neutral;                                         // not significant
  }

  function drawAB(tests) {
    // rows top->bottom in |z| order; y positions
    var cats = tests.map(function (t) { return t.meta.label; });
    draw('chart-ab', function (inst, p) {
      var series = [];
      // CI whiskers (custom lines via error-bar rendered as lines)
      var ciData = [];
      tests.forEach(function (t, i) {
        ciData.push({ y: i, x0: t.cCi[0] * 100, x1: t.cCi[1] * 100, color: p.neutralSoft });
        ciData.push({ y: i, x0: t.vCi[0] * 100, x1: t.vCi[1] * 100, color: variantColor(t, p) });
      });
      series.push({
        type: 'custom', renderItem: function (params, api) {
          var d = ciData[params.dataIndex];
          var yPix = api.coord([0, d.y])[1];
          var x0 = api.coord([d.x0, d.y])[0], x1 = api.coord([d.x1, d.y])[0];
          return { type: 'group', children: [
            { type: 'line', shape: { x1: x0, y1: yPix, x2: x1, y2: yPix }, style: { stroke: d.color, lineWidth: 2, opacity: 0.55 } },
            { type: 'line', shape: { x1: x0, y1: yPix - 5, x2: x0, y2: yPix + 5 }, style: { stroke: d.color, lineWidth: 2, opacity: 0.55 } },
            { type: 'line', shape: { x1: x1, y1: yPix - 5, x2: x1, y2: yPix + 5 }, style: { stroke: d.color, lineWidth: 2, opacity: 0.55 } }
          ] };
        }, data: ciData, silent: true, z: 1
      });
      // control dots (hollow neutral) + variant dots (filled colored)
      series.push({
        name: 'Control', type: 'scatter', symbol: 'circle', symbolSize: 12, z: 3,
        itemStyle: { color: p.surface, borderColor: p.neutral, borderWidth: 2 },
        data: tests.map(function (t, i) { return { value: [t.control.cvr * 100, i], t: t, arm: 'control' }; })
      });
      series.push({
        name: 'Variant', type: 'scatter', symbol: 'circle', symbolSize: 13, z: 4,
        itemStyle: { color: function (d) { return variantColor(d.data.t, p); } },
        data: tests.map(function (t, i) { return { value: [t.variant.cvr * 100, i], t: t, arm: 'variant' }; }),
        label: {
          show: true, position: 'right', distance: 16,
          formatter: function (d) { var t = d.data.t; return '{z|z ' + num(t.res.z_score, 2) + '}  {l|' + ppSigned(t.res.lift_pp, t.res.lift_pp < 0 || Math.abs(t.res.lift_pp) < 0.1 ? 2 : 1) + '}'; },
          rich: {
            z: { color: p.sub, fontFamily: cv('--font-mono'), fontSize: 10 },
            l: { color: p.text, fontFamily: cv('--font-ui'), fontWeight: 600, fontSize: 12 }
          }
        }
      });

      inst.setOption({
        grid: { left: 8, right: 96, top: 30, bottom: 30, containLabel: true },
        legend: { top: 0, left: 0, data: ['Control', 'Variant'], icon: 'circle', textStyle: { color: p.sub, fontFamily: cv('--font-ui'), fontSize: 12 } },
        tooltip: Object.assign({ trigger: 'item' }, baseTooltip(p), {
          formatter: function (d) {
            var t = d.data.t, arm = d.data.arm, r = arm === 'control' ? t.control : t.variant;
            var sig = t.res.significant_99 ? '99% significant' : (t.res.significant_95 ? '95% significant' : 'not significant');
            return '<b>' + t.meta.label + '</b> · ' + (arm === 'control' ? 'control' : 'variant') +
              '<br>CVR <b style="font-size:14px">' + pct(r.cvr, 2) + '</b> · ' + nf0.format(r.sessions) + ' sessions' +
              '<br>Lift ' + ppSigned(t.res.lift_pp, 2) + ' · z = ' + num(t.res.z_score, 2) + '<br>' + sig;
          }
        }),
        xAxis: { type: 'value', name: 'Conversion rate', nameLocation: 'middle', nameGap: 30, nameTextStyle: { color: p.sub, fontFamily: cv('--font-ui'), fontSize: 11 }, min: 0, axisLabel: Object.assign({ formatter: '{value}%' }, axisLabelStyle(p)), splitLine: { lineStyle: { color: p.grid, opacity: 0.5 } }, axisLine: { show: false }, axisTick: { show: false } },
        yAxis: { type: 'category', inverse: true, data: cats, axisLine: { lineStyle: { color: p.grid } }, axisTick: { show: false }, axisLabel: { color: p.text, fontFamily: cv('--font-ui'), fontSize: 12, fontWeight: 500 } },
        series: series,
        animation: !REDUCED, animationDuration: 500, animationEasing: 'cubicOut'
      }, true);
    });
  }

  function buildABTable(tests) {
    var t = document.getElementById('table-ab'); if (!t) return;
    var head = '<thead><tr><th>Test</th><th>Window</th><th>Sessions<br>C / V</th><th>CVR<br>control</th><th>CVR<br>variant</th><th>Lift</th><th>z</th><th>Sig.</th><th>Annualized<br>lift</th></tr></thead>';
    var rows = tests.map(function (t) {
      var r = t.res, win = fmtDate(r.window_start) + ' – ' + fmtDate(r.window_end);
      var badge = r.significant_95
        ? (r.lift_pp < 0 ? '<span class="badge badge--loss">lost</span>' : '<span class="badge badge--win">' + (r.significant_99 ? '99%' : '95%') + '</span>')
        : '<span class="badge badge--ns">n.s.</span>';
      var rev = r.annualized_revenue_lift_usd;
      var revTxt = (rev >= 0 ? '' : '−') + money(Math.abs(rev));
      return '<tr><td><b>' + t.meta.label + '</b><br><span class="caption">' + t.meta.scope + '</span></td>' +
        '<td>' + win + '</td>' +
        '<td>' + nf0.format(t.control.sessions) + ' / ' + nf0.format(t.variant.sessions) + '</td>' +
        '<td>' + pct(t.control.cvr, 2) + '</td>' +
        '<td>' + pct(t.variant.cvr, 2) + '</td>' +
        '<td>' + ppSigned(r.lift_pp, 2) + '</td>' +
        '<td class="mono">' + num(r.z_score, 2) + '</td>' +
        '<td>' + badge + '</td>' +
        '<td>' + revTxt + '</td></tr>';
    }).join('');
    t.innerHTML = head + '<tbody>' + rows + '</tbody>';
  }
  function fmtDate(d) { var m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']; var p = d.split('-'); return m[+p[1] - 1] + ' ' + (+p[2]) + ', ' + p[0].slice(2); }

  /* ================================================================= */
  /*  ACT 03 — DECOMPOSITION                                           */
  /* ================================================================= */
  function initDecomp() {
    if (!DATA.decomp) { errState('waterfall'); errState('contrib'); return; }
    var T = DATA.decomp.find(function (r) { return r.channel_group === 'TOTAL'; });
    var chans = DATA.decomp.filter(function (r) { return r.channel_group !== 'TOTAL'; });

    setNum('decomp-intra', ppSigned(T.contribution_intra_channel_pp, 2));
    setNum('decomp-mix', ppSigned(T.contribution_mix_shift_pp, 2));
    var g = chans.find(function (r) { return r.channel_group === 'gsearch'; });
    if (g) setNum('decomp-gsearch', ppSigned(g.contribution_intra_channel_pp, 2));

    drawWaterfall(T);
    drawContrib(chans);
  }

  var CHAN_LABELS = { gsearch: 'Paid Google', bsearch: 'Paid Bing', direct: 'Direct', socialbook: 'Social', organic_search_gsearch: 'Organic Google', organic_search_bsearch: 'Organic Bing' };

  function drawWaterfall(T) {
    var base = T.cvr_2012 * 100;
    var intra = T.contribution_intra_channel_pp * 100;
    var mix = T.contribution_mix_shift_pp * 100;
    var afterIntra = base + intra;
    var final = afterIntra + mix;
    var cats = ['CVR 2012', 'Within-channel', 'Mix shift', 'CVR 2015'];
    // placeholder (transparent) + visible value
    var placeholder = [0, base, afterIntra, 0];
    var values = [base, intra, mix, final];

    draw('chart-waterfall', function (inst, p) {
      var colors = [p.neutral, p.focal, p.neutralSoft, p.neutral];
      inst.setOption({
        grid: { left: 4, right: 16, top: 28, bottom: 24, containLabel: true },
        tooltip: Object.assign({ trigger: 'axis', axisPointer: { type: 'shadow' } }, baseTooltip(p), {
          formatter: function (a) {
            var i = a[0].dataIndex;
            if (i === 0) return 'CVR 2012<br><b style="font-size:14px">' + base.toFixed(2) + '%</b>';
            if (i === 3) return 'CVR 2015<br><b style="font-size:14px">' + final.toFixed(2) + '%</b>';
            return cats[i] + '<br><b style="font-size:14px">' + ppSigned(values[i] / 100, 2) + '</b>';
          }
        }),
        xAxis: { type: 'category', data: cats, axisLabel: Object.assign({ interval: 0, hideOverlap: false }, axisLabelStyle(p)), axisLine: { lineStyle: { color: p.grid } }, axisTick: { show: false } },
        yAxis: { type: 'value', min: 0, max: 10, splitLine: { lineStyle: { color: p.grid, opacity: 0.5 } }, axisLabel: Object.assign({ formatter: '{value}%' }, axisLabelStyle(p)) },
        series: [
          { type: 'bar', stack: 'w', itemStyle: { color: 'transparent' }, emphasis: { itemStyle: { color: 'transparent' } }, data: placeholder, silent: true },
          {
            type: 'bar', stack: 'w', barWidth: '52%',
            data: values.map(function (v, i) { return { value: v, itemStyle: { color: colors[i], borderRadius: 3 } }; }),
            label: {
              show: true, position: 'top', color: p.text, fontFamily: cv('--font-ui'), fontWeight: 600, fontSize: 12,
              formatter: function (d) { var i = d.dataIndex; return (i === 1 || i === 2) ? ppSigned(values[i] / 100, 2) : values[i].toFixed(2) + '%'; }
            }
          }
        ],
        animation: !REDUCED, animationDuration: 550, animationEasing: 'cubicOut', animationDelay: function (i) { return REDUCED ? 0 : i * 90; }
      }, true);
    });
  }

  function drawContrib(chans) {
    var sorted = chans.slice().sort(function (a, b) { return a.contribution_intra_channel_pp - b.contribution_intra_channel_pp; });
    var labels = sorted.map(function (r) { return CHAN_LABELS[r.channel_group] || r.channel_group; });
    var vals = sorted.map(function (r) { return +(r.contribution_intra_channel_pp * 100).toFixed(2); });
    draw('chart-contrib', function (inst, p) {
      inst.setOption({
        grid: { left: 4, right: 52, top: 8, bottom: 24, containLabel: true },
        tooltip: Object.assign({ trigger: 'axis', axisPointer: { type: 'shadow' } }, baseTooltip(p), {
          formatter: function (a) { return a[0].name + '<br><b style="font-size:14px">' + ppSigned(a[0].value / 100, 2) + '</b> of the gain'; }
        }),
        xAxis: { type: 'value', splitLine: { lineStyle: { color: p.grid, opacity: 0.5 } }, axisLabel: Object.assign({ formatter: '{value}pp' }, axisLabelStyle(p)), axisLine: { show: false }, axisTick: { show: false } },
        yAxis: { type: 'category', data: labels, axisLine: { lineStyle: { color: p.grid } }, axisTick: { show: false }, axisLabel: { color: p.text, fontFamily: cv('--font-ui'), fontSize: 12 } },
        series: [{
          type: 'bar', barWidth: '58%',
          data: sorted.map(function (r) {
            var focal = r.channel_group === 'gsearch';
            return { value: +(r.contribution_intra_channel_pp * 100).toFixed(2), itemStyle: { color: focal ? p.focal : p.neutral, borderRadius: [0, 3, 3, 0] } };
          }),
          label: { show: true, position: 'right', formatter: function (d) { return ppSigned(d.value / 100, 2); }, color: p.sub, fontFamily: cv('--font-ui'), fontSize: 11, fontWeight: 500 }
        }],
        animation: !REDUCED, animationDuration: 500, animationEasing: 'cubicOut', animationDelay: function (i) { return REDUCED ? 0 : i * 40; }
      }, true);
    });
  }

  /* ================================================================= */
  /*  ACT 04 — ECONOMICS                                              */
  /* ================================================================= */
  function initEconomics() {
    if (!DATA.eco) { errState('revenue'); errState('refund'); return; }
    var ch = DATA.eco.filter(function (r) { return r.grain === 'channel'; });
    var pr = DATA.eco.filter(function (r) { return r.grain === 'product'; });

    // overall gross margin
    var tot = ch.reduce(function (a, r) { a.rev += r.revenue_usd; a.cogs += r.cogs_usd; return a; }, { rev: 0, cogs: 0 });
    var margin = (tot.rev - tot.cogs) / tot.rev;
    setNum('eco-margin', pct(margin, 1));
    setNum('eco-margin-2', pct(margin, 1));

    // refund spike
    var spike = pr.filter(function (r) { return r.refund_rate_pct != null; }).sort(function (a, b) { return b.refund_rate_pct - a.refund_rate_pct; })[0];
    if (spike) setNum('eco-spike', pct(spike.refund_rate_pct, 2));

    drawRevenue(ch);
    drawRefund(pr);
  }

  function drawRevenue(ch) {
    var periods = Array.from(new Set(ch.map(function (r) { return r.period; }))).sort();
    var chans = Array.from(new Set(ch.map(function (r) { return r.dimension_value; })));
    // order: gsearch last (top of stack, most visible) — actually keep gsearch as biggest base
    var order = ['organic_search_bsearch', 'socialbook', 'direct', 'organic_search_gsearch', 'bsearch', 'gsearch'];
    chans = order.filter(function (c) { return chans.indexOf(c) >= 0; });
    var idx = {}; ch.forEach(function (r) { idx[r.dimension_value + '|' + r.period] = r.revenue_usd; });

    draw('chart-revenue', function (inst, p) {
      var muted = [p.d5, p.d3, p.d1, p.d2, p.d7]; // for the 5 non-focal channels
      var series = chans.map(function (c, i) {
        var focal = c === 'gsearch';
        var color = focal ? p.focal : muted[i % muted.length];
        return {
          name: CHAN_LABELS[c] || c, type: 'line', stack: 'rev', smooth: 0.2, showSymbol: false,
          lineStyle: { width: focal ? 0 : 0 }, z: focal ? 5 : 2,
          areaStyle: { color: focal ? color : hexA(color, 0.75), opacity: focal ? 0.95 : 0.6 },
          itemStyle: { color: color },
          emphasis: { focus: 'series' },
          data: periods.map(function (pr2) { return +(idx[c + '|' + pr2] || 0).toFixed(0); })
        };
      });
      inst.setOption({
        color: [p.d5, p.d3, p.d1, p.d2, p.d7, p.focal],
        grid: { left: 6, right: 30, top: 12, bottom: 48, containLabel: true },
        legend: { bottom: 0, type: 'scroll', icon: 'roundRect', itemWidth: 11, itemHeight: 11, textStyle: { color: p.sub, fontFamily: cv('--font-ui'), fontSize: 11 } },
        tooltip: Object.assign({ trigger: 'axis' }, baseTooltip(p), {
          formatter: function (arr) {
            var out = '<b>' + periodLabel(arr[0].axisValue) + '</b>';
            var tot = arr.reduce(function (s, a) { return s + a.value; }, 0);
            arr.slice().reverse().forEach(function (a) { if (a.value > 0) out += '<br>' + a.marker + a.seriesName + ': ' + money(a.value); });
            out += '<br><span style="opacity:.7">Total: ' + money(tot) + '</span>';
            return out;
          }
        }),
        xAxis: { type: 'category', boundaryGap: false, data: periods, axisLabel: Object.assign({ formatter: periodLabel, interval: 1, rotate: 0 }, axisLabelStyle(p)), axisLine: { lineStyle: { color: p.grid } }, axisTick: { show: false } },
        yAxis: { type: 'value', splitLine: { lineStyle: { color: p.grid, opacity: 0.5 } }, axisLabel: Object.assign({ formatter: function (v) { return v >= 1000 ? '$' + (v / 1000) + 'K' : '$' + v; } }, axisLabelStyle(p)) },
        series: series,
        animation: !REDUCED, animationDuration: 600, animationEasing: 'cubicOut'
      }, true);
    });
  }

  function drawRefund(pr) {
    var periods = Array.from(new Set(pr.map(function (r) { return r.period; }))).sort();
    var prods = Array.from(new Set(pr.map(function (r) { return r.dimension_value; })));
    var idx = {}; pr.forEach(function (r) { idx[r.dimension_value + '|' + r.period] = r.refund_rate_pct; });
    var FOCAL = 'The Original Mr. Fuzzy';

    draw('chart-refund', function (inst, p) {
      var neutralSeq = [p.neutral, p.neutralSoft, p.d5];
      var ni = 0;
      var series = prods.map(function (name) {
        var focal = name === FOCAL;
        var color = focal ? p.focal : neutralSeq[ni++ % neutralSeq.length];
        var data = periods.map(function (per) { var v = idx[name + '|' + per]; return v == null ? null : +(v * 100).toFixed(2); });
        var s = {
          name: shortProd(name), type: 'line', smooth: 0.2, connectNulls: false,
          symbol: 'circle', symbolSize: focal ? 5 : 3, showSymbol: false,
          lineStyle: { color: color, width: focal ? 2.5 : 1.5, opacity: focal ? 1 : 0.7 },
          itemStyle: { color: color }, z: focal ? 5 : 2, emphasis: { focus: 'series' },
          data: data
        };
        if (focal) {
          // mark the Q3-2014 spike
          var spikeVal = Math.max.apply(null, data.filter(function (v) { return v != null; }));
          var spikeI = data.indexOf(spikeVal);
          s.markPoint = {
            symbol: 'circle', symbolSize: 9, data: [{ coord: [periods[spikeI], spikeVal] }],
            itemStyle: { color: p.focal, borderColor: p.surface, borderWidth: 2 },
            label: { show: true, position: 'top', formatter: spikeVal.toFixed(2) + '%', color: p.focalText, fontFamily: cv('--font-ui'), fontWeight: 600, fontSize: 11 }
          };
        }
        return s;
      });
      inst.setOption({
        grid: { left: 6, right: 30, top: 12, bottom: 48, containLabel: true },
        legend: { bottom: 0, type: 'scroll', icon: 'roundRect', itemWidth: 11, itemHeight: 11, textStyle: { color: p.sub, fontFamily: cv('--font-ui'), fontSize: 11 } },
        tooltip: Object.assign({ trigger: 'axis' }, baseTooltip(p), {
          formatter: function (arr) {
            var out = '<b>' + periodLabel(arr[0].axisValue) + '</b>';
            arr.forEach(function (a) { if (a.value != null) out += '<br>' + a.marker + a.seriesName + ': <b>' + a.value + '%</b>'; });
            return out;
          }
        }),
        xAxis: { type: 'category', boundaryGap: false, data: periods, axisLabel: Object.assign({ formatter: periodLabel, interval: 1 }, axisLabelStyle(p)), axisLine: { lineStyle: { color: p.grid } }, axisTick: { show: false } },
        yAxis: { type: 'value', min: 0, splitLine: { lineStyle: { color: p.grid, opacity: 0.5 } }, axisLabel: Object.assign({ formatter: '{value}%' }, axisLabelStyle(p)) },
        series: series,
        animation: !REDUCED, animationDuration: 600, animationEasing: 'cubicOut'
      }, true);
    });
  }
  function shortProd(n) { return n.replace('The Original ', '').replace('The Birthday ', '').replace('The Forever ', '').replace('The Hudson River ', '').replace(' bear', ''); }

  /* ================================================================= */
  /*  SCROLL: reveals + active nav + lazy chart draw                  */
  /* ================================================================= */
  function initScroll() {
    // topbar shadow
    var topbar = document.getElementById('topbar');
    var onScroll = function () { topbar.classList.toggle('is-scrolled', window.scrollY > 8); };
    onScroll(); window.addEventListener('scroll', onScroll, { passive: true });

    // reveal
    if ('IntersectionObserver' in window && !REDUCED) {
      var revObs = new IntersectionObserver(function (entries) {
        entries.forEach(function (e) { if (e.isIntersecting) { e.target.classList.add('is-in'); revObs.unobserve(e.target); } });
      }, { threshold: 0.12, rootMargin: '0px 0px -8% 0px' });
      document.querySelectorAll('.reveal').forEach(function (el) { revObs.observe(el); });
    } else {
      document.querySelectorAll('.reveal').forEach(function (el) { el.classList.add('is-in'); });
    }

    // active section in side-nav
    var navLinks = Array.prototype.slice.call(document.querySelectorAll('.act-index a'));
    var sections = navLinks.map(function (a) { return document.querySelector(a.getAttribute('href')); });
    if ('IntersectionObserver' in window) {
      var secObs = new IntersectionObserver(function (entries) {
        entries.forEach(function (e) {
          if (e.isIntersecting) {
            var i = sections.indexOf(e.target);
            navLinks.forEach(function (a, j) { a.classList.toggle('is-active', j === i); });
          }
        });
      }, { threshold: 0.5, rootMargin: '-30% 0px -50% 0px' });
      sections.forEach(function (s) { if (s) secObs.observe(s); });
    }

    // ensure charts already drawn resize once fonts settle
    if (document.fonts && document.fonts.ready) { document.fonts.ready.then(function () { Object.keys(charts).forEach(function (id) { charts[id].resize(); }); }); }
  }

  /* ---- Theme toggle ------------------------------------------------ */
  (function themeToggle() {
    var btn = document.getElementById('theme-toggle');
    var label = document.getElementById('theme-toggle-label');
    function sync() {
      var dark = root.getAttribute('data-theme') === 'dark';
      btn.setAttribute('aria-pressed', String(dark));
      if (label) label.textContent = dark ? 'Light' : 'Dark';
    }
    sync();
    btn.addEventListener('click', function () {
      var dark = root.getAttribute('data-theme') === 'dark';
      var next = dark ? 'light' : 'dark';
      root.setAttribute('data-theme', next);
      try { localStorage.setItem('mff-theme', next); } catch (e) {}
      sync();
      redrawAll();
    });
  })();

  /* ---- color helper: hex -> rgba ----------------------------------- */
  function hexA(hex, a) {
    hex = (hex || '').replace('#', '');
    if (hex.length === 3) hex = hex.split('').map(function (c) { return c + c; }).join('');
    var r = parseInt(hex.slice(0, 2), 16), g = parseInt(hex.slice(2, 4), 16), b = parseInt(hex.slice(4, 6), 16);
    if (isNaN(r)) return hex;
    return 'rgba(' + r + ',' + g + ',' + b + ',' + a + ')';
  }
})();
