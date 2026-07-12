import { supabase } from '../config/supabase';
import path from 'path';

const BUCKET = 'jasaku-uploads';

export async function uploadToStorage(
  buffer: Buffer,
  folder: string,
  originalName: string,
): Promise<string> {
  const ext = path.extname(originalName).toLowerCase();
  const filename = `${folder}/${Date.now()}-${Math.round(Math.random() * 1e9)}${ext}`;

  const { error } = await supabase.storage
    .from(BUCKET)
    .upload(filename, buffer, {
      contentType: getMimeType(ext),
      upsert: false,
    });

  if (error) {
    throw new Error(`Storage upload failed: ${error.message}`);
  }

  const { data: urlData } = supabase.storage
    .from(BUCKET)
    .getPublicUrl(filename);

  return urlData.publicUrl;
}

export async function deleteFromStorage(fileUrl: string): Promise<void> {
  const filePath = extractPath(fileUrl);
  if (!filePath) return;

  await supabase.storage
    .from(BUCKET)
    .remove([filePath]);
}

function extractPath(url: string): string | null {
  const marker = `${BUCKET}/`;
  const idx = url.indexOf(marker);
  if (idx === -1) return null;
  return url.substring(idx + marker.length);
}

function getMimeType(ext: string): string {
  const map: Record<string, string> = {
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.png': 'image/png',
    '.pdf': 'application/pdf',
  };
  return map[ext] || 'application/octet-stream';
}
