"use client";

import Image from "next/image";
import Link from "next/link";
import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
  useSyncExternalStore,
  type CSSProperties,
  type PointerEvent as ReactPointerEvent,
} from "react";

import "./DriftWall.css";

/**
 * <DriftWall /> — a 3D wall of image tiles that drift vertically, ported from
 * React Bits (https://reactbits.dev) and adapted for this project.
 *
 * How it works, in one paragraph: the tiles are laid out in `columns` vertical
 * tracks inside a CSS `perspective` container. Each track holds several copies
 * of its items stacked end to end, and a single requestAnimationFrame loop
 * moves each track up or down by writing `transform: translate3d(...)` on it.
 * When a track has travelled exactly one copy's height the offset wraps back
 * to zero with a modulo, and because the next copy is identical the seam is
 * invisible — that is the whole trick behind the endless drift. The loop
 * writes to the DOM directly rather than through React state, so 60fps of
 * animation causes zero re-renders.
 *
 * Five deliberate changes from the upstream source:
 *
 *  1. Ported to TypeScript, to match the rest of the codebase.
 *  2. Ref callbacks use a block body. React 19 treats a *returned* value from
 *     a ref callback as a cleanup function, so the upstream shorthand
 *     `ref={el => (refs.current[c] = el)}` — an assignment expression, which
 *     returns the assigned value — throws at runtime here.
 *  3. `useLayoutEffect` became `useEffect`. Client components are still
 *     server-rendered in the App Router, and useLayoutEffect logs a warning
 *     during SSR. The observer reports the size as soon as it attaches, so
 *     nothing is lost.
 *  4. Images render through `next/image` and links through `next/link`, so
 *     photos are resized by the optimiser (subject to the host allowlist in
 *     next.config.ts) and navigation stays client-side instead of upstream's
 *     `target="_blank"`.
 *  5. The upstream default of 15 picsum.photos demo tiles is gone and `items`
 *     is required. This archive does not ship placeholder content that looks
 *     real, and those hosts are not in the image allowlist anyway.
 *
 * Plus one addition: `decorative`. See the prop docs below.
 */

export type DriftWallItem = {
  /** Absolute image URL. Must be on an allowlisted host — see next.config.ts. */
  image: string;
  title?: string;
  href?: string;
};

/**
 * React's CSSProperties has no room for custom properties, so the `--dw-*`
 * variables this component sets would be a type error without widening it.
 */
type CSSVarStyle = CSSProperties & Record<`--${string}`, string | number>;

type DriftWallProps = {
  items: DriftWallItem[];
  /** Number of drifting columns. Items are dealt across them round-robin. */
  columns?: number;
  tileWidth?: number;
  tileHeight?: number;
  gap?: number;
  radius?: number;
  /** Perspective pitch of the wall (rotateX, degrees). */
  tilt?: number;
  /** Perspective yaw of the wall (rotateY, degrees). */
  turn?: number;
  /** In-plane rotation of the wall (rotateZ, degrees). */
  roll?: number;
  /** Perspective distance in px — smaller is more dramatic. */
  perspective?: number;
  /** How far the wall sits back from the viewer, in px. */
  depth?: number;
  /**
   * Scatters the columns in depth, up to this many px further back.
   *
   * Not in the upstream component, which puts every column on one flat plane —
   * so its only 3D cue is the shared tilt. With a spread, near columns sweep
   * across far ones as the pointer moves and the wall reads as having actual
   * volume. 0 restores the original flat behaviour.
   */
  spread?: number;
  /** Base drift speed in px per second. */
  speed?: number;
  /** Primary drift direction; columns alternate around it. */
  direction?: "up" | "down";
  /** How much column speeds differ from each other (0–1). */
  variance?: number;
  /** Pointer-follow tilt strength; 0 disables it. */
  parallax?: number;
  pauseOnHover?: boolean;
  /** How far a hovered tile lifts toward the viewer, in px. */
  lift?: number;
  /** Strength of the edge and depth dissolve (0–1). */
  fade?: number;
  /** Resting opacity of unhovered tiles (0–1). */
  dim?: number;
  grayscale?: boolean;
  /** Tint laid over resting tiles, cleared on hover. */
  overlayColor?: string;
  /**
   * Renders the wall as pure decoration: hidden from assistive technology,
   * with no focusable or clickable tiles.
   *
   * This matters when the same items are already listed elsewhere on the page.
   * Each item is repeated once per column copy, so an interactive wall of a
   * dozen photos puts fifty-odd duplicate links in the tab order ahead of the
   * real content. Decorative mode keeps the motion and the hover lift while
   * leaving the accessible page exactly as it was.
   */
  decorative?: boolean;
  className?: string;
  style?: CSSVarStyle;
};

const REDUCED_MOTION_QUERY = "(prefers-reduced-motion: reduce)";

/*
 * The three halves of a useSyncExternalStore subscription: how to listen, how
 * to read the current value, and what to report on the server (where there is
 * no matchMedia at all).
 */
const subscribeToReducedMotion = (onStoreChange: () => void) => {
  const mq = window.matchMedia(REDUCED_MOTION_QUERY);
  mq.addEventListener("change", onStoreChange);
  return () => mq.removeEventListener("change", onStoreChange);
};

const getReducedMotion = () => window.matchMedia(REDUCED_MOTION_QUERY).matches;

const getServerReducedMotion = () => false;

/**
 * Gives each column a stable, uneven speed multiplier so the columns do not
 * visibly march in lockstep. Multiplying by the golden ratio and taking the
 * fractional part scatters successive indices about as evenly as possible,
 * and unlike Math.random() it returns the same value on the server and the
 * client — which matters, because this feeds the first render.
 */
const columnFactor = (index: number, variance: number) => {
  const pseudo = ((index * 0.6180339887 + 0.35) % 1) * 2 - 1;
  return 1 + variance * pseudo;
};

export function DriftWall({
  items,
  columns = 5,
  tileWidth = 200,
  tileHeight = 132,
  gap = 18,
  radius = 14,
  tilt = 16,
  turn = -14,
  roll = 0,
  perspective = 1200,
  depth = 120,
  spread = 0,
  speed = 42,
  direction = "up",
  variance = 0.45,
  parallax = 0.6,
  pauseOnHover = false,
  lift = 64,
  fade = 0.6,
  dim = 0.55,
  grayscale = false,
  overlayColor = "#060010",
  decorative = false,
  className = "",
  style,
}: DriftWallProps) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const planeRef = useRef<HTMLDivElement | null>(null);
  const trackRefs = useRef<(HTMLDivElement | null)[]>([]);
  const rafRef = useRef<number | null>(null);

  /*
   * Everything the animation loop touches lives in a ref, not in state. A ref
   * can be written 60 times a second without scheduling a render.
   */
  const offsetsRef = useRef<number[]>([]);
  const velocitiesRef = useRef<number[]>([]);
  const hoveredColRef = useRef(-1);
  const wallHoveredRef = useRef(false);
  const pointerRef = useRef({ x: 0, y: 0 });
  const pointerDampedRef = useRef({ x: 0, y: 0 });
  const lastTsRef = useRef<number | null>(null);

  const [containerHeight, setContainerHeight] = useState(600);
  const [activeId, setActiveId] = useState<string | null>(null);
  const activeIdRef = useRef<string | null>(null);

  /*
   * Whether the visitor asked their OS to reduce motion. Read through
   * useSyncExternalStore rather than useState + useEffect, for two reasons:
   * it takes a separate server snapshot, so the server render and the client
   * hydration agree without reading matchMedia during render; and it does not
   * set state from inside an effect, which the React Compiler lint rules
   * reject as a cascading render.
   */
  const reduced = useSyncExternalStore(
    subscribeToReducedMotion,
    getReducedMotion,
    getServerReducedMotion,
  );

  /** Deals the items across columns round-robin: 0,1,2,0,1,2,… */
  const columnItems = useMemo(() => {
    const cols: DriftWallItem[][] = Array.from({ length: columns }, () => []);
    items.forEach((item, i) => cols[i % columns].push(item));
    // A column with no items of its own borrows the first, so that fewer
    // items than columns still fills the wall instead of leaving a gap.
    return cols.map((col) => (col.length ? col : items.slice(0, 1)));
  }, [items, columns]);

  /**
   * Per column: the height of one full pass through its items (the distance
   * after which the drift wraps), and how many copies are needed to keep the
   * container covered while one of them is scrolling out of view.
   */
  const columnMeta = useMemo(() => {
    const unit = tileHeight + gap;
    return columnItems.map((col) => {
      const copyHeight = Math.max(unit, col.length * unit);
      const copies = Math.max(2, Math.ceil((containerHeight * 1.6) / copyHeight) + 1);
      return { copyHeight, copies };
    });
  }, [columnItems, tileHeight, gap, containerHeight]);

  useEffect(() => {
    const el = containerRef.current;
    if (!el) return;
    const ro = new ResizeObserver(([entry]) => {
      setContainerHeight(entry.contentRect.height || 600);
    });
    ro.observe(el);
    return () => ro.disconnect();
  }, []);

  const baseVelocities = useMemo(() => {
    const dirSign = direction === "up" ? 1 : -1;
    // Alternating the sign per column makes neighbours move against each
    // other, which is what reads as "drift" rather than "scroll".
    return columnItems.map((_, c) => {
      const altSign = c % 2 === 0 ? 1 : -1;
      return speed * columnFactor(c, variance) * dirSign * altSign;
    });
  }, [columnItems, speed, direction, variance]);

  /*
   * How far back each column sits. Same golden-ratio scatter as the speeds, so
   * the depths are uneven rather than a repeating near/far/near sawtooth.
   */
  const columnDepths = useMemo(
    () => columnItems.map((_, c) => -spread * ((c * 0.6180339887) % 1)),
    [columnItems, spread],
  );

  /*
   * Seeds an offset for any column that does not have one yet, staggering the
   * columns so they do not all start at the same point.
   *
   * Existing offsets are preserved rather than reset. columnMeta changes on
   * every resize, and upstream's unconditional reset made the whole wall jump
   * back to its starting position whenever the container height changed —
   * which on mobile happens every time the browser chrome hides.
   */
  useEffect(() => {
    offsetsRef.current = columnMeta.map(
      (meta, c) => offsetsRef.current[c] ?? meta.copyHeight * ((c * 0.37) % 1),
    );
    velocitiesRef.current = columnItems.map((_, c) => velocitiesRef.current[c] ?? 0);
  }, [columnMeta, columnItems]);

  const applyPlaneTransform = useCallback(
    (px: number, py: number) => {
      const plane = planeRef.current;
      if (!plane) return;
      /*
       * The plane is overfilled so the rotated slab still covers the corners
       * it would otherwise pull away from. A column pushed back by `spread`
       * shrinks by perspective / (perspective + spread), so the overfill grows
       * by the reciprocal — otherwise a wide spread would expose the edges.
       */
      const scale = 1.18 * ((perspective + spread) / perspective);
      plane.style.transform =
        `translate(-50%, -50%) scale(${scale.toFixed(3)}) ` +
        `rotateX(${tilt + py}deg) rotateY(${turn + px}deg) rotateZ(${roll}deg) ` +
        `translateZ(${-depth}px)`;
    },
    [tilt, turn, roll, depth, perspective, spread],
  );

  useEffect(() => {
    const animate = (ts: number) => {
      if (lastTsRef.current === null) lastTsRef.current = ts;
      // Clamped so a backgrounded tab that resumes after ten seconds does not
      // teleport every column by ten seconds' worth of travel.
      const dt = Math.min(0.05, Math.max(0, ts - lastTsRef.current) / 1000);
      lastTsRef.current = ts;

      /*
       * Pointer parallax. Both this and the column speeds below use the same
       * frame-rate-independent easing: 1 - e^(-dt/tau) is the fraction of the
       * remaining distance to close this frame, where tau is roughly the time
       * constant in seconds. It behaves identically at 60Hz and 120Hz, which a
       * plain `current += (target - current) * 0.1` does not.
       */
      const maxTilt = parallax * 8;
      const targetX = pointerRef.current.x * maxTilt;
      const targetY = -pointerRef.current.y * maxTilt;
      const damp = 1 - Math.exp(-dt / 0.12);
      pointerDampedRef.current.x += (targetX - pointerDampedRef.current.x) * damp;
      pointerDampedRef.current.y += (targetY - pointerDampedRef.current.y) * damp;
      applyPlaneTransform(pointerDampedRef.current.x, pointerDampedRef.current.y);

      if (!reduced) {
        for (let c = 0; c < trackRefs.current.length; c++) {
          const meta = columnMeta[c];
          if (!meta) continue;

          // A hovered column eases to a stop so the tile can be looked at.
          const paused = wallHoveredRef.current && pauseOnHover;
          const factor = paused || hoveredColRef.current === c ? 0 : 1;
          const target = baseVelocities[c] * factor;

          // Stopping (0.16s) is quicker than starting again (0.28s).
          const ease = 1 - Math.exp(-dt / (target === 0 ? 0.16 : 0.28));
          velocitiesRef.current[c] += (target - velocitiesRef.current[c]) * ease;

          // The modulo is what makes the drift endless: one copy's height of
          // travel lands on an identical copy, so the wrap is invisible. The
          // doubled remainder keeps it positive for downward drift.
          let next = (offsetsRef.current[c] ?? 0) + velocitiesRef.current[c] * dt;
          next = ((next % meta.copyHeight) + meta.copyHeight) % meta.copyHeight;
          offsetsRef.current[c] = next;

          const el = trackRefs.current[c];
          if (el) el.style.transform = `translate3d(0, ${-next}px, 0)`;
        }
      } else {
        // Reduced motion: hold each column still, but keep writing the
        // transform so a resize still positions the tracks correctly.
        for (let c = 0; c < trackRefs.current.length; c++) {
          const el = trackRefs.current[c];
          if (el && columnMeta[c]) {
            el.style.transform = `translate3d(0, ${-(offsetsRef.current[c] ?? 0)}px, 0)`;
          }
        }
      }

      rafRef.current = requestAnimationFrame(animate);
    };

    rafRef.current = requestAnimationFrame(animate);
    return () => {
      if (rafRef.current) cancelAnimationFrame(rafRef.current);
      rafRef.current = null;
      lastTsRef.current = null;
    };
  }, [baseVelocities, columnMeta, pauseOnHover, parallax, reduced, applyPlaneTransform]);

  const activate = useCallback((id: string, index: number) => {
    activeIdRef.current = id;
    hoveredColRef.current = index;
    setActiveId(id);
  }, []);

  const release = useCallback(() => {
    activeIdRef.current = null;
    hoveredColRef.current = -1;
    setActiveId(null);
  }, []);

  /*
   * Hover is resolved with elementFromPoint rather than per-tile onPointerEnter
   * because the tiles are moving underneath a stationary cursor: the browser
   * does not reliably fire enter/leave for an element that slides out from
   * under a pointer that has not itself moved.
   *
   * The ref check short-circuits before setState, so no render happens while
   * the pointer stays on the same tile.
   */
  const handlePointerMove = useCallback(
    (e: ReactPointerEvent<HTMLDivElement>) => {
      const rect = containerRef.current?.getBoundingClientRect();
      if (!rect) return;

      if (parallax > 0 && !reduced) {
        pointerRef.current = {
          x: (e.clientX - rect.left) / rect.width - 0.5,
          y: (e.clientY - rect.top) / rect.height - 0.5,
        };
      }

      const hit = document.elementFromPoint(e.clientX, e.clientY);
      const tile = hit?.closest?.("[data-tile-id]") as HTMLElement | null;
      if (!tile) return;

      const id = tile.dataset.tileId;
      if (!id || id === activeIdRef.current) return;
      activeIdRef.current = id;
      hoveredColRef.current = Number(tile.dataset.col);
      setActiveId(id);
    },
    [parallax, reduced],
  );

  const handlePointerLeaveWall = useCallback(() => {
    wallHoveredRef.current = false;
    pointerRef.current = { x: 0, y: 0 };
    release();
  }, [release]);

  const cssVars = useMemo<CSSVarStyle>(
    () => ({
      "--dw-tile-w": `${tileWidth}px`,
      "--dw-tile-h": `${tileHeight}px`,
      "--dw-gap": `${gap}px`,
      "--dw-radius": `${radius}px`,
      "--dw-perspective": `${perspective}px`,
      "--dw-lift": `${lift}px`,
      "--dw-dim": dim,
      "--dw-gray": grayscale ? 1 : 0,
      "--dw-overlay": overlayColor,
      // fade is expressed as "how much dissolve"; the CSS mask wants the
      // opposite — the point at which the gradient starts fading out.
      "--dw-edge": `${Math.max(0, (1 - fade) * 100)}%`,
      ...style,
    }),
    [tileWidth, tileHeight, gap, radius, perspective, lift, dim, grayscale, overlayColor, fade, style],
  );

  const renderTile = (item: DriftWallItem, id: string, colIndex: number) => {
    const inner = (
      <span className="drift-wall__inner">
        <Image
          src={item.image}
          alt={decorative ? "" : (item.title ?? "")}
          width={tileWidth}
          height={tileHeight}
          draggable={false}
        />
        <span className="drift-wall__overlay" aria-hidden="true" />
      </span>
    );

    const tileClass = `drift-wall__tile${activeId === id ? " is-active" : ""}`;

    if (decorative) {
      return (
        <span key={id} className={tileClass} data-tile-id={id} data-col={colIndex}>
          {inner}
        </span>
      );
    }

    if (item.href) {
      return (
        <Link
          key={id}
          href={item.href}
          className={tileClass}
          data-tile-id={id}
          data-col={colIndex}
          onFocus={() => activate(id, colIndex)}
          onBlur={release}
        >
          {inner}
        </Link>
      );
    }

    return (
      <div
        key={id}
        tabIndex={0}
        role="button"
        aria-label={item.title ?? "tile"}
        className={tileClass}
        data-tile-id={id}
        data-col={colIndex}
        onFocus={() => activate(id, colIndex)}
        onBlur={release}
      >
        {inner}
      </div>
    );
  };

  const rootClass = [
    "drift-wall",
    reduced ? "drift-wall--reduced" : "",
    decorative ? "drift-wall--decorative" : "",
    className,
  ]
    .filter(Boolean)
    .join(" ");

  return (
    <div
      ref={containerRef}
      className={rootClass}
      style={cssVars}
      onPointerMove={handlePointerMove}
      onPointerEnter={() => {
        wallHoveredRef.current = true;
      }}
      onPointerLeave={handlePointerLeaveWall}
      {...(decorative
        ? { "aria-hidden": true as const }
        : { role: "group", "aria-label": "Drifting wall of tiles" })}
    >
      <div ref={planeRef} className="drift-wall__plane">
        {columnItems.map((col, c) => {
          const meta = columnMeta[c];
          const copies = Array.from({ length: meta.copies });
          return (
            <div
              className="drift-wall__col"
              key={`col-${c}`}
              style={{ transform: `translateZ(${columnDepths[c].toFixed(1)}px)` }}
            >
              <div
                className="drift-wall__track"
                ref={(el) => {
                  trackRefs.current[c] = el;
                }}
              >
                {copies.map((_, copyIndex) =>
                  col.map((item, itemIndex) =>
                    renderTile(item, `${c}-${copyIndex}-${itemIndex}`, c),
                  ),
                )}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

export default DriftWall;
