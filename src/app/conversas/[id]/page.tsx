import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound, redirect } from 'next/navigation';
import { createClient } from '@/lib/db/server';
import { getMyUja } from '@/lib/db/seller';
import { formatKz, photoUrl } from '@/lib/public';
import { VerifiedMark } from '../../_components/ProductGrid';
import Composer from './Composer';
import LiveUpdates from './LiveUpdates';
import styles from './conversa.module.css';

export const metadata: Metadata = { title: 'Conversa · Monira' };

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function time(iso: string) {
  return new Intl.DateTimeFormat('pt-PT', { hour: '2-digit', minute: '2-digit', timeZone: 'Africa/Luanda' }).format(new Date(iso));
}

// Uma só conversa, vista de dois lados: quem compra e quem vende.
export default async function ConversaPage(props: PageProps<'/conversas/[id]'>) {
  const { id } = await props.params;
  if (!UUID.test(id)) notFound();

  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/entrar?next=/conversas/${id}`);

  // RLS: só as duas partes vêem a conversa.
  const { data: conv } = await supabase
    .from('monira_conversations')
    .select('id, uja_id, product_id')
    .eq('id', id)
    .maybeSingle();
  if (!conv) notFound();

  const myUja = await getMyUja(supabase, user.id);
  const iSell = myUja?.id === conv.uja_id;

  const [{ data: uja }, { data: product }, { data: messages }] = await Promise.all([
    supabase.from('monira_public_ujas').select('name, slug, verified, whatsapp, phone').eq('id', conv.uja_id).maybeSingle(),
    conv.product_id
      ? supabase.from('monira_public_products').select('id, name, photos, price_kz').eq('id', conv.product_id).maybeSingle()
      : Promise.resolve({ data: null }),
    supabase.from('monira_messages').select('id, sender_user_id, body, created_at').eq('conversation_id', id).order('created_at').limit(300),
  ]);

  const list = messages ?? [];
  const productName = product?.name as string | undefined;
  const whatsappDigits = uja?.whatsapp ? String(uja.whatsapp).replace(/\D/g, '') : '';
  const whatsappText = encodeURIComponent(`Olá, venho da Monira.${productName ? ` Estou interessado no ${productName}.` : ''}`);

  return (
    <main className={styles.screen}>
      <header className={styles.header}>
        <Link href={iSell ? '/painel/conversas' : '/conversas'} className={styles.back}>← Conversas</Link>
        {iSell ? (
          <h1 className={styles.title}>Cliente</h1>
        ) : (
          <h1 className={styles.title}>
            <Link href={`/uja/${uja?.slug ?? ''}`}>{uja?.name ?? 'Uja'}</Link>
            {uja?.verified && <VerifiedMark size={17} />}
          </h1>
        )}

        {product && (
          <Link href={`/produto/${product.id}`} className={styles.product}>
            {product.photos?.[0] && (
              // eslint-disable-next-line @next/next/no-img-element -- fotografia já tratada pela Monira
              <img src={photoUrl(product.photos[0])} alt="" className={styles.productPhoto} />
            )}
            <span className={styles.productText}>
              <span className={styles.productLabel}>Sobre</span>
              <span className={styles.productName}>{product.name}</span>
              <span className={styles.productPrice}>{formatKz(product.price_kz)}</span>
            </span>
          </Link>
        )}
      </header>

      <section className={styles.messages} aria-label="Mensagens" aria-live="polite">
        {list.length === 0 && (
          <p className={styles.empty}>{iSell ? 'Ainda sem mensagens.' : 'Escreve a tua pergunta. A Uja responde aqui.'}</p>
        )}
        {list.map((m) => {
          const mine = m.sender_user_id === user.id;
          return (
            <div key={m.id} className={mine ? styles.mine : styles.theirs}>
              <p className={styles.body}>{m.body}</p>
              <time className={styles.time} dateTime={m.created_at}>{time(m.created_at)}</time>
            </div>
          );
        })}
        <div id="fim" />
      </section>

      <footer className={styles.footer}>
        {!iSell && (whatsappDigits || uja?.phone) && (
          <div className={styles.extensions}>
            {whatsappDigits && <a href={`https://wa.me/${whatsappDigits}?text=${whatsappText}`} target="_blank" rel="noopener noreferrer">Continuar no WhatsApp</a>}
            {uja?.phone && <a href={`tel:${String(uja.phone).replace(/[^\d+]/g, '')}`}>Ligar</a>}
          </div>
        )}
        <Composer conversationId={id} />
      </footer>

      <LiveUpdates count={list.length} />
    </main>
  );
}
