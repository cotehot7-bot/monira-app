import Link from 'next/link';
import type { ConversationRow } from '@/lib/db/conversations';
import { photoUrl } from '@/lib/public';
import styles from './ConversationList.module.css';

function when(iso: string | null) {
  if (!iso) return '';
  return new Intl.DateTimeFormat('pt-PT', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit', timeZone: 'Africa/Luanda' }).format(new Date(iso));
}

// `side`: quem vende vê "Cliente" e o que está por responder; quem compra vê o nome da Uja.
export default function ConversationList({ rows, side }: { rows: ConversationRow[]; side: 'seller' | 'buyer' }) {
  return (
    <ul className={styles.list}>
      {rows.map((c) => {
        const pending = side === 'seller' && !c.lastFromMe;
        return (
          <li key={c.id}>
            <Link href={`/conversas/${c.id}`} className={styles.row}>
              {c.productPhoto ? (
                // eslint-disable-next-line @next/next/no-img-element -- fotografia já tratada pela Monira
                <img src={photoUrl(c.productPhoto)} alt="" className={styles.thumb} />
              ) : (
                <span className={styles.thumb} />
              )}
              <span className={styles.text}>
                <span className={styles.top}>
                  <span className={pending ? styles.whoPending : styles.who}>{side === 'seller' ? 'Cliente' : c.ujaName ?? 'Uja'}</span>
                  <time className={styles.when}>{when(c.last_message_at)}</time>
                </span>
                {c.productName && <span className={styles.product}>{c.productName}</span>}
                <span className={pending ? styles.lastPending : styles.last}>
                  {c.lastFromMe ? 'Tu: ' : ''}{c.lastBody}
                </span>
              </span>
              {pending && <span className={styles.dot} aria-label="Por responder" />}
            </Link>
          </li>
        );
      })}
    </ul>
  );
}
