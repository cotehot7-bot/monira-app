import 'server-only';
import type { SupabaseClient } from '@supabase/supabase-js';

export type ConversationRow = {
  id: string;
  uja_id: string;
  product_id: string | null;
  last_message_at: string | null;
  lastBody: string | null;
  lastFromMe: boolean;
  productName: string | null;
  productPhoto: string | null;
  ujaName: string | null;
};

// Conversas visíveis para quem tem sessão (RLS), com a última mensagem.
// `ujaId` filtra o lado de quem vende; `excludeUjaId` tira as da própria Uja no lado de quem compra.
export async function listConversations(
  supabase: SupabaseClient,
  userId: string,
  filter: { ujaId?: string; excludeUjaId?: string },
): Promise<ConversationRow[]> {
  let q = supabase
    .from('monira_conversations')
    .select('id, uja_id, product_id, last_message_at, messages:monira_messages(body, sender_user_id, created_at)')
    .not('last_message_at', 'is', null)
    .order('last_message_at', { ascending: false })
    .order('created_at', { referencedTable: 'monira_messages', ascending: false })
    .limit(1, { referencedTable: 'monira_messages' })
    .limit(100);
  if (filter.ujaId) q = q.eq('uja_id', filter.ujaId);
  if (filter.excludeUjaId) q = q.neq('uja_id', filter.excludeUjaId);

  const { data } = await q;
  const rows = data ?? [];

  const productIds = [...new Set(rows.map((r) => r.product_id).filter(Boolean))] as string[];
  const ujaIds = [...new Set(rows.map((r) => r.uja_id))];
  const [{ data: products }, { data: ujas }] = await Promise.all([
    productIds.length
      ? supabase.from('monira_public_products').select('id, name, photos').in('id', productIds)
      : Promise.resolve({ data: [] as { id: string; name: string | null; photos: string[] | null }[] }),
    supabase.from('monira_public_ujas').select('id, name').in('id', ujaIds),
  ]);
  const productById = new Map((products ?? []).map((p) => [p.id, p]));
  const ujaById = new Map((ujas ?? []).map((u) => [u.id, u.name as string]));

  return rows.map((r) => {
    const last = (r.messages as { body: string; sender_user_id: string }[] | null)?.[0];
    const product = r.product_id ? productById.get(r.product_id) : undefined;
    return {
      id: r.id,
      uja_id: r.uja_id,
      product_id: r.product_id,
      last_message_at: r.last_message_at,
      lastBody: last?.body ?? null,
      lastFromMe: last?.sender_user_id === userId,
      productName: product?.name ?? null,
      productPhoto: product?.photos?.[0] ?? null,
      ujaName: ujaById.get(r.uja_id) ?? null,
    };
  });
}
