import { BRAND_FEATHER, BRAND_H, BRAND_RING, BRAND_S } from './brandPaths'

/**
 * Знак кофейни: зелёное кольцо, в нём H · перо · S (пути — brandPaths.ts,
 * источник — docs/brand/logo.svg). С [animate] знак «рисуется»: кольцо линией,
 * затем H, опускающееся перо и S.
 */
export function Monogram({ size = 40, animate = false }: { size?: number; animate?: boolean }) {
  return (
    <svg width={size} height={size} viewBox="0 0 100 100" aria-hidden="true" className={animate ? 'monogram draw' : 'monogram'}>
      <circle className="mono-fill" cx="50" cy="50" r={BRAND_RING.r} fill="#EAE9E5" />
      <circle
        className="mono-ring"
        cx="50"
        cy="50"
        r={BRAND_RING.r}
        fill="none"
        stroke="#5E6D50"
        strokeWidth={BRAND_RING.width}
        transform="rotate(-90 50 50)"
        pathLength={100}
      />
      <g fill="#5E6D50" fillRule="evenodd">
        <path className="mono-h" d={BRAND_H} />
        <path className="mono-feather" d={BRAND_FEATHER} />
        <path className="mono-s" d={BRAND_S} />
      </g>
    </svg>
  )
}

export function Logo({ size = 40, animate = false }: { size?: number; animate?: boolean }) {
  return (
    <div className={animate ? 'logo draw' : 'logo'} aria-label="History Coffee">
      <Monogram size={size} animate={animate} />
      <div className="logo-words">
        <div className="logo-title" style={{ fontSize: size * 0.62 }}>History</div>
        <div className="logo-sub">кофейня-бутик</div>
      </div>
    </div>
  )
}
