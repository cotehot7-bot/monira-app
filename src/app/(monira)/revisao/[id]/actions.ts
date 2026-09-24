'use server';

import sharp from 'sharp';
import { redirect } from 'next/navigation';
import { revalidatePath } from 'next/cache';
import { createClient } from '@/lib/db/server';

export type PublishState = { status: 'idle' } | { status: 'error'; message: string };

const MESSAGES: Record<string, string> = {
  not_allowed: 'Sem permissão para publicar.',
  invalid_name: 'Dá um nome ao produto (até 120 caracteres).',
  invalid_description: 'A descrição tem de ter até 1000 caracteres.',
  invalid_photos: 'Escolhe entre 1 e 8 fotografias.',
  product_not_found: 'Este produto já não existe.',
};

// A Monira trata a fotografia antes de a tornar pública:
// endireita (EXIF), limita a 1600 px, converte para JPEG e retira os metadados (incluindo GPS).
async function treat(input: ArrayBuffer) {
  return sharp(Buffer.from(input))
    .rotate()
    .resize({ width: 1600, height: 1600, fit: 'inside', withoutEnlargement: true })
    .jpeg({ quality: 82, mozjpeg: true })
    .toBuffer();
}

export async function publishProduct(productId: string, _prev: PublishState, formData: FormData): Promise<PublishState> {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { status: 'error', message: 'A tua sessão terminou. Entra outra vez.' };
  const { data: isAdmin } = await supabase.rpc('monira_is_admin');
  if (!isAdmin) return { status: 'error', message: MESSAGES.not_allowed };

  const name = String(formData.get('name') ?? '').trim();
  const description = String(formData.get('description') ?? '').trim();
  const chosen = formData.getAll('photo').map(String);
  if (!name) return { status: 'error', message: MESSAGES.invalid_name };
  if (chosen.length === 0) return { status: 'error', message: MESSAGES.invalid_photos };

  // Só aceita fotografias que pertencem mesmo a este produto.
  const { data: product } = await supabase.from('monira_products').select('raw_photos').eq('id', productId).maybeSingle();
  if (!product) return { status: 'error', message: MESSAGES.product_not_found };
  const allowed = new Set(product.raw_photos ?? []);
  const photos = chosen.filter((p) => allowed.has(p));
  if (photos.length === 0 || photos.length > 8) return { status: 'error', message: MESSAGES.invalid_photos };

  const published: string[] = [];
  for (const [i, rawPath] of photos.entries()) {
    const { data: blob, error: downloadError } = await supabase.storage.from('monira-raw').download(rawPath);
    if (downloadError || !blob) return { status: 'error', message: 'Não foi possível ler uma das fotografias originais.' };

    let jpeg: Buffer;
    try {
      jpeg = await treat(await blob.arrayBuffer());
    } catch {
      return { status: 'error', message: 'Uma das fotografias está num formato que ainda não conseguimos tratar. Pede a quem vende que a envie outra vez.' };
    }

    const target = `products/${productId}/${i + 1}.jpg`;
    const { error: uploadError } = await supabase.storage
      .from('monira-public')
      .upload(target, jpeg, { contentType: 'image/jpeg', upsert: true });
    if (uploadError) return { status: 'error', message: 'Não foi possível guardar a fotografia tratada.' };
    published.push(target);
  }

  const { error } = await supabase.rpc('monira_admin_publish_product', {
    p_product_id: productId,
    p_name: name,
    p_description: description || null,
    p_photos: published,
  });
  if (error) {
    const known = Object.keys(MESSAGES).find((code) => error.message.includes(code));
    return { status: 'error', message: known ? MESSAGES[known] : 'Não foi possível publicar. Tenta outra vez.' };
  }

  revalidatePath('/revisao');
  revalidatePath('/');
  redirect('/revisao?publicado=1');
}
