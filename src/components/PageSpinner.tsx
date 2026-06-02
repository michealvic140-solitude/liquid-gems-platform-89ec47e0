import { useEffect, useState } from "react";
import { useRouterState } from "@tanstack/react-router";
import { Loader2 } from "lucide-react";

/**
 * Non-blocking page transition indicator.
 * Shows a small pill in the corner only while the router is actively
 * transitioning between routes — never blocks interaction with the page.
 */
export function PageSpinner() {
  const pending = useRouterState({ select: (s) => s.status === "pending" });
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    if (!pending) { setVisible(false); return; }
    // Only show if the transition takes longer than a brief moment.
    const t = window.setTimeout(() => setVisible(true), 150);
    return () => window.clearTimeout(t);
  }, [pending]);

  if (!visible) return null;
  return (
    <div
      role="status"
      aria-live="polite"
      aria-label="Loading"
      className="pointer-events-none fixed bottom-4 right-4 z-[9999] flex items-center gap-2 rounded-full border border-primary/30 bg-background/90 px-3 py-1.5 shadow-lg backdrop-blur animate-in fade-in slide-in-from-bottom-2 duration-150"
    >
      <Loader2 className="h-4 w-4 text-primary animate-spin" strokeWidth={2.5} />
      <span className="text-[10px] uppercase tracking-[0.3em] text-primary font-bold">Loading</span>
    </div>
  );
}
