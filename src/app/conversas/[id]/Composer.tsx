'use client';

import { useActionState, useEffect, useRef } from 'react';
import { sendMessage, type SendState } from '../actions';
import styles from './conversa.module.css';

export default function Composer({ conversationId }: { conversationId: string }) {
  const [state, action, pending] = useActionState<SendState, FormData>(sendMessage.bind(null, conversationId), { status: 'idle' });
  const formRef = useRef<HTMLFormElement>(null);

  useEffect(() => {
    if (state.status === 'sent') formRef.current?.reset();
  }, [state]);

  return (
    <form ref={formRef} action={action} className={styles.composer}>
      {state.status === 'error' && <p className={styles.error} role="alert">{state.message}</p>}
      <div className={styles.composerRow}>
        <label htmlFor="body" className={styles.srOnly}>Mensagem</label>
        <textarea
          id="body"
          name="body"
          rows={1}
          maxLength={4000}
          placeholder="Escrever mensagem…"
          className={styles.input}
          onKeyDown={(e) => {
            if (e.key === 'Enter' && !e.shiftKey && !e.nativeEvent.isComposing) {
              e.preventDefault();
              formRef.current?.requestSubmit();
            }
          }}
        />
        <button type="submit" className={styles.send} disabled={pending}>{pending ? '…' : 'Enviar'}</button>
      </div>
    </form>
  );
}
