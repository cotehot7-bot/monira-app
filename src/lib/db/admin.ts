import 'server-only';
import { notFound, redirect } from 'next/navigation';
import { createClient } from './server';

// Só a Monira entra na revisão. Quem não é admin vê "página não encontrada".
// A base de dados volta a verificar em cada leitura e em cada publicação.
export async function requireAdmin(nextPath: string) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/entrar?next=${encodeURIComponent(nextPath)}`);

  const { data: isAdmin } = await supabase.rpc('monira_is_admin');
  if (!isAdmin) notFound();

  return supabase;
}
