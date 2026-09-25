'use server';

import { revalidatePath } from 'next/cache';
import { createClient } from '@/lib/db/server';

export type ApplyState = { status: 'idle' } | { status: 'sent' } | { status: 'error'; message: string };

const MESSAGES: Record<string, string> = {
  not_signed_in: 'A tua sessão terminou. Entra outra vez.',
  already_seller: 'Esta conta já tem uma Uja.',
  already_pending: 'Já tens um pedido em análise.',
  invalid_name: 'Indica o nome do teu negócio.',
  invalid_phone: 'O número de WhatsApp não parece válido.',
  invalid_description: 'Conta-nos o que vendes (até 1000 caracteres).',
  invalid_city: 'A localização tem de ter até 80 caracteres.',
  invalid_avenue: 'Escolhe uma categoria da lista.',
};

export async function submitApplication(_prev: ApplyState, formData: FormData): Promise<ApplyState> {
  const supabase = await createClient();
  const avenue = String(formData.get('avenue_id') ?? '');
  const { error } = await supabase.rpc('monira_submit_application', {
    p_name: String(formData.get('name') ?? ''),
    p_phone: String(formData.get('phone') ?? ''),
    p_description: String(formData.get('description') ?? ''),
    p_avenue_id: avenue || null,
    p_city: String(formData.get('city') ?? ''),
  });
  if (error) {
    const code = Object.keys(MESSAGES).find((c) => error.message.includes(c));
    return { status: 'error', message: code ? MESSAGES[code] : 'Não foi possível enviar. Tenta outra vez.' };
  }
  revalidatePath('/vender');
  revalidatePath('/revisao');
  return { status: 'sent' };
}
