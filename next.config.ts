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
  /*
   * Next refuses a Server Action body over 1 MB by default, and the entry
   * forms post the photo inside that body. 4.25mb is 4 MiB for the photo
   * (MAX_PHOTO_BYTES in lib/photos.ts, and the bucket's limit) plus 256 KiB
   * for the text fields and multipart framing. Vercel applies its own request
   * limit before this one; raising this does not raise that.
   */
  experimental: {
    serverActions: {
      bodySizeLimit: "4.25mb",
    },
  },
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
