import { useEffect, useRef } from "react";
import { supabase } from "@/integrations/supabase/client";

/**
 * Listens to public.app_settings.force_reload_at. When the value changes
 * (and isn't the initial value snapshot taken on mount), every active
 * browser session reloads the page. Wired in src/routes/__root.tsx.
 */
export function ReloadBroadcastListener() {
  const baseline = useRef<string | null>(null);
  useEffect(() => {
    let mounted = true;
    (async () => {
      const { data } = await supabase
        .from("app_settings")
        .select("force_reload_at")
        .eq("id", 1)
        .maybeSingle();
      if (mounted) baseline.current = (data as any)?.force_reload_at ?? null;
    })();

    const ch = supabase
      .channel("force-reload-broadcast")
      .on(
        "postgres_changes",
        { event: "UPDATE", schema: "public", table: "app_settings", filter: "id=eq.1" },
        (payload: any) => {
          const next = payload?.new?.force_reload_at ?? null;
          if (!next) return;
          if (baseline.current && next === baseline.current) return;
          baseline.current = next;
          if (typeof window !== "undefined") window.location.reload();
        }
      )
      .subscribe();

    return () => {
      mounted = false;
      supabase.removeChannel(ch);
    };
  }, []);
  return null;
}