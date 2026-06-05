import { supabase } from "@/integrations/supabase/client";

export function storagePathFromUrl(value: string | null | undefined, bucket: string) {
  if (!value) return null;
  const raw = value.trim();
  if (!raw) return null;
  const publicMarker = `/storage/v1/object/public/${bucket}/`;
  const signedMarker = `/storage/v1/object/sign/${bucket}/`;
  const marker = raw.includes(publicMarker) ? publicMarker : raw.includes(signedMarker) ? signedMarker : null;
  if (!marker) return raw.includes("://") ? null : raw.replace(/^\/+/, "");
  return decodeURIComponent(raw.split(marker)[1]?.split("?")[0] ?? "");
}

export async function resolveStorageUrl(bucket: string, value: string | null | undefined) {
  if (!value) return null;
  const path = storagePathFromUrl(value, bucket);
  if (!path) return value;
  const { data, error } = await supabase.storage.from(bucket).createSignedUrl(path, 60 * 60);
  return error ? value : data.signedUrl;
}

export async function withResolvedMedia<T extends Record<string, any>>(rows: T[], bucket: string, sourceKey: keyof T, outputKey: string) {
  return Promise.all(rows.map(async (row) => ({ ...row, [outputKey]: await resolveStorageUrl(bucket, row[sourceKey] as string | null | undefined) })));
}