/**
 * dsh-hpmp-meters — Host half.
 *
 * Serves GET /hpmp/balance on the app's own origin (same-origin, so the
 * browser client needs no CORS and no host RPC). The handler resolves the
 * DeepSeek API key through the credentials service, calls the DeepSeek
 * balance endpoint via subprocess + curl, and answers JSON.
 *
 * Rows: composed at boot by the web profile (see cordis.patch.yml).
 */

export const name = 'hpmp-meters-host'

export const inject = ['webServer']

const KEY_REF = 'DEEPSEEK_API_KEY'
const BALANCE_URL = 'https://api.deepseek.com/user/balance'
const CACHE_MS = 30000

export function apply(ctx) {
  let cache = { at: 0, payload: null }

  const resolveKey = async () => {
    const credentials = ctx.get('credentials')
    if (credentials === undefined) return undefined
    try {
      const hit = await credentials.resolve(KEY_REF)
      return hit !== undefined && hit.value !== undefined && hit.value.length > 0
        ? hit.value
        : undefined
    } catch (error) {
      return undefined
    }
  }

  const resolveCurl = async (subprocess) => {
    const candidates = ['curl', 'curl.exe', 'C:\\Windows\\System32\\curl.exe']
    for (const candidate of candidates) {
      try {
        if (candidate.includes('\\') || candidate.includes('/')) return candidate
        return await subprocess.resolveExecutable(candidate)
      } catch (error) {
        // try next candidate
      }
    }
    return 'curl'
  }

  const fetchBalance = async () => {
    const key = await resolveKey()
    if (key === undefined) {
      return { ok: false, code: 'no-key', message: '未配置 DEEPSEEK_API_KEY（设置 → 模型 中填写）' }
    }
    const subprocess = ctx.get('subprocess')
    if (subprocess === undefined) {
      return { ok: false, code: 'no-subprocess', message: 'subprocess 服务不可用' }
    }
    const curl = await resolveCurl(subprocess)
    let handle
    try {
      handle = subprocess.spawn({
        argv: [curl, '-sS', '-m', '20', '-H', 'Authorization: Bearer ' + key, BALANCE_URL],
        stdio: {
          stdin: 'ignore',
          stdout: { maxBytes: 65536, spill: { maxBytes: 1048576 } },
          stderr: { maxBytes: 65536, spill: { maxBytes: 1048576 } }
        },
        graceMs: 25000
      })
    } catch (error) {
      return { ok: false, code: 'spawn-failed', message: String(error) }
    }
    let outcome
    try {
      outcome = await handle.done
    } catch (error) {
      return { ok: false, code: 'spawn-error', message: String(error) }
    }
    const out = handle.collected && handle.collected.stdout
      ? handle.collected.stdout.readFrom(0)
      : undefined
    const text = (out && out.text) || ''
    if (outcome.exitCode !== 0) {
      const err = handle.collected && handle.collected.stderr
        ? handle.collected.stderr.readFrom(0).text
        : ''
      return {
        ok: false,
        code: 'curl-failed',
        message: 'curl exit ' + outcome.exitCode + (err ? ': ' + err.slice(0, 200) : '')
      }
    }
    let parsed
    try {
      parsed = JSON.parse(text)
    } catch (error) {
      return { ok: false, code: 'bad-json', message: text.slice(0, 200) }
    }
    if (parsed && parsed.error) {
      return {
        ok: false,
        code: 'api-error',
        message: String(parsed.error.message || JSON.stringify(parsed.error)).slice(0, 200)
      }
    }
    const infos = (parsed.balance_infos || []).map((b) => ({
      currency: b.currency,
      totalBalance: b.total_balance,
      grantedBalance: b.granted_balance,
      toppedUpBalance: b.topped_up_balance
    }))
    return { ok: true, isAvailable: parsed.is_available === true, infos, fetchedAt: Date.now() }
  }

  const handler = async (req, res) => {
    const now = Date.now()
    let payload
    if (cache.payload !== null && now - cache.at < CACHE_MS) {
      payload = cache.payload
    } else {
      payload = await fetchBalance()
      cache = { at: now, payload }
    }
    res.setHeader('Content-Type', 'application/json; charset=utf-8')
    res.setHeader('Cache-Control', 'no-store')
    res.end(JSON.stringify(payload))
  }

  ctx.webServer.register({
    kind: 'exact',
    path: '/hpmp/balance',
    handler
  })
}
