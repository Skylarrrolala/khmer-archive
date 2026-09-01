import type { NextConfig } from "next";

/**
 * next/image refuses to optimise a remote image unless its host is listed
 * here. That allowlist is a security control: without it, anyone could point
 * /_next/image at any URL on the internet and use the deployment as a free
 * image proxy.
 *
 * Entry photos live in Supabase Storage, whose public URLs look like:
 *   https://<project-ref>.supabase.co/storage/v1/object/public/entry-photos/...
 *
 * The host is derived from NEXT_PUBLIC_SUPABASE_URL rather than hardcoded, so
 * the same code works locally and on Vercel without editing this file. If the
 * variable is missing (e.g. a build with no env set), the list is simply
 * empty — local images in /public still work.
 */
const supabaseHost = process.env.NEXT_PUBLIC_SUPABASE_URL
  ? new URL(process.env.NEXT_PUBLIC_SUPABASE_URL).hostname
  : undefined;

const nextConfig: NextConfig = {
  images: {
    remotePatterns: supabaseHost
      ? [
          {
            protocol: "https",
            hostname: supabaseHost,
            pathname: "/storage/v1/object/public/**",
          },
        ]
      : [],
  },
};

export default nextConfig;
