import { NextResponse, type NextRequest } from 'next/server';
import { createClient } from '@/lib/db/server';

// Destino do link de entrada enviado por email.
// Troca o código do link por uma sessão e segue para onde a pessoa ia.
function safeNext(value: string | null) {
  return value && value.startsWith('/') && !value.startsWith('//') ? value : '/painel/produtos/novo';
}

export async function GET(request: NextRequest) {
  const { searchParams, origin } = request.nextUrl;
  const next = safeNext(searchParams.get('next'));
  const code = searchParams.get('code');
  const tokenHash = searchParams.get('token_hash');

  const supabase = await createClient();
  let ok = false;

  if (code) {
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    ok = !error;
  } else if (tokenHash) {
    const { error } = await supabase.auth.verifyOtp({ token_hash: tokenHash, type: 'email' });
    ok = !error;
  }

  if (ok) return NextResponse.redirect(new URL(next, origin));

  const back = new URL('/entrar', origin);
  back.searchParams.set('next', next);
  back.searchParams.set('erro', 'link');
  return NextResponse.redirect(back);
}
