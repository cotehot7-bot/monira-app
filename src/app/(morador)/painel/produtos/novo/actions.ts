'use server';

import { revalidatePath } from 'next/cache';
import { createClient } from '@/lib/db/server';

export type SubmitState =
  | { status: 'idle' }
  | { status: 'done' }
  | { status: 'error'; message: string };

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// Mensagens para quem vende. Os códigos vêm de monira_submit_product (003).
const MESSAGES: Record<string, string> = {
  invalid_name: 'Dá um nome ao produto.',
  invalid_description: 'O texto sobre o produto é demasiado longo.',
  invalid_price: 'Indica um preço válido.',
  invalid_photos: 'Junta entre 1 e 8 fotografias.',
  invalid_options: 'Usa até 12 opções, cada uma com até 40 caracteres.',
};

export async function submitProduct(_prev: SubmitState, formData: FormData): Promise<SubmitState> {
  // Verificar sempre a sessão dentro da acção, mesmo numa página protegida.
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { status: 'error', message: 'A tua sessão terminou. Entra outra vez.' };

  const ujaId = String(formData.get('uja_id') ?? '');
  if (!UUID.test(ujaId)) return { status: 'error', message: 'Não foi possível identificar a tua Uja.' };

  const rawName = String(formData.get('raw_name') ?? '').trim();
  const rawDescription = String(formData.get('raw_description') ?? '').trim();
  const priceDigits = String(formData.get('price') ?? '').replace(/\D/g, '');
  const photos = formData.getAll('photo_path').map(String);
  const options = formData.getAll('option').map(String);

  if (!rawName) return { status: 'error', message: MESSAGES.invalid_name };
  if (!priceDigits || Number(priceDigits) <= 0) return { status: 'error', message: MESSAGES.invalid_price };
  if (photos.length === 0) return { status: 'error', message: MESSAGES.invalid_photos };

  // A base de dados volta a validar tudo e aplica as regras de acesso.
  const { error } = await supabase.rpc('monira_submit_product', {
    p_uja_id: ujaId,
    p_raw_name: rawName,
    p_raw_description: rawDescription || null,
    p_raw_photos: photos,
    p_price_kz: Number(priceDigits),
    p_options: options,
  });

  if (error) {
    const known = Object.keys(MESSAGES).find((code) => error.message.includes(code));
    return { status: 'error', message: known ? MESSAGES[known] : 'Não foi possível publicar. Tenta outra vez.' };
  }

  revalidatePath('/painel');
  return { status: 'done' };
}
