'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';

// Sem infraestrutura de tempo real por agora: actualiza a conversa a cada 8 s
// enquanto está visível, e desce até à última mensagem quando chega uma nova.
export default function LiveUpdates({ count }: { count: number }) {
  const router = useRouter();

  useEffect(() => {
    const tick = () => { if (!document.hidden) router.refresh(); };
    const id = window.setInterval(tick, 8000);
    return () => window.clearInterval(id);
  }, [router]);

  useEffect(() => {
    document.getElementById('fim')?.scrollIntoView({ block: 'end' });
  }, [count]);

  return null;
}
