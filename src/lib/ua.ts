/** Lightweight User-Agent parser for activity logs. No external dep. */
export function parseUA(ua: string | undefined | null): {
  device_type: "mobile" | "tablet" | "desktop" | "bot" | "unknown";
  browser: string;
  os: string;
} {
  const u = (ua || "").toString();
  if (!u) return { device_type: "unknown", browser: "Unknown", os: "Unknown" };
  const isBot = /bot|crawler|spider|crawling/i.test(u);
  const isTablet = /ipad|tablet|playbook|silk|(android(?!.*mobile))/i.test(u);
  const isMobile = !isTablet && /mobile|iphone|ipod|android.*mobile|windows phone|webos|blackberry/i.test(u);
  const device_type = isBot ? "bot" : isTablet ? "tablet" : isMobile ? "mobile" : "desktop";

  let browser = "Unknown";
  if (/edg\//i.test(u)) browser = "Edge";
  else if (/opr\/|opera/i.test(u)) browser = "Opera";
  else if (/chrome\//i.test(u)) browser = "Chrome";
  else if (/firefox\//i.test(u)) browser = "Firefox";
  else if (/safari\//i.test(u)) browser = "Safari";

  let os = "Unknown";
  if (/windows nt/i.test(u)) os = "Windows";
  else if (/mac os x|macintosh/i.test(u)) os = "macOS";
  else if (/android/i.test(u)) os = "Android";
  else if (/iphone|ipad|ipod/i.test(u)) os = "iOS";
  else if (/linux/i.test(u)) os = "Linux";

  return { device_type, browser, os };
}
