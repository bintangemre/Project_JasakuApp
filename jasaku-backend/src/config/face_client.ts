import axios from "axios";
import FormData from "form-data";
import fs from "fs";
import { prisma } from "./prisma";

const FACE_SERVICE_URL = process.env.FACE_SERVICE_URL || "http://127.0.0.1:5001";

export async function compareFaces(
  ktpPath: string,
  selfiePath: string,
): Promise<{ similarity: number; match: boolean }> {
  try {
    const form = new FormData();
    form.append("ktp_image", fs.createReadStream(ktpPath));
    form.append("selfie_image", fs.createReadStream(selfiePath));

    const { data } = await axios.post(`${FACE_SERVICE_URL}/compare`, form, {
      headers: form.getHeaders(),
      timeout: 30_000,
    });

    return {
      similarity: data.similarity ?? 0,
      match: data.match ?? false,
    };
  } catch (err: any) {
    console.warn("Face service unavailable or error:", err.message);
    return { similarity: 0, match: false };
  }
}

export async function runFaceMatchAsync(
  taskProviderId: string,
  ktpPath: string,
  selfiePath: string,
): Promise<void> {
  try {
    const result = await compareFaces(ktpPath, selfiePath);
    await prisma.identity_verifications.update({
      where: { provider_id: taskProviderId },
      data: {
        face_match_score: result.similarity,
        face_match_status: result.match ? "matched" : "not_matched",
      },
    });
  } catch (err) {
    console.error("Face match update failed:", err);
  }
}
