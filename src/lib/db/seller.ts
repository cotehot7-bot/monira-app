import 'server-only';
import type { SupabaseClient } from '@supabase/supabase-js';

// A Uja de quem tem sessão, pela sua conta de quem vende.
// Nunca "a primeira Uja que consigo ler": um admin consegue ler todas.
export async function getMyUja(supabase: SupabaseClient, userId: string) {
  const { data: vendor } = await supabase.from('monira_vendors').select('id, name').eq('user_id', userId).maybeSingle();
  if (!vendor) return null;

  const { data: uja } = await supabase
    .from('monira_ujas')
    .select('id, name, slug, is_open')
    .eq('vendor_id', vendor.id)
    .order('created_at')
    .limit(1)
    .maybeSingle();
  return uja as { id: string; name: string; slug: string; is_open: boolean } | null;
}
