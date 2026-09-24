'use client';

import { useActionState, useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import { createClient } from '@/lib/db/browser';
import { resubmitProduct, submitProduct, type SubmitState } from './actions';
import styles from './page.module.css';

const MAX_PHOTOS = 8;
const MAX_OPTIONS = 12;
const BUCKET = 'monira-raw';

type Photo = {
  key: string;
  file?: File;     // ausente em fotografias já enviadas antes (modo Corrigir)
  preview: string;
  path?: string;   // preenchido depois do envio, para não reenviar numa nova tentativa
};

export type EditInitial = {
  productId: string;
  name: string;
  price: number;
  description: string;
  options: string[];
  photos: { path: string; url: string }[];
};

function revoke(p: Photo) {
  if (p.preview.startsWith('blob:')) URL.revokeObjectURL(p.preview);
}

function formatKz(digits: string) {
  return digits.replace(/\B(?=(\d{3})+(?!\d))/g, '.');
}

function extensionOf(file: File) {
  const fromName = file.name.split('.').pop()?.toLowerCase();
  if (fromName && /^[a-z0-9]{2,5}$/.test(fromName)) return fromName;
  return file.type.split('/')[1] ?? 'jpg';
}

export default function AddProductForm({ ujaId, edit }: { ujaId: string; edit?: EditInitial }) {
  const [photos, setPhotos] = useState<Photo[]>(
    () => edit?.photos.map((p) => ({ key: p.path, preview: p.url, path: p.path })) ?? [],
  );
  const [price, setPrice] = useState(edit ? formatKz(String(Math.round(edit.price))) : '');
  const [options, setOptions] = useState<string[]>(edit?.options ?? []);
  const [optionDraft, setOptionDraft] = useState('');
  const fileInput = useRef<HTMLInputElement>(null);
  const photosRef = useRef(photos);

  useEffect(() => {
    photosRef.current = photos;
  }, [photos]);

  // Libertar as pré-visualizações quando o ecrã sai.
  useEffect(() => () => photosRef.current.forEach(revoke), []);

  const [state, formAction, pending] = useActionState<SubmitState, FormData>(
    async (prev, formData) => {
      if (photos.length === 0) return { status: 'error', message: 'Junta pelo menos uma fotografia.' };

      // As fotografias vão directamente para o Storage (a Server Action aceita pouco peso).
      // A Server Action só recebe os caminhos.
      const supabase = createClient();
      const uploaded: Photo[] = [];
      for (const photo of photos) {
        if (photo.path) {
          uploaded.push(photo);
          continue;
        }
        const file = photo.file!;
        const path = `${ujaId}/${crypto.randomUUID()}.${extensionOf(file)}`;
        const { error } = await supabase.storage
          .from(BUCKET)
          .upload(path, file, { contentType: file.type || undefined, upsert: false });
        if (error) {
          setPhotos([...uploaded, ...photos.slice(uploaded.length)]);
          return { status: 'error', message: 'Não foi possível enviar as fotografias. Tenta outra vez.' };
        }
        uploaded.push({ ...photo, path });
      }
      setPhotos(uploaded);

      uploaded.forEach((p) => formData.append('photo_path', p.path!));
      options.forEach((o) => formData.append('option', o));
      return edit ? resubmitProduct(edit.productId, prev, formData) : submitProduct(prev, formData);
    },
    { status: 'idle' },
  );

  function addFiles(list: FileList | null) {
    if (!list) return;
    const room = MAX_PHOTOS - photos.length;
    const next = Array.from(list)
      .filter((f) => f.type.startsWith('image/'))
      .slice(0, room)
      .map((file) => ({ key: crypto.randomUUID(), file, preview: URL.createObjectURL(file) }));
    setPhotos((current) => [...current, ...next]);
    if (fileInput.current) fileInput.current.value = '';
  }

  function removePhoto(key: string) {
    setPhotos((current) => {
      const gone = current.find((p) => p.key === key);
      if (gone) revoke(gone);
      return current.filter((p) => p.key !== key);
    });
  }

  function addOption() {
    const value = optionDraft.trim();
    if (!value || options.length >= MAX_OPTIONS) return;
    if (!options.some((o) => o.toLowerCase() === value.toLowerCase())) setOptions([...options, value]);
    setOptionDraft('');
  }

  // O estado de useActionState não se repõe: recarregar dá um formulário limpo.
  function startOver() {
    window.location.reload();
  }

  if (state.status === 'done') {
    return (
      <section className={styles.done} aria-live="polite">
        <span className={styles.doneMark} aria-hidden="true">
          <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"><path d="M6 12.5l4 4L18 8" /></svg>
        </span>
        <h2 className={styles.doneTitle}>{edit ? 'Enviado de novo.' : 'Recebido.'}</h2>
        <p className={styles.doneText}>A Monira vai preparar o teu produto antes de o publicar.</p>
        <div className={styles.doneActions}>
          <Link href="/painel" className={styles.primaryLink}>Ver os meus produtos</Link>
          {!edit && <button type="button" className={styles.secondary} onClick={startOver}>Adicionar outro</button>}
        </div>
      </section>
    );
  }

  const [main, ...rest] = photos;

  return (
    <form action={formAction} className={styles.form} noValidate>
      <input type="hidden" name="uja_id" value={ujaId} />

      <section className={styles.block}>
        <span className={styles.label} id="photos-label">Fotografias</span>
        <div className={styles.photos} aria-labelledby="photos-label">
          {main ? (
            <figure className={styles.photoMain}>
              {/* eslint-disable-next-line @next/next/no-img-element -- pré-visualização local (blob:), fora do alcance do next/image */}
              <img src={main.preview} alt="Fotografia principal" />
              <button type="button" className={styles.remove} aria-label="Retirar fotografia principal" onClick={() => removePhoto(main.key)} disabled={pending}>×</button>
            </figure>
          ) : (
            <button type="button" className={styles.photoAddMain} onClick={() => fileInput.current?.click()} disabled={pending}>
              <svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"><path d="M12 5v14M5 12h14" /></svg>
              Juntar fotografias
            </button>
          )}
          {rest.map((p, i) => (
            <figure key={p.key} className={styles.photoSmall}>
              {/* eslint-disable-next-line @next/next/no-img-element -- pré-visualização local (blob:), fora do alcance do next/image */}
              <img src={p.preview} alt={`Fotografia ${i + 2}`} />
              <button type="button" className={styles.remove} aria-label={`Retirar fotografia ${i + 2}`} onClick={() => removePhoto(p.key)} disabled={pending}>×</button>
            </figure>
          ))}
          {main && photos.length < MAX_PHOTOS && (
            <button type="button" className={styles.photoAdd} aria-label="Adicionar fotografia" onClick={() => fileInput.current?.click()} disabled={pending}>
              <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"><path d="M12 5v14M5 12h14" /></svg>
              Foto
            </button>
          )}
        </div>
        {/* Sem `name`: os ficheiros não seguem para a Server Action, só os caminhos.
            accept="image/*" (sem .heic) faz o iPhone converter as fotos para JPEG ao escolher. */}
        <input ref={fileInput} type="file" accept="image/*" multiple hidden onChange={(e) => addFiles(e.target.files)} />
        <p className={styles.hint}>A primeira foto será a principal do produto.</p>
      </section>

      <section className={styles.fields}>
        <div className={styles.field}>
          <label htmlFor="raw_name" className={styles.label}>Nome</label>
          <input id="raw_name" name="raw_name" type="text" maxLength={120} required autoComplete="off" defaultValue={edit?.name} className={styles.input} />
        </div>

        <div className={styles.field}>
          <label htmlFor="price" className={styles.label}>Preço</label>
          <div className={styles.priceBox}>
            <input
              id="price"
              name="price"
              type="text"
              inputMode="numeric"
              required
              placeholder="0"
              value={price}
              onChange={(e) => setPrice(formatKz(e.target.value.replace(/\D/g, '').slice(0, 12)))}
              className={styles.priceInput}
            />
            <span className={styles.unit}>Kz</span>
          </div>
        </div>

        <div className={styles.field}>
          <label htmlFor="raw_description" className={styles.label}>Sobre o produto</label>
          <p id="about-hint" className={styles.hintTight}>Conta-nos o essencial. A Monira trata da apresentação.</p>
          <textarea id="raw_description" name="raw_description" rows={3} maxLength={2000} aria-describedby="about-hint" defaultValue={edit?.description} className={styles.textarea} />
        </div>

        <div className={styles.field}>
          <span className={styles.label} id="options-label">Opções</span>
          <div className={styles.chips} aria-labelledby="options-label">
            {options.map((o) => (
              <span key={o} className={styles.chip}>
                {o}
                <button type="button" aria-label={`Retirar ${o}`} onClick={() => setOptions(options.filter((x) => x !== o))} disabled={pending}>×</button>
              </span>
            ))}
          </div>
          {options.length < MAX_OPTIONS && (
            <div className={styles.optionRow}>
              <label htmlFor="option-draft" className={styles.srOnly}>Nova opção</label>
              <input
                id="option-draft"
                type="text"
                maxLength={40}
                placeholder="Ex.: Azul"
                value={optionDraft}
                onChange={(e) => setOptionDraft(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter') {
                    e.preventDefault();
                    addOption();
                  }
                }}
                className={styles.input}
              />
              <button type="button" className={styles.addOption} onClick={addOption} disabled={pending || !optionDraft.trim()}>+ Opção</button>
            </div>
          )}
        </div>
      </section>

      <div className={styles.footer}>
        {state.status === 'error' && <p className={styles.error} role="alert">{state.message}</p>}
        <button type="submit" className={styles.primary} disabled={pending}>
          {pending ? 'A enviar…' : edit ? 'Enviar de novo' : 'Publicar na Uja'}
        </button>
      </div>
    </form>
  );
}
