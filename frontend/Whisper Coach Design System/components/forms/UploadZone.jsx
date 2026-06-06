import React from "react";

const UPLOAD_STYLE_ID = "wc-upload-styles";
function ensureUploadStyles() {
  if (typeof document === "undefined" || document.getElementById(UPLOAD_STYLE_ID)) return;
  const el = document.createElement("style");
  el.id = UPLOAD_STYLE_ID;
  el.textContent = `
.wc-upload{display:block;width:100%;box-sizing:border-box;text-align:center;cursor:pointer;
  font-family:var(--font-sans);background:var(--surface-card);
  border:1px dashed var(--border-default);border-radius:var(--radius-lg);
  padding:28px 16px;transition:var(--transition-colors);}
.wc-upload:hover{background:var(--surface-sunken);}
.wc-upload .wc-upload__icon{font-size:32px;color:var(--text-tertiary);display:block;margin-bottom:8px;}
.wc-upload__title{font-size:var(--text-md);font-weight:var(--weight-medium);color:var(--text-primary);}
.wc-upload__hint{font-size:var(--text-sm);color:var(--text-secondary);margin-top:4px;}
.wc-upload.is-done{background:var(--brand-subtle);border-color:var(--brand-border);border-style:solid;}
.wc-upload.is-done .wc-upload__icon,.wc-upload.is-done .wc-upload__title{color:var(--brand);}
.wc-upload__spin{display:inline-block;animation:wc-spin 0.8s linear infinite;}
@keyframes wc-spin{to{transform:rotate(360deg);}}
@media (prefers-reduced-motion:reduce){.wc-upload__spin{animation:none;}}`;
  document.head.appendChild(el);
}

const UPLOAD_COPY = {
  idle: { icon: "camera", title: "Upload team roster photo", hint: "AI will extract player names automatically" },
  processing: { icon: "loader-2", title: "Reading roster…", hint: "Extracting player names" },
  done: { icon: "circle-check", title: "Photo processed!", hint: "players detected" },
};

/**
 * Dashed photo-upload target for the "extract roster" flow. Drive the
 * three states with `status`; on `done` it shows the detected count.
 */
export function UploadZone({ status = "idle", count, title, hint, onClick, style, className = "", ...rest }) {
  ensureUploadStyles();
  const c = UPLOAD_COPY[status] || UPLOAD_COPY.idle;
  const resolvedHint = hint != null ? hint : status === "done" && count != null ? `${count} ${c.hint}` : c.hint;
  return (
    <div
      role="button"
      tabIndex={0}
      className={`wc-upload${status === "done" ? " is-done" : ""} ${className}`.trim()}
      onClick={onClick}
      style={style}
      {...rest}
    >
      <i
        className={`ti ti-${c.icon} wc-upload__icon${status === "processing" ? " wc-upload__spin" : ""}`}
        aria-hidden="true"
      />
      <div className="wc-upload__title">{title || c.title}</div>
      <div className="wc-upload__hint">{resolvedHint}</div>
    </div>
  );
}
