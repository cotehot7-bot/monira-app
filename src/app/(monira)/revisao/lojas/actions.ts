'use server';

import { revalidatePath } from 'next/cache';
import { createClient } from '@/lib/db/server';
import { sendNotificationEmail } from '@/lib/notify';
import type { SupabaseClient } from '@supabase/supabase-js';

async function notifyApplicant(supabase: SupabaseClient, applicationId: string) {
  const { data } = await supabase.rpc('monira_application_notification', { p_application_id: applicationId });
  const n = Array.isArray(data) ? data[0] : null;
  if (!n?.email) return;
  if (n.status === 'aprovado') sendNotificationEmail({ kind: 'application_approved', to: n.email, ujaName: n.uja_name });
  else sendNotificationEmail({ kind: 'application_rejected', to: n.email, note: n.note });
}

export type DecisionState = { status: 'idle' } | { status: 'done'; message: string } | { status: 'error'; message: string };

const MESSAGES: Record<string, string> = {
  not_allowed: 'Sem permissão.',
  application_not_found: 'Este pedido já não existe.',
  not_pending: 'Este pedido já foi decidido.',
  already_seller: 'Esta conta já tem uma Uja.',
  invalid_name: 'Dá um nome à Uja (2 a 80 caracteres).',
  invalid_avenue: 'Escolhe a categoria.',
  invalid_note: 'Escreve uma nota para quem pediu (até 500 caracteres).',
};
const known = (m: string) => Object.keys(MESSAGES).find((c) => m.includes(c));

export async function approveApplication(applicationId: string, _prev: DecisionState, formData: FormData): Promise<DecisionState> {
  const supabase = await createClient();
  const { data: slug, error } = await supabase.rpc('monira_admin_approve_application', {
    p_application_id: applicationId,
    p_uja_name: String(formData.get('uja_name') ?? ''),
    p_avenue_id: String(formData.get('avenue_id') ?? '') || null,
    p_verified: formData.get('verified') === 'on',
  });
  if (error) { const c = known(error.message); return { status: 'error', message: c ? MESSAGES[c] : 'Não foi possível aprovar.' }; }
  await notifyApplicant(supabase, applicationId);
  revalidatePath('/revisao');
  revalidatePath('/revisao/lojas');
  return { status: 'done', message: `Aprovado. Uja criada em /uja/${slug} (fechada até quem vende a abrir).` };
}

export async function rejectApplication(applicationId: string, _prev: DecisionState, formData: FormData): Promise<DecisionState> {
  const supabase = await createClient();
  const { error } = await supabase.rpc('monira_admin_reject_application', {
    p_application_id: applicationId,
    p_note: String(formData.get('note') ?? ''),
  });
  if (error) { const c = known(error.message); return { status: 'error', message: c ? MESSAGES[c] : 'Não foi possível recusar.' }; }
  await notifyApplicant(supabase, applicationId);
  revalidatePath('/revisao');
  revalidatePath('/revisao/lojas');
  return { status: 'done', message: 'Recusado. Quem pediu vê a tua nota e pode pedir outra vez.' };
}
