import type { Metadata } from 'next';
import Link from 'next/link';
import { redirect } from 'next/navigation';
import { createClient } from '@/lib/db/server';
import { getMyUja } from '@/lib/db/seller';
import { listConversations } from '@/lib/db/conversations';
import { greeting } from '@/lib/greeting';
import { formatKz, photoUrl } from '@/lib/public';
import styles from './painel.module.css';

export const metadata: Metadata = { title: 'Painel · Monira' };

// Estados que quem vende vê. Os estados internos (admin_reviewed, needs_review…) ficam na Monira.
type SellerStatus = 'attention' | 'published' | 'in_review';
const STATUS_LABEL: Record<SellerStatus, string> = {
  attention: 'Precisa de atenção',
  published: 'Publicado',
  in_review: 'Em revisão',
};

type OwnProduct = {
  id: string;
  raw_name: string | null;
  name: string | null;
  price_kz: number;
  raw_photos: string[] | null;
  photos: string[] | null;
  admin_reviewed: boolean;
  attention_note: string | null;
  created_at: string;
};

export default async function PainelPage() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect('/entrar?next=/painel');

  const uja = await getMyUja(supabase, user.id);
  if (!uja) {
    return (
      <main className={styles.screen}>
        <section className={styles.intro}>
          <h1 className={styles.greeting}>{greeting()}.</h1>
          <p className={styles.state}>A tua Uja ainda está a ser preparada.</p>
        </section>
      </main>
    );
  }

  const { data } = await supabase
    .from('monira_products')
    .select('id, raw_name, name, price_kz, raw_photos, photos, admin_reviewed, attention_note, created_at')
    .eq('uja_id', uja.id)
    .eq('active', true)
    .order('created_at', { ascending: false });
  const products = (data ?? []) as OwnProduct[];
  const conversations = await listConversations(supabase, user.id, { ujaId: uja.id });
  const pendingConversations = conversations.filter((c) => !c.lastFromMe).length;

  // Em revisão ainda não há foto pública: mostra-se o original, que só quem vende consegue abrir.
  const rawFirst = products.filter((p) => (!p.admin_reviewed || p.attention_note) && p.raw_photos?.[0]).map((p) => p.raw_photos![0]);
  const { data: signed } = rawFirst.length
    ? await supabase.storage.from('monira-raw').createSignedUrls(rawFirst, 600)
    : { data: [] };
  const signedByPath = new Map((signed ?? []).map((s) => [s.path, s.signedUrl]));

  return (
    <main className={styles.screen}>
      <section className={styles.intro}>
        <h1 className={styles.greeting}>
          {greeting()}, {uja.name}.
          <br />
          A tua Uja está {uja.is_open ? 'aberta' : 'fechada'}.
        </h1>
        <Link href="/painel/produtos/novo" className={styles.add}>
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" aria-hidden="true"><path d="M12 5v14M5 12h14" /></svg>
          Adicionar produto
        </Link>
      </section>

      <Link href="/painel/conversas" className={styles.conversations}>
        <span className={styles.conversationsText}>
          <span className={styles.conversationsTitle}>Conversas</span>
          <span className={styles.conversationsMeta}>
            {pendingConversations ? `${pendingConversations} por responder` : conversations.length ? 'Tudo respondido' : 'Ainda sem conversas'}
          </span>
        </span>
        {pendingConversations > 0 && <span className={styles.badge}>{pendingConversations}</span>}
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#8a8a8a" strokeWidth="1.8" strokeLinecap="round" aria-hidden="true"><path d="M9 6l6 6-6 6" /></svg>
      </Link>

      <Link href="/painel/uja" className={styles.conversations}>
        <span className={styles.conversationsText}>
          <span className={styles.conversationsTitle}>Minha Uja</span>
          <span className={styles.conversationsMeta}>Estado, levantamento, entrega e contactos</span>
        </span>
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#8a8a8a" strokeWidth="1.8" strokeLinecap="round" aria-hidden="true"><path d="M9 6l6 6-6 6" /></svg>
      </Link>

      <section className={styles.products} aria-labelledby="produtos">
        <h2 id="produtos" className={styles.sectionTitle}>Produtos</h2>

        {products.length === 0 ? (
          <p className={styles.empty}>Ainda não tens produtos. Começa por adicionar o primeiro.</p>
        ) : (
          <ul className={styles.list}>
            {products.map((p) => {
              const status: SellerStatus = p.attention_note ? 'attention' : p.admin_reviewed ? 'published' : 'in_review';
              const title = (status === 'published' ? p.name : null) ?? p.raw_name ?? 'Produto';
              const src =
                status === 'published' && p.photos?.[0]
                  ? photoUrl(p.photos[0])
                  : p.raw_photos?.[0] ? signedByPath.get(p.raw_photos[0]) : undefined;

              const content = (
                <>
                  {src ? (
                    // eslint-disable-next-line @next/next/no-img-element -- foto pública tratada ou URL assinado temporário
                    <img src={src} alt="" className={styles.thumb} />
                  ) : (
                    <span className={styles.thumb} />
                  )}
                  <span className={styles.rowText}>
                    <span className={styles.rowTitle}>{title}</span>
                    <span className={styles.rowPrice}>{formatKz(p.price_kz)}</span>
                    <span className={styles[status]}>{STATUS_LABEL[status]}</span>
                    {status === 'attention' && <span className={styles.note}>{p.attention_note}</span>}
                  </span>
                </>
              );

              return (
                <li key={p.id}>
                  {status === 'attention' ? (
                    <Link href={`/painel/produtos/${p.id}/corrigir`} className={styles.row}>
                      {content}
                      <span className={styles.fix}>Corrigir</span>
                    </Link>
                  ) : status === 'published' ? (
                    <Link href={`/produto/${p.id}`} className={styles.row}>
                      {content}
                      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#8a8a8a" strokeWidth="1.8" strokeLinecap="round" aria-hidden="true"><path d="M9 6l6 6-6 6" /></svg>
                    </Link>
                  ) : (
                    <div className={styles.row}>{content}</div>
                  )}
                </li>
              );
            })}
          </ul>
        )}
      </section>

      <p className={styles.footer}>
        <Link href={`/uja/${uja.slug}`}>Ver a minha Uja como os clientes a vêem</Link>
      </p>
    </main>
  );
}
