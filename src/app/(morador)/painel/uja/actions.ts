'use server';

import { revalidatePath } from 'next/cache';
import { createClient } from '@/lib/db/server';

export type SaveState = { status: 'idle' } | { status: 'saved'; at: number } | { status: 'error'; message: string };

const MESSAGES: Record<string, string> = {
  not_allowed: 'Sem permissão para alterar esta Uja.',
  pickup_address_required: 'Para permitir levantamento, indica a morada.',
  invalid_address: 'A morada e a referência têm de ter até 200 caracteres.',
  invalid_whatsapp: 'O número de WhatsApp não parece válido.',
  invalid_phone: 'O número de telefone não parece válido.',
  whatsapp_required: 'Para mostrar o WhatsApp, indica o número.',
  phone_required: 'Para permitir chamadas, indica o número.',
  invalid_zones: 'Cada zona precisa de nome e de um preço válido.',
  duplicate_zone: 'Há duas zonas com o mesmo nome.',
  zone_required: 'Para permitir entrega, adiciona pelo menos uma zona.',
};

export async function saveUjaSettings(ujaId: string, _prev: SaveState, formData: FormData): Promise<SaveState> {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { status: 'error', message: 'A tua sessão terminou. Entra outra vez.' };

  const on = (name: string) => formData.get(name) === 'on';
  const text = (name: string) => String(formData.get(name) ?? '').trim();

  const settings = {
    is_open: on('is_open'),
    pickup_enabled: on('pickup_enabled'),
    pickup_address: text('pickup_address'),
    pickup_reference: text('pickup_reference'),
    delivery_enabled: on('delivery_enabled'),
    whatsapp: text('whatsapp'),
    whatsapp_public: on('whatsapp_public'),
    phone: text('phone'),
    calls_enabled: on('calls_enabled'),
  };

  const names = formData.getAll('zone_name').map((v) => String(v).trim());
  const fees = formData.getAll('zone_fee').map((v) => String(v).replace(/\D/g, ''));
  const zones = names
    .map((name, i) => ({ name, fee_kz: fees[i] === '' ? null : Number(fees[i]) }))
    .filter((z) => z.name || z.fee_kz !== null);

  // O preço de cada zona fica guardado na Monira; o checkout só envia o id da zona.
  const { error } = await supabase.rpc('monira_save_uja_settings', { p_uja_id: ujaId, p_settings: settings, p_zones: zones });
  if (error) {
    const code = Object.keys(MESSAGES).find((c) => error.message.includes(c));
    return { status: 'error', message: code ? MESSAGES[code] : 'Não foi possível guardar. Tenta outra vez.' };
  }

  revalidatePath('/painel');
  revalidatePath('/painel/uja');
  return { status: 'saved', at: Date.now() };
}
