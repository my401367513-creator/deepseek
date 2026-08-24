/**
 * dsh-hpmp-meters — Client half (browser module, __ModuleLoader__ format).
 *
 * Renders two compact meters in the composer dock (`conversation.composer.dock`):
 *  - HP (red): remaining context tokens, from the contextPressure projection.
 *  - MP (blue): DeepSeek account balance, fetched same-origin from
 *    GET /hpmp/balance (served by the Host half). Auto-refresh 60s + manual ⟳.
 */

window.__ModuleLoader__.load({
  id: 'dsh-hpmp-meters',
  factory: (require) => {
    var module = { exports: {} }
    var exports = module.exports
    Object.defineProperty(exports, Symbol.toStringTag, { value: 'Module' })

    var React = require('react')

    var STYLE_TAG_ID = 'dsh-hpmp-meters-styles'
    var css = [
      '.hpmp-dock { display: flex; align-items: center; gap: 14px; padding: 2px 4px; font-size: 11px; line-height: 1; color: rgba(130,130,130,0.92); user-select: none; }',
      '.hpmp-meter { display: flex; align-items: center; gap: 6px; min-width: 0; }',
      '.hpmp-bar { position: relative; width: 110px; height: 10px; border-radius: 5px; background: rgba(128,128,128,0.18); overflow: hidden; flex: none; }',
      '.hpmp-fill { position: absolute; left: 0; top: 0; bottom: 0; border-radius: 5px; transition: width .4s ease; }',
      '.hpmp-hp .hpmp-fill { background: linear-gradient(90deg, #ef4444, #f97316); }',
      '.hpmp-mp .hpmp-fill { background: linear-gradient(90deg, #3b82f6, #22d3ee); }',
      '.hpmp-label { flex: none; white-space: nowrap; }',
      '.hpmp-refresh { cursor: pointer; opacity: .7; border: none; background: none; color: inherit; font-size: 11px; padding: 0 3px; }',
      '.hpmp-refresh:hover { opacity: 1; }'
    ].join('\n')

    var styleTag = null
    function ensureStyles() {
      if (styleTag !== null || typeof document === 'undefined') return
      if (document.querySelector('style[data-plugin-css="' + STYLE_TAG_ID + '"]') !== null) return
      styleTag = document.createElement('style')
      styleTag.dataset.pluginCss = STYLE_TAG_ID
      styleTag.textContent = css
      document.head.appendChild(styleTag)
    }
    function removeStyles() {
      if (styleTag !== null && styleTag.parentNode !== null) {
        styleTag.parentNode.removeChild(styleTag)
      }
      styleTag = null
    }

    function fmt(n) {
      if (n >= 1000000) return (n / 1000000).toFixed(1) + 'M'
      if (n >= 1000) return (n / 1000).toFixed(0) + 'k'
      return String(n)
    }

    function Meters(props) {
      var useProjection = props.useProjection
      var pressure = useProjection ? useProjection('contextPressure') : undefined
      var balanceState = React.useState(null)
      var balance = balanceState[0]
      var setBalance = balanceState[1]
      var errorState = React.useState(null)
      var error = errorState[0]
      var setError = errorState[1]
      var maxRefState = React.useState(null)
      var maxRef = maxRefState[0]
      var setMaxRef = maxRefState[1]

      var refresh = React.useCallback(function () {
        fetch('/hpmp/balance', { cache: 'no-store' }).then(function (response) {
          return response.json()
        }).then(function (res) {
          setBalance(res)
          setError(null)
          if (res && res.ok && Array.isArray(res.infos) && res.infos.length > 0) {
            var total = res.infos[0].totalBalance
            setMaxRef(function (prev) {
              return prev === null || total > prev ? total : prev
            })
          }
        }, function (err) {
          setBalance(null)
          setError(String(err))
        })
      }, [])

      React.useEffect(function () {
        refresh()
        var timer = setInterval(refresh, 60000)
        return function () {
          clearInterval(timer)
        }
      }, [refresh])

      var contextWindow = pressure ? pressure.contextWindow : undefined
      var used = pressure && pressure.projectedTokens !== undefined ? pressure.projectedTokens : undefined
      var hpPct = 0
      if (contextWindow && used !== undefined) {
        hpPct = Math.min(100, Math.max(0, (used / contextWindow) * 100))
      }
      var hpRemain = contextWindow && used !== undefined ? Math.max(0, contextWindow - used) : undefined

      var mpPct = 0
      var mpText = '…'
      if (balance && balance.ok && Array.isArray(balance.infos) && balance.infos.length > 0) {
        var info = balance.infos[0]
        var total = info.totalBalance
        mpText = (info.currency === 'CNY' ? '¥' : '$') + Number(total).toFixed(2)
        if (maxRef !== null && maxRef > 0) {
          mpPct = Math.min(100, Math.max(0, (total / maxRef) * 100))
        }
      } else if (balance && !balance.ok) {
        mpText = balance.code === 'no-key' ? '未配置 Key' : String(balance.message || '余额不可用')
      } else if (error) {
        mpText = '查询失败'
      }

      return React.createElement('div', { className: 'hpmp-dock' },
        React.createElement('div', {
          className: 'hpmp-meter hpmp-hp',
          title: hpRemain !== undefined ? ('已用 ' + used + ' tok，剩余 ' + hpRemain + ' tok') : '暂无上下文数据'
        },
          React.createElement('span', { className: 'hpmp-label' }, '上下文'),
          React.createElement('div', { className: 'hpmp-bar' },
            React.createElement('div', { className: 'hpmp-fill', style: { width: hpPct + '%' } })),
          React.createElement('span', { className: 'hpmp-label' },
            hpRemain !== undefined ? ('剩 ' + fmt(hpRemain)) : (contextWindow !== undefined ? '加载中' : '—'))
        ),
        React.createElement('div', { className: 'hpmp-meter hpmp-mp', title: 'DeepSeek 开放平台余额' },
          React.createElement('span', { className: 'hpmp-label' }, 'DeepSeek'),
          React.createElement('div', { className: 'hpmp-bar' },
            React.createElement('div', { className: 'hpmp-fill', style: { width: mpPct + '%' } })),
          React.createElement('span', { className: 'hpmp-label' }, mpText),
          React.createElement('button', { className: 'hpmp-refresh', onClick: refresh }, '⟳')
        )
      )
    }

    function apply(ctx) {
      ensureStyles()
      var slots = ctx.get('slots')
      if (slots === undefined) return
      var dispose = slots.inject('conversation.composer.dock', function () {
        return slots.register(
          { name: 'conversation.composer.dock', id: 'hpmp-meters', order: 20 },
          function (props) {
            return React.createElement(Meters, props)
          }
        )
      })
      return function () {
        dispose()
        removeStyles()
      }
    }

    exports.name = 'hpmp-meters'
    exports.inject = ['slots']
    exports.apply = apply
    return module.exports
  }
})
