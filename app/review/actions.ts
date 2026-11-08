"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { requireReviewer } from "@/lib/auth";
import { reviewEntry } from "@/lib/entries";
import { EntryWriteError } from "@/lib/save-with-photo";

export async function decideEntry(id: string, decision: string) {
  await requireReviewer();

  // Bound arguments are still untrusted when an action is called directly.
  if (
    typeof id !== "string" ||
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id) ||
    (decision !== "published" && decision !== "returned")
  ) {
    redirect("/review?result=invalid");
  }

  let changed;
  try {
    changed = await reviewEntry(id, decision);
  } catch (cause) {
    if (!(cause instanceof EntryWriteError)) console.error("[review] decision failed:", cause);
    redirect("/review?result=failed");
  }

  if (!changed) redirect("/review?result=unchanged");

  revalidatePath("/review");
  revalidatePath("/");
  revalidatePath(`/entries/${id}`);
  revalidatePath("/my-entries");
  redirect(`/review?result=${decision}`);
}
