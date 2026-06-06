import React from "react";
import { PlayerDot } from "./PlayerDot.jsx";

const PITCH_STYLE_ID = "wc-pitch-styles";
function ensurePitchStyles() {
  if (typeof document === "undefined" || document.getElementById(PITCH_STYLE_ID)) return;
  const el = document.createElement("style");
  el.id = PITCH_STYLE_ID;
  el.textContent = `
.wc-pitch{position:relative;border-radius:var(--radius-md);overflow:hidden;
  background:var(--surface-pitch);font-family:var(--font-sans);}
.wc-pitch__stripes{position:absolute;inset:0;
  background:repeating-linear-gradient(0deg,var(--pitch-400) 0 9%,var(--pitch-600) 9% 18%);opacity:.22;}
.wc-pitch__line{position:absolute;border:1.5px solid var(--pitch-line);}
.wc-pitch__circle{position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);
  width:60px;height:60px;border-radius:50%;border:1.5px solid var(--pitch-line);}
.wc-pitch__spot{position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);
  width:4px;height:4px;border-radius:50%;background:var(--pitch-line);}
.wc-pitch__badge{position:absolute;bottom:12px;right:12px;display:inline-flex;align-items:center;gap:4px;
  background:var(--surface-inverse);color:var(--text-on-inverse);font-size:var(--text-xs);
  font-weight:var(--weight-medium);padding:4px 10px;border-radius:var(--radius-pill);}
.wc-pitch__badge .ti{font-size:11px;}`;
  document.head.appendChild(el);
}

/**
 * The playing field. Renders turf, markings and a set of `players`
 * ([{id,name,pos,x,y}]) as PlayerDots. Vertical orientation with the GK
 * at the bottom — matching the lineup screen.
 */
export function Pitch({
  players = [],
  selectedId,
  onSelectPlayer,
  height = 380,
  aiBadge = false,
  dotSize = 38,
  style,
  className = "",
  children,
  ...rest
}) {
  ensurePitchStyles();
  return (
    <div className={`wc-pitch ${className}`.trim()} style={{ height, ...style }} {...rest}>
      <div className="wc-pitch__stripes" />
      {/* outer touchlines */}
      <div className="wc-pitch__line" style={{ top: "3%", left: "6%", width: "88%", height: "94%", borderRadius: 3 }} />
      {/* penalty boxes */}
      <div className="wc-pitch__line" style={{ top: "3%", left: "30%", width: "40%", height: "14%" }} />
      <div className="wc-pitch__line" style={{ bottom: "3%", left: "30%", width: "40%", height: "14%" }} />
      {/* halfway line + centre circle */}
      <div className="wc-pitch__line" style={{ top: "50%", left: "6%", width: "88%", height: 0 }} />
      <div className="wc-pitch__circle" />
      <div className="wc-pitch__spot" />
      {players.map((p) => (
        <PlayerDot
          key={p.id}
          name={p.name}
          pos={p.pos}
          x={p.x}
          y={p.y}
          size={dotSize}
          selected={selectedId === p.id}
          onClick={() => onSelectPlayer && onSelectPlayer(p.id)}
        />
      ))}
      {children}
      {aiBadge && (
        <span className="wc-pitch__badge"><i className="ti ti-cpu" aria-hidden="true" />AI generated</span>
      )}
    </div>
  );
}
