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
  not_editable: 'Este produto já foi enviado de novo e está em revisão.',
  product_not_found: 'Este produto já não existe.',
};

function readForm(formData: FormData) {
  return {
    rawName: String(formData.get('raw_name') ?? '').trim(),
    rawDescription: String(formData.get('raw_description') ?? '').trim(),
    priceDigits: String(formData.get('price') ?? '').replace(/\D/g, ''),
    photos: formData.getAll('photo_path').map(String),
    options: formData.getAll('option').map(String),
  };
}

function checkForm(f: ReturnType<typeof readForm>): SubmitState | null {
  if (!f.rawName) return { status: 'error', message: MESSAGES.invalid_name };
  if (!f.priceDigits || Number(f.priceDigits) <= 0) return { status: 'error', message: MESSAGES.invalid_price };
  if (f.photos.length === 0) return { status: 'error', message: MESSAGES.invalid_photos };
  return null;
}

function toMessage(message: string, fallback: string): SubmitState {
  const known = Object.keys(MESSAGES).find((code) => message.includes(code));
  return { status: 'error', message: known ? MESSAGES[known] : fallback };
}

export async function submitProduct(_prev: SubmitState, formData: FormData): Promise<SubmitState> {
  // Verificar sempre a sessão dentro da acção, mesmo numa página protegida.
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { status: 'error', message: 'A tua sessão terminou. Entra outra vez.' };

  const ujaId = String(formData.get('uja_id') ?? '');
  if (!UUID.test(ujaId)) return { status: 'error', message: 'Não foi possível identificar a tua Uja.' };

  const f = readForm(formData);
  const invalid = checkForm(f);
  if (invalid) return invalid;

  // A base de dados volta a validar tudo e aplica as regras de acesso.
  const { error } = await supabase.rpc('monira_submit_product', {
    p_uja_id: ujaId,
    p_raw_name: f.rawName,
    p_raw_description: f.rawDescription || null,
    p_raw_photos: f.photos,
    p_price_kz: Number(f.priceDigits),
    p_options: f.options,
  });
  if (error) return toMessage(error.message, 'Não foi possível publicar. Tenta outra vez.');

  revalidatePath('/painel');
  return { status: 'done' };
}

// Responder a "Precisa de atenção": corrigir e enviar de novo. Volta a "Em revisão".
export async function resubmitProduct(productId: string, _prev: SubmitState, formData: FormData): Promise<SubmitState> {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { status: 'error', message: 'A tua sessão terminou. Entra outra vez.' };
  if (!UUID.test(productId)) return { status: 'error', message: MESSAGES.product_not_found };

  const f = readForm(formData);
  const invalid = checkForm(f);
  if (invalid) return invalid;

  const { error } = await supabase.rpc('monira_resubmit_product', {
    p_product_id: productId,
    p_raw_name: f.rawName,
    p_raw_description: f.rawDescription || null,
    p_raw_photos: f.photos,
    p_price_kz: Number(f.priceDigits),
    p_options: f.options,
  });
  if (error) return toMessage(error.message, 'Não foi possível enviar. Tenta outra vez.');

  revalidatePath('/painel');
  return { status: 'done' };
}
