import { useRouterState } from "@tanstack/react-router";
import { Loader2 } from "lucide-react";

/**
 * Full-screen spinner overlay shown during route transitions.
 * Replaces the prior horizontal top progress bar.
 */
export function PageSpinner() {
  const pending = useRouterState({ select: (s) => s.status === "pending" });
  if (!pending) return null;
  return (
    <div
      role="status"
      aria-live="polite"
      aria-label="Loading page"
      className="fixed inset-0 z-[9999] grid place-items-center bg-background/70 backdrop-blur-md animate-in fade-in duration-150"
    >
      <div className="flex flex-col items-center gap-3">
        <div className="relative">
          <div className="absolute inset-0 rounded-full bg-primary/30 blur-2xl animate-pulse" />
          <Loader2 className="relative h-14 w-14 text-primary animate-spin" strokeWidth={2.5} />
        </div>
        <span className="text-xs uppercase tracking-[0.4em] text-primary/80 font-bold">Loading</span>
      </div>
    </div>
  );
}
