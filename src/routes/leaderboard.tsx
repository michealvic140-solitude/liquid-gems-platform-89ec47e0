import { createFileRoute } from "@tanstack/react-router";
import { useEffect, useMemo, useState } from "react";
import { Layout } from "@/components/Layout";
import { Card } from "@/components/ui/card";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Trophy, Upload, X } from "lucide-react";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/contexts/AuthContext";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { toast } from "sonner";
import { resolveStorageUrl } from "@/lib/storage-media";

export const Route = createFileRoute("/leaderboard")({
  head: () => ({
    meta: [
      { title: "Leaderboard — Lomita Shooters League" },
      { name: "description", content: "See the top shooters and top gangs ranked by season points, wins, and tokens won across the Lomita Shooters League." },
      { property: "og:title", content: "LSL Leaderboard — Top Shooters & Gangs" },
      { property: "og:description", content: "Top shooters and gangs ranked by season points, wins, and tokens won." },
      { property: "og:url", content: "https://lslonlinebetting.lovable.app/leaderboard" },
    ],
    links: [{ rel: "canonical", href: "https://lslonlinebetting.lovable.app/leaderboard" }],
    scripts: [{
      type: "application/ld+json",
      children: JSON.stringify({
        "@context": "https://schema.org",
        "@type": "CollectionPage",
        name: "LSL Leaderboard",
        description: "Top shooters and gangs in the Lomita Shooters League.",
        url: "https://lslonlinebetting.lovable.app/leaderboard",
      }),
    }],
  }),
  component: Page,
});

function rankIcon(i: number) {
  if (i === 0) return "🥇"; if (i === 1) return "🥈"; if (i === 2) return "🥉";
  return `#${i + 1}`;
}

type Stats = { name: string; top_player?: string; W: number; L: number; D: number; PTS: number; P: number; manual_rank?: number | null };

function Page() {
  const [shooters, setShooters] = useState<Stats[]>([]);
  const [gangs, setGangs] = useState<Stats[]>([]);
  const { isAdmin } = useAuth();
  const [bannerUrl, setBannerUrl] = useState<string | null>(null);
  const [bannerDescription, setBannerDescription] = useState<string>("");
  const [bannerSigned, setBannerSigned] = useState<string | null>(null);
  const [editing, setEditing] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [draftDesc, setDraftDesc] = useState("");

  const loadBanner = async () => {
    const { data } = await supabase
      .from("app_settings")
      .select("leaderboard_banner_url,leaderboard_banner_description")
      .eq("id", 1)
      .maybeSingle();
    const url = (data as any)?.leaderboard_banner_url ?? null;
    const desc = (data as any)?.leaderboard_banner_description ?? "";
    setBannerUrl(url);
    setBannerDescription(desc);
    setDraftDesc(desc);
    if (url) {
      const signed = await resolveStorageUrl("highlights", url);
      setBannerSigned(signed ?? url);
    } else {
      setBannerSigned(null);
    }
  };

  useEffect(() => { loadBanner(); }, []);

  async function uploadBanner(file: File) {
    setUploading(true);
    try {
      const ext = file.name.split(".").pop() || "jpg";
      const path = `leaderboard/banner-${Date.now()}.${ext}`;
      const { error: upErr } = await supabase.storage.from("highlights").upload(path, file, { upsert: true, contentType: file.type });
      if (upErr) throw upErr;
      const { error: dbErr } = await (supabase as any).from("app_settings")
        .update({ leaderboard_banner_url: path, leaderboard_banner_description: draftDesc })
        .eq("id", 1);
      if (dbErr) throw dbErr;
      toast.success("Leaderboard banner updated");
      setEditing(false);
      await loadBanner();
    } catch (e: any) {
      toast.error(e?.message ?? "Upload failed");
    } finally { setUploading(false); }
  }

  async function saveDescription() {
    const { error } = await (supabase as any).from("app_settings")
      .update({ leaderboard_banner_description: draftDesc })
      .eq("id", 1);
    if (error) { toast.error(error.message); return; }
    toast.success("Description saved");
    setEditing(false);
    await loadBanner();
  }

  async function removeBanner() {
    const { error } = await (supabase as any).from("app_settings")
      .update({ leaderboard_banner_url: null, leaderboard_banner_description: null })
      .eq("id", 1);
    if (error) { toast.error(error.message); return; }
    toast.success("Banner removed");
    await loadBanner();
  }

  useEffect(() => {
    (async () => {
      // matches finished
      const { data: matches } = await supabase
        .from("matches")
        .select("home_team_id,away_team_id,home_score,away_score,winner_team_id,status,is_virtual")
        .eq("status", "ended")
        .eq("is_virtual", false);
      const { data: teams } = await supabase.from("teams").select("id,name");
      const { data: players } = await supabase.from("players").select("id,name,team_id");
      const { data: overrides } = await supabase.from("leaderboard_overrides").select("*");

      const teamMap = new Map<string, string>(); (teams ?? []).forEach((t) => teamMap.set(t.id, t.name));
      const teamPlayers = new Map<string, string[]>();
      (players ?? []).forEach((p) => { if (!p.team_id) return; const a = teamPlayers.get(p.team_id) ?? []; a.push(p.name); teamPlayers.set(p.team_id, a); });

      const gangAgg = new Map<string, Stats>();
      const playerAgg = new Map<string, Stats>();

      (matches ?? []).forEach((m: any) => {
        for (const side of ["home", "away"] as const) {
          const tid = side === "home" ? m.home_team_id : m.away_team_id;
          const tname = teamMap.get(tid) || "Team";
          const won = m.winner_team_id === tid;
          const draw = m.winner_team_id == null;
          const cur = gangAgg.get(tname) ?? { name: tname, top_player: (teamPlayers.get(tid) ?? [])[0], W: 0, L: 0, D: 0, PTS: 0, P: 0 };
          cur.P += 1;
          if (draw) { cur.D += 1; cur.PTS += 1; }
          else if (won) { cur.W += 1; cur.PTS += 3; }
          else { cur.L += 1; }
          gangAgg.set(tname, cur);
          // shooters: each player on team
          (teamPlayers.get(tid) ?? []).forEach((pname) => {
            const pc = playerAgg.get(pname) ?? { name: pname, W: 0, L: 0, D: 0, PTS: 0, P: 0 };
            pc.P += 1;
            if (draw) { pc.D += 1; pc.PTS += 1; }
            else if (won) { pc.W += 1; pc.PTS += 3; }
            else { pc.L += 1; }
            playerAgg.set(pname, pc);
          });
        }
      });

      // apply overrides
      (overrides ?? []).forEach((o: any) => {
        const target = o.kind === "gang" ? gangAgg : playerAgg;
        target.set(o.name, {
          name: o.name, top_player: o.top_player ?? undefined,
          W: o.wins, L: o.losses, D: o.draws, P: o.played, PTS: o.points,
          manual_rank: o.manual_rank,
        });
      });

      const sortFn = (a: Stats, b: Stats) => {
        if (a.manual_rank != null && b.manual_rank != null) return a.manual_rank - b.manual_rank;
        if (a.manual_rank != null) return -1;
        if (b.manual_rank != null) return 1;
        return b.PTS - a.PTS || b.W - a.W;
      };
      setGangs(Array.from(gangAgg.values()).sort(sortFn));
      setShooters(Array.from(playerAgg.values()).sort(sortFn));
    })();
  }, []);

  return (
    <Layout>
      <div className="container py-10">
        {(bannerSigned || isAdmin) && (
          <Card className="glass-strong overflow-hidden mb-6 border-primary/30">
            {bannerSigned ? (
              <div className="relative w-full">
                <img src={bannerSigned} alt={bannerDescription || "Leaderboard banner"} className="w-full max-h-[420px] object-cover" />
                <div className="absolute inset-x-0 bottom-0 bg-gradient-to-t from-background/90 via-background/60 to-transparent p-4 sm:p-6">
                  {bannerDescription && <p className="text-sm sm:text-base text-foreground/90 max-w-3xl drop-shadow">{bannerDescription}</p>}
                </div>
                {isAdmin && (
                  <div className="absolute top-2 right-2 flex gap-2">
                    <Button size="sm" variant="secondary" onClick={() => setEditing((v) => !v)}>{editing ? "Close" : "Edit"}</Button>
                    <Button size="sm" variant="destructive" onClick={removeBanner}><X className="h-3 w-3 mr-1" />Remove</Button>
                  </div>
                )}
              </div>
            ) : (
              isAdmin && (
                <div className="p-6 text-center text-sm text-muted-foreground">
                  No leaderboard banner yet — upload one below to feature it at the top of this page.
                </div>
              )
            )}
            {isAdmin && (editing || !bannerSigned) && (
              <div className="p-4 space-y-3 border-t border-border/40 bg-card/30">
                <Textarea
                  placeholder="Banner description (visible to everyone)…"
                  value={draftDesc}
                  onChange={(e) => setDraftDesc(e.target.value)}
                  className="min-h-[80px]"
                />
                <div className="flex flex-wrap gap-2">
                  <label className="inline-flex">
                    <input type="file" accept="image/*" hidden disabled={uploading} onChange={(e) => { const f = e.target.files?.[0]; if (f) uploadBanner(f); }} />
                    <span className={`inline-flex items-center gap-1 px-3 py-2 rounded-md text-xs font-bold cursor-pointer btn-luxury ${uploading ? "opacity-60 pointer-events-none" : ""}`}>
                      <Upload className="h-3.5 w-3.5" />{uploading ? "Uploading…" : (bannerSigned ? "Replace banner" : "Upload banner")}
                    </span>
                  </label>
                  {bannerSigned && <Button size="sm" variant="outline" onClick={saveDescription}>Save description</Button>}
                </div>
              </div>
            )}
          </Card>
        )}
        <div className="flex items-center gap-2 mb-6">
          <Trophy className="h-7 w-7 text-primary" />
          <h1 className="text-3xl font-bold gradient-gold-text">Leaderboard</h1>
        </div>
        <Tabs defaultValue="gangs">
          <TabsList>
            <TabsTrigger value="gangs">Top Gangs / Factions</TabsTrigger>
            <TabsTrigger value="shooters">Top Shooters</TabsTrigger>
          </TabsList>

          <TabsContent value="gangs" className="mt-4">
            <Card className="glass overflow-x-auto">
              <table className="w-full text-sm">
                <thead className="border-b border-border bg-card/40">
                  <tr className="text-left text-xs uppercase tracking-widest text-muted-foreground">
                    <Th>Rank</Th><Th>Gang / Faction</Th><Th>Top Player</Th>
                    <Th right>W</Th><Th right>L</Th><Th right>D</Th><Th right>P</Th><Th right>PTS</Th>
                  </tr>
                </thead>
                <tbody>
                  {gangs.length === 0 && <tr><td colSpan={8} className="p-6 text-center text-muted-foreground">No data yet.</td></tr>}
                  {gangs.map((g, i) => (
                    <tr key={g.name} className="border-b border-border/40 hover:bg-primary/5">
                      <Td><span className="text-lg font-bold">{rankIcon(i)}</span></Td>
                      <Td><span className="font-bold">{g.name}</span></Td>
                      <Td><span className="text-muted-foreground">{g.top_player || "—"}</span></Td>
                      <Td right><span className="text-emerald-400 font-bold">{g.W}</span></Td>
                      <Td right><span className="text-destructive font-bold">{g.L}</span></Td>
                      <Td right><span className="text-amber-400 font-bold">{g.D}</span></Td>
                      <Td right>{g.P}</Td>
                      <Td right><span className="font-bold text-primary">{g.PTS}</span></Td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </Card>
          </TabsContent>

          <TabsContent value="shooters" className="mt-4">
            <Card className="glass overflow-x-auto">
              <table className="w-full text-sm">
                <thead className="border-b border-border bg-card/40">
                  <tr className="text-left text-xs uppercase tracking-widest text-muted-foreground">
                    <Th>Rank</Th><Th>Player</Th>
                    <Th right>Won</Th><Th right>Lost</Th><Th right>Total</Th><Th right>PTS</Th>
                  </tr>
                </thead>
                <tbody>
                  {shooters.length === 0 && <tr><td colSpan={6} className="p-6 text-center text-muted-foreground">No shooters yet.</td></tr>}
                  {shooters.map((p, i) => (
                    <tr key={p.name} className="border-b border-border/40 hover:bg-primary/5">
                      <Td><span className="text-lg font-bold">{rankIcon(i)}</span></Td>
                      <Td><span className="font-bold">{p.name}</span></Td>
                      <Td right><span className="text-emerald-400 font-bold">{p.W}</span></Td>
                      <Td right><span className="text-destructive font-bold">{p.L}</span></Td>
                      <Td right>{p.P}</Td>
                      <Td right><span className="font-bold text-primary">{p.PTS}</span></Td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </Card>
          </TabsContent>
        </Tabs>
      </div>
    </Layout>
  );
}

function Th({ children, right }: { children: React.ReactNode; right?: boolean }) { return <th className={`px-4 py-3 ${right ? "text-right" : ""}`}>{children}</th>; }
function Td({ children, right }: { children: React.ReactNode; right?: boolean }) { return <td className={`px-4 py-3 ${right ? "text-right" : ""}`}>{children}</td>; }
